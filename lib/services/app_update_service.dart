import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_constants.dart';

class AppUpdateService {
  // Single Source of Truth Production Domain
  static String get baseUrl => AppConstants.baseUrl; 

  static Future<bool> checkForUpdates(BuildContext context) async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      int currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      String platform = Platform.isAndroid ? 'android' : 'ios';

      // Call Laravel API with a strict 3-second timeout to prevent startup blocking
      final url = Uri.parse('$baseUrl/api/app-version/check?platform=$platform&version_code=$currentVersionCode');
      
      final response = await http.get(url).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['update_available'] == true && context.mounted) {
          final bool force = data['force_update'] ?? false;
          _showUpdateDialog(
            context,
            forceUpdate: force,
            versionName: data['latest_version_name']?.toString() ?? 'Latest',
            apkUrl: data['apk_url']?.toString(),
            releaseNotes: data['release_notes']?.toString(),
          );
          return force;
        }
      }
    } catch (e) {
      debugPrint("Failed to check for updates: $e");
    }
    return false;
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required bool forceUpdate,
    required String versionName,
    required String? apkUrl,
    required String? releaseNotes,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => !forceUpdate,
          child: AlertDialog(
            title: Text('Update Available ($versionName)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(forceUpdate 
                    ? 'A mandatory update is required to continue using the app.' 
                    : 'A new version of the app is available. Would you like to update?'),
                if (releaseNotes != null && releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('What\'s new:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(releaseNotes),
                ],
              ],
            ),
            actions: [
              if (!forceUpdate)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('LATER'),
                ),
              ElevatedButton(
                onPressed: () async {
                  if (apkUrl != null) {
                    final Uri url = Uri.parse(apkUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                child: const Text('UPDATE NOW'),
              ),
            ],
          ),
        );
      },
    );
  }
}
