import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'drive_service.dart';

class DataManager extends ChangeNotifier {
  final DriveService _driveService = DriveService();
  
  // --- STATE ---
  bool _isInitialized = false;
  bool _isGuest = false;
  List<dynamic> _currentPayrollData = []; 

  // Settings
  bool _use24HourFormat = false;
  bool _isDarkMode = false;
  TimeOfDay _shiftStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _shiftEnd = const TimeOfDay(hour: 17, minute: 0);

  // --- GETTERS ---
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _driveService.currentUser != null || _isGuest;
  bool get isGuest => _isGuest;
  
  String? get userEmail => _driveService.currentUser?.email;
  String? get userName => _driveService.currentUser?.displayName;
  String? get userPhoto => _driveService.currentUser?.photoUrl;

  bool get use24HourFormat => _use24HourFormat;
  bool get isDarkMode => _isDarkMode;
  TimeOfDay get shiftStart => _shiftStart;
  TimeOfDay get shiftEnd => _shiftEnd;

  // --- 1. APP STARTUP ---
  Future<void> initApp() async {
    final prefs = await SharedPreferences.getInstance();
    _isGuest = prefs.getBool('isGuest') ?? false;

    if (!_isGuest) {
      bool success = await _driveService.trySilentLogin();
      if (success) {
        await _pullAllFromCloud(); 
      }
    }

    await _loadLocalSettings(prefs);
    _isInitialized = true;
    notifyListeners();
  }

  // --- 2. AUTH ACTIONS ---
  Future<bool> loginWithGoogle() async {
    bool success = await _driveService.signIn();
    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isGuest', false);
      _isGuest = false;
      await _pullAllFromCloud();
      notifyListeners();
    }
    return success;
  }

  Future<void> continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearLocalData(); 
    await prefs.setBool('isGuest', true);
    _isGuest = true;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearLocalData();
    await prefs.remove('isGuest');
    _isGuest = false;
    await _driveService.signOut();
    notifyListeners();
  }

  Future<void> _clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pay_tracker_data'); 
    await prefs.remove('pay_periods_data'); 
    _currentPayrollData = [];
  }

  // --- 3. SYNC ENGINE ---

  // SMART SYNC: Merges Cloud and Local data
  Future<String> smartSync(List<Map<String, dynamic>> localData) async {
    if (_isGuest) return "Guest Mode: Saved locally.";

    try {
      // 1. Fetch Cloud Data
      final cloudBackup = await _driveService.fetchCloudData();
      List<dynamic> cloudList = [];
      
      if (cloudBackup != null && cloudBackup.isNotEmpty) {
        final payrollMap = cloudBackup.firstWhere(
          (e) => e.containsKey('payroll_data'), orElse: () => {}
        );
        if (payrollMap['payroll_data'] != null) {
          cloudList = List<dynamic>.from(payrollMap['payroll_data']);
        }
      }

      // 2. MERGE LOGIC
      Map<String, Map<String, dynamic>> mergedMap = {};

      // Add all Local items first
      for (var item in localData) {
        mergedMap[item['id']] = item;
      }

      // Merge Cloud items
      int updates = 0;
      for (var cloudItem in cloudList) {
        String id = cloudItem['id'];
        
        if (mergedMap.containsKey(id)) {
          // Conflict: Compare dates
          // Using a default distant past date if lastEdited is missing to be safe
          DateTime localDate = DateTime.tryParse(mergedMap[id]!['lastEdited'] ?? "") ?? DateTime(2000);
          DateTime cloudDate = DateTime.tryParse(cloudItem['lastEdited'] ?? "") ?? DateTime(2000);

          // If Cloud is newer, overwrite local
          if (cloudDate.isAfter(localDate)) {
            mergedMap[id] = cloudItem;
            updates++;
          }
        } else {
          // New item from cloud (doesn't exist locally)
          mergedMap[id] = cloudItem;
          updates++;
        }
      }

      // 3. Finalize List
      _currentPayrollData = mergedMap.values.toList();
      
      // 4. Save merged data to Local Storage (so UI updates)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pay_tracker_data', jsonEncode(_currentPayrollData));

      // 5. Upload merged data back to Cloud
      await _syncAllToCloud();

      return "Sync Complete (Merged $updates items)";

    } catch (e) {
      print("Smart Sync Error: $e");
      // Fallback: Just try to upload what we have
      await _syncAllToCloud(); 
      return "Sync Error (Uploaded Local Only)";
    }
  }

  // Simple Auto-Save (Push Only)
  Future<String> syncPayrollToCloud(List<Map<String, dynamic>> data) async {
    _currentPayrollData = data;
    if (_isGuest) return "Saved locally";

    String? error = await _syncAllToCloud();
    return error == null ? "Cloud Backup Complete" : "Sync Failed: $error";
  }

  Future<void> _pullAllFromCloud() async {
    if (_isGuest) return;
    try {
      final cloudData = await _driveService.fetchCloudData();
      if (cloudData != null && cloudData.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();

        // Data
        final payrollMap = cloudData.firstWhere((e) => e.containsKey('payroll_data'), orElse: () => {});
        if (payrollMap.isNotEmpty && payrollMap['payroll_data'] != null) {
          _currentPayrollData = List<dynamic>.from(payrollMap['payroll_data']);
          await prefs.setString('pay_tracker_data', jsonEncode(_currentPayrollData));
        }

        // Settings
        final settingsMap = cloudData.firstWhere((e) => e.containsKey('settings'), orElse: () => {});
        if (settingsMap.isNotEmpty && settingsMap['settings'] != null) {
           final s = settingsMap['settings'];
           _use24HourFormat = s['use24HourFormat'] ?? _use24HourFormat;
           _isDarkMode = s['isDarkMode'] ?? _isDarkMode;
           await prefs.setBool('use24HourFormat', _use24HourFormat);
           await prefs.setBool('isDarkMode', _isDarkMode);
        }
        notifyListeners();
      }
    } catch (e) {
      print("Cloud Pull Error: $e");
    }
  }

  Future<String?> _syncAllToCloud() async {
    if (_isGuest) return "Guest Mode";
    
    final Map<String, dynamic> settingsData = {
      'use24HourFormat': _use24HourFormat,
      'isDarkMode': _isDarkMode,
      'shiftStart': "${_shiftStart.hour}:${_shiftStart.minute}",
      'shiftEnd': "${_shiftEnd.hour}:${_shiftEnd.minute}",
    };

    final List<Map<String, dynamic>> fullBackup = [
      {'settings': settingsData},
      {'payroll_data': _currentPayrollData},
    ];

    return await _driveService.syncToCloud(fullBackup);
  }

  // --- SETTINGS HELPERS ---
  Future<void> _loadLocalSettings(SharedPreferences prefs) async {
    _use24HourFormat = prefs.getBool('use24HourFormat') ?? false;
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    String? startStr = prefs.getString('shiftStart');
    if (startStr != null) {
      final parts = startStr.split(':');
      _shiftStart = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    String? endStr = prefs.getString('shiftEnd');
    if (endStr != null) {
      final parts = endStr.split(':');
      _shiftEnd = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
  }

  Future<void> updateSettings({bool? isDark, bool? is24h, TimeOfDay? shiftStart, TimeOfDay? shiftEnd}) async {
    final prefs = await SharedPreferences.getInstance();
    if (isDark != null) { _isDarkMode = isDark; await prefs.setBool('isDarkMode', isDark); }
    if (is24h != null) { _use24HourFormat = is24h; await prefs.setBool('use24HourFormat', is24h); }
    if (shiftStart != null) { _shiftStart = shiftStart; await prefs.setString('shiftStart', "${shiftStart.hour}:${shiftStart.minute}"); }
    if (shiftEnd != null) { _shiftEnd = shiftEnd; await prefs.setString('shiftEnd', "${shiftEnd.hour}:${shiftEnd.minute}"); }
    notifyListeners();
    _syncAllToCloud();
  }
}