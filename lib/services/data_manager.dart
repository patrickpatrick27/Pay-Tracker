import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'drive_service.dart';

class DataManager extends ChangeNotifier {
  final DriveService _driveService = DriveService();
  
  // --- AUTH STATE ---
  bool _isInitialized = false;
  bool _isGuest = false;
  
  // --- SETTINGS STATE ---
  bool _isLoading = true;
  bool _use24HourFormat = false;
  bool _isDarkMode = false;
  TimeOfDay _shiftStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _shiftEnd = const TimeOfDay(hour: 17, minute: 0);

  // --- GETTERS ---
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _driveService.currentUser != null || _isGuest;
  bool get isGuest => _isGuest;
  
  // User Info
  String? get userEmail => _driveService.currentUser?.email;
  String? get userName => _driveService.currentUser?.displayName;
  String? get userPhoto => _driveService.currentUser?.photoUrl;

  // Settings Getters
  bool get use24HourFormat => _use24HourFormat;
  bool get isDarkMode => _isDarkMode;
  TimeOfDay get shiftStart => _shiftStart;
  TimeOfDay get shiftEnd => _shiftEnd;

  // --- 1. APP STARTUP ---
  Future<void> initApp() async {
    final prefs = await SharedPreferences.getInstance();
    
    // A. Check for Guest Mode
    _isGuest = prefs.getBool('isGuest') ?? false;

    // B. Check for Google User (Silent Login)
    if (!_isGuest) {
      bool success = await _driveService.trySilentLogin();
      if (success) {
        await _pullSettingsFromCloud(); // Sync settings immediately
      }
    }

    // C. Load Local Settings
    await _loadLocalSettings(prefs);

    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
  }

  // --- 2. AUTH ACTIONS ---
  Future<bool> loginWithGoogle() async {
    bool success = await _driveService.signIn();
    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isGuest', false);
      _isGuest = false;
      
      // Pull Cloud Settings on login
      await _pullSettingsFromCloud();
      notifyListeners();
    }
    return success;
  }

  Future<void> continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isGuest', true);
    _isGuest = true;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Clear Auth Flags
    await prefs.remove('isGuest');
    _isGuest = false;
    
    // Sign out of Google
    await _driveService.signOut();
    
    notifyListeners();
  }

  // --- 3. SETTINGS LOGIC ---
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

  Future<void> updateSettings({
    bool? isDark,
    bool? is24h,
    TimeOfDay? shiftStart,
    TimeOfDay? shiftEnd,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (isDark != null) {
      _isDarkMode = isDark;
      await prefs.setBool('isDarkMode', isDark);
    }
    if (is24h != null) {
      _use24HourFormat = is24h;
      await prefs.setBool('use24HourFormat', is24h);
    }
    if (shiftStart != null) {
      _shiftStart = shiftStart;
      await prefs.setString('shiftStart', "${shiftStart.hour}:${shiftStart.minute}");
    }
    if (shiftEnd != null) {
      _shiftEnd = shiftEnd;
      await prefs.setString('shiftEnd', "${shiftEnd.hour}:${shiftEnd.minute}");
    }

    notifyListeners();
    _syncSettingsToCloud(); // Auto-save to cloud
  }

  // --- 4. CLOUD SYNC (SETTINGS ONLY) ---
  Future<void> _pullSettingsFromCloud() async {
    if (_isGuest) return;
    try {
      final cloudData = await _driveService.fetchCloudData();
      if (cloudData != null && cloudData.isNotEmpty) {
        final settingsMap = cloudData.firstWhere(
          (element) => element.containsKey('settings'), 
          orElse: () => {},
        );

        if (settingsMap.isNotEmpty && settingsMap['settings'] != null) {
          final s = settingsMap['settings'];
          _use24HourFormat = s['use24HourFormat'] ?? _use24HourFormat;
          _isDarkMode = s['isDarkMode'] ?? _isDarkMode;
          
          if (s['shiftStart'] != null) {
            final parts = s['shiftStart'].split(':');
            _shiftStart = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
          if (s['shiftEnd'] != null) {
            final parts = s['shiftEnd'].split(':');
            _shiftEnd = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
          notifyListeners();
        }
      }
    } catch (e) {
      print("Cloud Pull Error: $e");
    }
  }

  Future<void> _syncSettingsToCloud() async {
    if (_isGuest) return;
    
    final Map<String, dynamic> settingsData = {
      'use24HourFormat': _use24HourFormat,
      'isDarkMode': _isDarkMode,
      'shiftStart': "${_shiftStart.hour}:${_shiftStart.minute}",
      'shiftEnd': "${_shiftEnd.hour}:${_shiftEnd.minute}",
    };

    // Note: This currently overwrites the whole file with just settings.
    // If you add Syncing for Pay Periods later, you must merge lists here.
    final List<Map<String, dynamic>> fullBackup = [
      {'settings': settingsData},
    ];

    await _driveService.syncToCloud(fullBackup);
  }
}