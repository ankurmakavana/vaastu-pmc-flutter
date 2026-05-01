// ─────────────────────────────────────────────────────────────────
// lib/screens/webview_screen.dart
// ─────────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../utils/app_constants.dart';
import '../utils/app_theme.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});
  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen>
    with WidgetsBindingObserver {
  late final WebViewController _wvc;
  bool _loading = true;
  bool _hasError = false;
  int _progress = 0;
  bool _isOnline = true;

  StreamSubscription<List<ConnectivityResult>>? _connectSub;
  StreamSubscription<String>? _notifSub;

  // ── Init ─────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupWebView(); // Initialize controller synchronously
    _initWebViewFlow();
  }

  Future<void> _initWebViewFlow() async {
    await _clearSessionOnStart();
    _monitorConnectivity();
    _listenNotificationTaps();
    _wvc.loadRequest(Uri.parse(AppConstants.baseUrl));
  }

  Future<void> _clearSessionOnStart() async {
    try {
      final cookieManager = WebViewCookieManager();
      await cookieManager.clearCookies();
      await StorageService.secureDelete(AppConstants.secureSessionToken);
    } catch (e) {
      debugPrint("Error clearing session: $e");
    }
  }

  void _monitorConnectivity() {
    _connectSub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online && !_isOnline) {
        // Came back online — reload
        setState(() {
          _isOnline = true;
          _hasError = false;
        });
        _wvc.reload();
      }
      setState(() => _isOnline = online);
    });
  }

  void _listenNotificationTaps() {
    _notifSub = NotificationService.onNotificationTap.stream.listen((route) {
      _wvc.loadRequest(Uri.parse('${AppConstants.baseUrl}$route'));
    });
  }

  void _setupWebView() {
    _wvc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppTheme.background)
      ..setUserAgent(
          'Mozilla/5.0 VaastuPMC-Flutter/${Platform.operatingSystem}')
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() {
          _loading = true;
          _hasError = false;
        }),
        onPageFinished: (url) {
          setState(() => _loading = false);
          _injectBridge();
          _syncFcmToken();
        },
        onProgress: (p) => setState(() => _progress = p),
        onWebResourceError: (err) {
          if (err.isForMainFrame == true) setState(() => _hasError = true);
        },
        onNavigationRequest: (req) {
          final url = req.url;
          // Allow any URL on your domain
          if (url.contains('pixelforge.lt') ||
              url.startsWith('about:') ||
              url.startsWith('blob:') ||
              url.startsWith('data:')) {
            return NavigationDecision.navigate;
          }
          // Only block truly external domains
          return NavigationDecision.prevent;
        },
      ))
      // ── JS → Flutter channels ───────────────────────────────
      ..addJavaScriptChannel('FlutterGPS', onMessageReceived: _handleGps)
      ..addJavaScriptChannel('FlutterCamera', onMessageReceived: _handleCamera)
      ..addJavaScriptChannel('FlutterFile', onMessageReceived: _handleFile)
      ..addJavaScriptChannel('FlutterBiometric',
          onMessageReceived: _handleBiometric)
      ..addJavaScriptChannel('FlutterStorage',
          onMessageReceived: _handleStorage)
      ..addJavaScriptChannel('FlutterToast', onMessageReceived: _handleToast)
      ..addJavaScriptChannel('FlutterPlatform',
          onMessageReceived: _handlePlatform);
  }

  // ── JS Bridge injection ──────────────────────────────────────
  Future<void> _injectBridge() async {
    const js = r'''
(function() {
  if (window.__vaastuBridgeInjected) return;
  window.__vaastuBridgeInjected = true;

  /* ── Promise factory ── */
  function makePromise(channel, payload) {
    return new Promise(function(resolve, reject) {
      var key = '_cb_' + channel + '_' + Date.now();
      window[key + '_res'] = resolve;
      window[key + '_rej'] = reject;
      window['_pending_' + channel] = key;
      window[channel].postMessage(JSON.stringify(Object.assign({ _key: key }, payload)));
    });
  }

  /* ── VaastuNative public API ── */
  window.VaastuNative = {
    isNative: true,
    platform: null, // set after platform channel responds

    /* GPS */
    getCurrentPosition: function() {
      return makePromise('FlutterGPS', { action: 'get' });
    },

    /* Camera: source = 'camera' | 'gallery' */
    takePhoto: function(source) {
      return makePromise('FlutterCamera', { source: source || 'camera', quality: 75 });
    },

    /* File picker: returns { name, base64, size, mime } */
    pickFile: function(accept) {
      return makePromise('FlutterFile', { accept: accept || '*/*' });
    },

    /* Biometric auth: resolves true or rejects */
    biometricAuth: function() {
      return makePromise('FlutterBiometric', {});
    },

    /* Secure storage (Keychain/Keystore) */
    secureSet: function(key, val) {
      FlutterStorage.postMessage(JSON.stringify({ op: 'set', key: key, val: val }));
    },
    secureGet: function(key) {
      return makePromise('FlutterStorage', { op: 'get', key: key });
    },
    secureDelete: function(key) {
      FlutterStorage.postMessage(JSON.stringify({ op: 'del', key: key }));
    },

    /* Native toast */
    toast: function(msg) { FlutterToast.postMessage(msg); },
  };

  /* ── Resolve helper (called by Flutter → JS) ── */
  window.__vaastuResolve = function(key, value) {
    var res = window[key + '_res'];
    if (res) { res(value); delete window[key + '_res']; delete window[key + '_rej']; }
  };
  window.__vaastuReject = function(key, error) {
    var rej = window[key + '_rej'];
    if (rej) { rej(new Error(error)); delete window[key + '_res']; delete window[key + '_rej']; }
  };

  /* ── Override VastuGPS to use native GPS ── */
  window.VastuGPS = {
    getCurrentPosition: window.VaastuNative.getCurrentPosition,
    checkIn: function(projectId) {
      return window.VaastuNative.getCurrentPosition().then(function(pos) {
        return window.fetchJson('/attendance/check-in', {
          method: 'POST',
          body: JSON.stringify({ project_id: projectId, latitude: pos.latitude, longitude: pos.longitude })
        });
      });
    },
    checkOut: function(projectId) {
      return window.VaastuNative.getCurrentPosition().then(function(pos) {
        return window.fetchJson('/attendance/check-out', {
          method: 'POST',
          body: JSON.stringify({ project_id: projectId, latitude: pos.latitude, longitude: pos.longitude })
        });
      });
    },
  };

  /* ── Get platform info ── */
  FlutterPlatform.postMessage('info');

  console.log('[Vaastu] Native bridge ready');
})();
''';
    await _wvc.runJavaScript(js);
  }

  // ── GPS ──────────────────────────────────────────────────────
  Future<void> _handleGps(JavaScriptMessage msg) async {
    final data = jsonDecode(msg.message) as Map<String, dynamic>;
    final key = data['_key'] as String;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        throw Exception(
            'Location permission permanently denied. Enable in Settings.');
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      await _wvc.runJavaScript(
          'window.__vaastuResolve("$key", {latitude:${pos.latitude},longitude:${pos.longitude},accuracy:${pos.accuracy}});');
    } catch (e) {
      await _wvc.runJavaScript(
          'window.__vaastuReject("$key", "${_esc(e.toString())}");');
    }
  }

  // ── Camera ───────────────────────────────────────────────────
  Future<void> _handleCamera(JavaScriptMessage msg) async {
    final data = jsonDecode(msg.message) as Map<String, dynamic>;
    final key = data['_key'] as String;
    final source =
        data['source'] == 'gallery' ? ImageSource.gallery : ImageSource.camera;
    final quality = (data['quality'] as num?)?.toInt() ?? 75;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: quality,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked == null) {
        await _wvc.runJavaScript('window.__vaastuReject("$key", "cancelled");');
        return;
      }
      final bytes = await picked.readAsBytes();
      final b64 = base64Encode(bytes);
      final mime = picked.mimeType ?? 'image/jpeg';
      // Pass as { dataUrl, name, mime }
      final payload = jsonEncode({
        'dataUrl': 'data:$mime;base64,$b64',
        'name': picked.name,
        'mime': mime
      });
      await _wvc.runJavaScript('window.__vaastuResolve("$key", $payload);');
    } catch (e) {
      await _wvc.runJavaScript(
          'window.__vaastuReject("$key", "${_esc(e.toString())}");');
    }
  }

  // ── File picker ──────────────────────────────────────────────
  Future<void> _handleFile(JavaScriptMessage msg) async {
    final data = jsonDecode(msg.message) as Map<String, dynamic>;
    final key = data['_key'] as String;
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) {
        await _wvc.runJavaScript('window.__vaastuReject("$key", "cancelled");');
        return;
      }
      final file = result.files.first;
      final b64 = base64Encode(file.bytes!);
      final payload = jsonEncode({
        'name': file.name,
        'base64': b64,
        'size': file.size,
        'mime': file.extension ?? 'application/octet-stream'
      });
      await _wvc.runJavaScript('window.__vaastuResolve("$key", $payload);');
    } catch (e) {
      await _wvc.runJavaScript(
          'window.__vaastuReject("$key", "${_esc(e.toString())}");');
    }
  }

  // ── Biometric ────────────────────────────────────────────────
  Future<void> _handleBiometric(JavaScriptMessage msg) async {
    final data = jsonDecode(msg.message) as Map<String, dynamic>;
    final key = data['_key'] as String;
    final ok = await AuthService.authenticateBiometric();
    if (ok) {
      await _wvc.runJavaScript('window.__vaastuResolve("$key", true);');
    } else {
      await _wvc
          .runJavaScript('window.__vaastuReject("$key", "biometric_failed");');
    }
  }

  // ── Secure storage ───────────────────────────────────────────
  Future<void> _handleStorage(JavaScriptMessage msg) async {
    final data = jsonDecode(msg.message) as Map<String, dynamic>;
    final op = data['op'] as String;
    final k = data['key'] as String;
    if (op == 'set') {
      await StorageService.secureWrite(k, data['val'] as String);
    } else if (op == 'del') {
      await StorageService.secureDelete(k);
    } else if (op == 'get') {
      final key = data['_key'] as String;
      final val = await StorageService.secureRead(k);
      final js = val != null
          ? 'window.__vaastuResolve("$key", ${jsonEncode(val)});'
          : 'window.__vaastuResolve("$key", null);';
      await _wvc.runJavaScript(js);
    }
  }

  // ── Toast ─────────────────────────────────────────────────────
  void _handleToast(JavaScriptMessage msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg.message)));
  }

  // ── Platform info ─────────────────────────────────────────────
  Future<void> _handlePlatform(JavaScriptMessage msg) async {
    await _wvc.runJavaScript(
        'if(window.VaastuNative) window.VaastuNative.platform = "${Platform.operatingSystem}";');
  }

  // ── Sync FCM token to server ──────────────────────────────────
  Future<void> _syncFcmToken() async {
    final token = await NotificationService.getToken();
    if (token == null) return;
    await _wvc.runJavaScript('''
      (function(){
        var csrf = document.querySelector('meta[name="csrf-token"]');
        if(!csrf) return;
        fetch('/api/fcm-token', {
          method: 'POST',
          headers: {'Content-Type':'application/json','X-CSRF-TOKEN': csrf.content},
          body: JSON.stringify({token:'${_esc(token)}', platform:'${Platform.operatingSystem}'})
        });
      })();
    ''');
  }



  String _esc(String s) =>
      s.replaceAll("'", "\\'").replaceAll('"', '\\"').replaceAll('\n', ' ');

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectSub?.cancel();
    _notifSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _wvc.canGoBack()) {
          await _wvc.goBack();
        } else {
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Stack(
            children: [
              if (!_hasError) WebViewWidget(controller: _wvc),
              if (_hasError) _buildError(),
              if (_loading && _progress < 100)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _progress / 100,
                    backgroundColor: Colors.transparent,
                    color: AppTheme.orange,
                    minHeight: 3,
                  ),
                ),
              if (!_isOnline)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.dark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.wifi_off, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text('No internet connection',
                            style:
                                TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() => Container(
        color: AppTheme.background,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded,
                    size: 80, color: Colors.grey[300]),
                const SizedBox(height: 24),
                const Text('Cannot reach server',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 10),
                const Text(
                    'Check your internet connection\nor contact your administrator.',
                    style: TextStyle(
                        fontSize: 14, color: AppTheme.textMuted, height: 1.5),
                    textAlign: TextAlign.center),
                const SizedBox(height: 36),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _loading = true;
                    });
                    _wvc.reload();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
}
