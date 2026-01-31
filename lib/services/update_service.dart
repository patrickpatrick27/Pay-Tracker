import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_app_installer/flutter_app_installer.dart';
// 1. IMPORT YOUR MAIN.DART
import '../main.dart'; 

class GithubUpdateService {
  static const String _owner = "patrickpatrick27";
  static const String _repo = "payout_app";

  static Future<bool> isUpdateAvailable() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version.split('+')[0];

      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String latestVersion = (data['tag_name'] ?? "").toString().replaceAll('v', '');
        if (latestVersion.isEmpty) return false;
        return _isNewer(latestVersion, currentVersion);
      }
    } catch (e) {
      print("⚠️ Silent update check failed: $e");
    }
    return false;
  }

  static Future<void> checkForUpdate(BuildContext context, {bool showNoUpdateMsg = false}) async {
    print("🔍 [UpdateService] Checking for updates...");
    
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version.split('+')[0];
      
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String tagName = data['tag_name'] ?? ""; 
        String latestVersion = tagName.replaceAll('v', '');

        if (latestVersion == currentVersion) {
            if (showNoUpdateMsg && context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("You are on the latest version!"), backgroundColor: Colors.green)
                 );
            }
            return;
        }

        String? apkUrl;
        List<dynamic>? assets = data['assets'];
        if (assets != null) {
          for (var asset in assets) {
            if (asset['name'].toString().endsWith('.apk')) {
              apkUrl = asset['browser_download_url']; 
              break;
            }
          }
        }

        if (apkUrl == null) return;

        bool isNewer = _isNewer(latestVersion, currentVersion);

        if (isNewer) {
          // Use Future.delayed to ensure the frame is ready
          Future.delayed(Duration.zero, () {
            _showUpdateDialog(latestVersion, apkUrl!);
          });
        }
      }
    } catch (e) {
      print("❌ Update Check Failed: $e");
    }
  }

  static bool _isNewer(String latest, String current) {
    try {
      List<int> l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      for (int i = 0; i < l.length; i++) {
        if (i >= c.length) return true;
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
    } catch (e) {
      print("⚠️ Version parse error: $e");
    }
    return false;
  }

  // 2. UPDATED: Removed BuildContext from signature, uses navigatorKey
  static void _showUpdateDialog(String version, String apkUrl) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UpdateProgressDialog(version: version, apkUrl: apkUrl),
    );
  }
}

class _UpdateProgressDialog extends StatefulWidget {
  final String version;
  final String apkUrl;
  const _UpdateProgressDialog({required this.version, required this.apkUrl});

  @override
  State<_UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<_UpdateProgressDialog> {
  String _status = "Ready to download";
  double _progress = 0.0;
  bool _isDownloading = false;
  final Dio _dio = Dio();
  final FlutterAppInstaller _installer = FlutterAppInstaller();

  Future<void> _startDownload() async {
    setState(() { _isDownloading = true; _status = "Downloading..."; });
    try {
      Directory tempDir = await getTemporaryDirectory();
      String savePath = "${tempDir.path}/update.apk";
      File file = File(savePath);
      if (await file.exists()) await file.delete();

      await _dio.download(widget.apkUrl, savePath, onReceiveProgress: (received, total) {
        if (total != -1) {
          setState(() {
            _progress = received / total;
            _status = "Downloading: ${(_progress * 100).toStringAsFixed(0)}%";
          });
        }
      });
      setState(() => _status = "Installing...");
      await _installer.installApk(filePath: savePath);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _status = "Error: $e"; _isDownloading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: const Text("Update Available 🚀"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Version ${widget.version} is ready to install."),
          const SizedBox(height: 20),
          if (_isDownloading) ...[
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 10),
            Text(_status, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ],
      ),
      actions: [
        if (!_isDownloading) TextButton(onPressed: () => Navigator.pop(context), child: const Text("Later", style: TextStyle(color: Colors.grey))),
        if (!_isDownloading) FilledButton(onPressed: _startDownload, child: const Text("Update Now")),
      ],
    );
  }
}