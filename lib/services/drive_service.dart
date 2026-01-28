import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class DriveService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  drive.DriveApi? _api;
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  // 1. SILENT LOGIN (On App Startup)
  Future<bool> trySilentLogin() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        await _initializeClient();
        return true;
      }
    } catch (e) {
      print("Silent Login Error: $e");
    }
    return false;
  }

  // 2. EXPLICIT LOGIN (Login Button)
  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        await _initializeClient();
        return true;
      }
    } catch (e) {
      print("Sign In Error: $e");
    }
    return false;
  }

  // 3. LOGOUT
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _api = null;
  }

  // Helper: Setup the Drive API Client
  Future<void> _initializeClient() async {
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient != null) {
      _api = drive.DriveApi(httpClient);
    }
  }

  // --- DRIVE OPERATIONS (Same as before) ---
  Future<List<Map<String, dynamic>>?> fetchCloudData() async {
    if (_api == null) return null;
    try {
      final fileId = await _findFileId();
      if (fileId == null) return null;

      final media = await _api!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> dataStore = [];
      await media.stream.forEach((element) => dataStore.addAll(element));
      
      if (dataStore.isEmpty) return null;
      
      final String jsonString = utf8.decode(dataStore);
      final List<dynamic> rawList = jsonDecode(jsonString);
      return rawList.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      print("Fetch Error: $e");
      return null;
    }
  }

  Future<void> syncToCloud(List<Map<String, dynamic>> data) async {
    if (_api == null) return; // Guest mode or not logged in
    try {
      final String jsonString = jsonEncode(data);
      final List<int> fileBytes = utf8.encode(jsonString);
      final media = drive.Media(Stream.value(fileBytes), fileBytes.length);

      final fileId = await _findFileId();

      if (fileId != null) {
        await _api!.files.update(drive.File(), fileId, uploadMedia: media);
      } else {
        final fileMetadata = drive.File()
          ..name = 'pay_tracker_data.json'
          ..parents = ['appDataFolder'];
        await _api!.files.create(fileMetadata, uploadMedia: media);
      }
      print("☁️ Cloud Synced");
    } catch (e) {
      print("Sync Error: $e");
    }
  }

  Future<String?> _findFileId() async {
    if (_api == null) return null;
    final list = await _api!.files.list(
      spaces: 'appDataFolder',
      q: "name = 'pay_tracker_data.json' and trashed = false",
    );
    return (list.files?.isNotEmpty == true) ? list.files!.first.id : null;
  }
}