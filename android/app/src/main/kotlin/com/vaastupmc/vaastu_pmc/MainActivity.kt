package com.vaastupmc.vaastu_pmc

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.vaastupmc.download"
    private var downloadChannel: MethodChannel? = null
    private var downloadReceiver: BroadcastReceiver? = null

    companion object {
        private const val TAG = "VaastuDownload"
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        downloadChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        downloadChannel?.setMethodCallHandler { call, result ->
            if (call.method == "downloadFile") {
                val url = call.argument<String>("url")
                val explicitFilename = call.argument<String>("filename")
                val mimeType = call.argument<String>("mimeType")

                if (url != null) {
                    try {
                        val uri = Uri.parse(url)
                        
                        // Resolve the best filename available
                        var targetFilename = explicitFilename
                        if (targetFilename.isNullOrBlank()) {
                            targetFilename = uri.getQueryParameter("dl_name")
                        }
                        if (targetFilename.isNullOrBlank()) {
                            targetFilename = android.webkit.URLUtil.guessFileName(url, null, mimeType)
                        }
                        if (targetFilename.isNullOrBlank() || targetFilename == "downloadfile.bin") {
                            val lastSeg = uri.lastPathSegment
                            targetFilename = if (!lastSeg.isNullOrBlank() && lastSeg.contains(".")) {
                                lastSeg
                            } else {
                                val ext = when {
                                    mimeType?.contains("pdf") == true || url.contains("pdf") -> ".pdf"
                                    mimeType?.contains("sheet") == true || url.contains("excel") || url.contains("xlsx") -> ".xlsx"
                                    mimeType?.contains("csv") == true || url.contains("csv") -> ".csv"
                                    else -> ".pdf"
                                }
                                "Vaastu_Export_${System.currentTimeMillis()}$ext"
                            }
                        }

                        val request = DownloadManager.Request(uri)
                        request.setTitle(targetFilename)
                        request.setDescription("Downloading $targetFilename...")
                        request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                        request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, targetFilename)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            request.setAllowedOverwriteFile(true)
                        }
                        request.allowScanningByMediaScanner()
                        
                        if (mimeType != null && mimeType.isNotEmpty()) {
                            request.setMimeType(mimeType)
                        }

                        val cookieManager = android.webkit.CookieManager.getInstance()
                        // Ensure WebKit cookies are flushed to disk/shared memory before native download request
                        try {
                            cookieManager.flush()
                        } catch (ce: Exception) {
                            Log.w(TAG, "CookieManager flush error: ${ce.message}")
                        }

                        var cookies = cookieManager.getCookie(url)
                        if (cookies.isNullOrEmpty() && uri.host != null) {
                            val host = uri.host!!
                            cookies = cookieManager.getCookie(host) ?: cookieManager.getCookie("https://$host")
                        }

                        if (!cookies.isNullOrEmpty()) {
                            request.addRequestHeader("Cookie", cookies)
                            Log.d(TAG, "Attached cookies to DownloadManager request for $url")
                        } else {
                            Log.w(TAG, "No session cookies found in CookieManager for $url")
                        }
                        
                        // Set User-Agent and Referer if available
                        request.addRequestHeader("User-Agent", System.getProperty("http.agent") ?: "VaastuPMC Android App")
                        if (uri.host != null) {
                            request.addRequestHeader("Referer", "https://${uri.host}/")
                        }
                        
                        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                        val downloadId = manager.enqueue(request)
                        Log.i(TAG, "Download enqueued with ID: $downloadId from $url -> $targetFilename")
                        result.success(downloadId)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error enqueuing download: ${e.message}", e)
                        result.error("DOWNLOAD_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "URL missing", null)
                }
            } else {
                result.notImplemented()
            }
        }

        registerDownloadReceiver()
    }

    private fun registerDownloadReceiver() {
        if (downloadReceiver != null) return

        downloadReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (DownloadManager.ACTION_DOWNLOAD_COMPLETE == intent?.action) {
                    val downloadId = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1)
                    if (downloadId != -1L) {
                        verifyDownload(downloadId)
                    }
                }
            }
        }

        val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(downloadReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(downloadReceiver, filter)
        }
    }

    private fun verifyDownload(downloadId: Long) {
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as? DownloadManager ?: return
        val query = DownloadManager.Query().setFilterById(downloadId)
        var cursor: Cursor? = null

        try {
            cursor = manager.query(query)
            if (cursor != null && cursor.moveToFirst()) {
                val statusIndex = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS)
                val status = if (statusIndex != -1) cursor.getInt(statusIndex) else -1

                val reasonIndex = cursor.getColumnIndex(DownloadManager.COLUMN_REASON)
                val reason = if (reasonIndex != -1) cursor.getInt(reasonIndex) else -1

                val titleIndex = cursor.getColumnIndex(DownloadManager.COLUMN_TITLE)
                val title = if (titleIndex != -1) cursor.getString(titleIndex) else "File"

                val uriIndex = cursor.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI)
                val localUriStr = if (uriIndex != -1) cursor.getString(uriIndex) else null

                val bytesDownloadedIndex = cursor.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
                val bytesDownloaded = if (bytesDownloadedIndex != -1) cursor.getLong(bytesDownloadedIndex) else 0L

                val file = if (localUriStr != null) {
                    try {
                        val localUri = Uri.parse(localUriStr)
                        val path = localUri.path
                        if (path != null) File(path) else null
                    } catch (_: Exception) { null }
                } else null

                val actualFilename = file?.name ?: title ?: "Export_File"

                Log.i(TAG, "Download query for ID $downloadId: status=$status, reason=$reason, filename=$actualFilename, bytes=$bytesDownloaded, uri=$localUriStr")

                if (status == DownloadManager.STATUS_SUCCESSFUL) {
                    // Check file validity
                    var isValidFile = false
                    var failureDetail: String? = null

                    if (localUriStr != null) {
                        try {
                            val localUri = Uri.parse(localUriStr)
                            val stream = if (localUri.scheme == "content") {
                                contentResolver.openInputStream(localUri)
                            } else if (file != null && file.exists()) {
                                FileInputStream(file)
                            } else {
                                null
                            }

                            if (stream != null) {
                                val buffer = ByteArray(512)
                                val read = stream.read(buffer)
                                stream.close()

                                if (read <= 0 && bytesDownloaded <= 0L) {
                                    failureDetail = "Downloaded file is empty (0 bytes)."
                                } else if (read > 0) {
                                    val headerText = String(buffer, 0, read)
                                    val isHtml = headerText.contains("<!DOCTYPE html", ignoreCase = true) ||
                                            headerText.contains("<html", ignoreCase = true) ||
                                            headerText.contains("<head", ignoreCase = true) ||
                                            headerText.contains("login", ignoreCase = true) ||
                                            headerText.contains("Access Denied", ignoreCase = true) ||
                                            headerText.contains("Unauthorized", ignoreCase = true)

                                    if (isHtml) {
                                        failureDetail = "Authentication or server error: received HTML instead of document."
                                        Log.w(TAG, "File content is HTML login/error page instead of document!")
                                    } else {
                                        isValidFile = true
                                    }
                                } else {
                                    isValidFile = true
                                }
                            } else if (bytesDownloaded > 0) {
                                isValidFile = true
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Exception reading file for verification: ${e.message}", e)
                            if (bytesDownloaded > 0) {
                                isValidFile = true
                            }
                        }
                    } else if (bytesDownloaded > 0) {
                        isValidFile = true
                    }

                    val resultMap = HashMap<String, Any?>()
                    resultMap["downloadId"] = downloadId
                    resultMap["filename"] = actualFilename
                    resultMap["success"] = isValidFile
                    resultMap["error"] = failureDetail

                    Handler(Looper.getMainLooper()).post {
                        downloadChannel?.invokeMethod("onDownloadResult", resultMap)
                    }
                } else if (status == DownloadManager.STATUS_FAILED) {
                    val failureMessage = getDownloadFailureReason(reason)
                    Log.e(TAG, "Download failed for ID $downloadId: $failureMessage (raw code: $reason)")
                    val resultMap = HashMap<String, Any?>()
                    resultMap["downloadId"] = downloadId
                    resultMap["filename"] = actualFilename
                    resultMap["success"] = false
                    resultMap["error"] = failureMessage

                    Handler(Looper.getMainLooper()).post {
                        downloadChannel?.invokeMethod("onDownloadResult", resultMap)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in verifyDownload: ${e.message}", e)
        } finally {
            cursor?.close()
        }
    }

    private fun getDownloadFailureReason(reason: Int): String {
        return when (reason) {
            DownloadManager.ERROR_CANNOT_RESUME -> "Cannot resume download."
            DownloadManager.ERROR_DEVICE_NOT_FOUND -> "Storage device not found."
            DownloadManager.ERROR_FILE_ALREADY_EXISTS -> "Destination file already exists."
            DownloadManager.ERROR_FILE_ERROR -> "Storage I/O error."
            DownloadManager.ERROR_HTTP_DATA_ERROR -> "Network error during data transfer."
            DownloadManager.ERROR_INSUFFICIENT_SPACE -> "Insufficient storage space."
            DownloadManager.ERROR_TOO_MANY_REDIRECTS -> "Too many HTTP redirects."
            DownloadManager.ERROR_UNHANDLED_HTTP_CODE -> "Unhandled HTTP response."
            DownloadManager.ERROR_UNKNOWN -> "Unknown download error."
            in 400..499 -> "Client error (HTTP $reason - check session/authentication)."
            in 500..599 -> "Server error (HTTP $reason - backend failed to generate file)."
            else -> "Download failed with error code $reason"
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (downloadReceiver != null) {
            try {
                unregisterReceiver(downloadReceiver)
            } catch (e: Exception) {
                Log.w(TAG, "Error unregistering download receiver: ${e.message}")
            }
            downloadReceiver = null
        }
    }
}
