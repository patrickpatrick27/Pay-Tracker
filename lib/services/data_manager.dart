import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'drive_service.dart';

class DataManager extends ChangeNotifier {
  final DriveService _driveService = DriveService();
  
  // --- AUTH STATE ---
  bool _isInitialized = false;
  bool _isGuest = false;
  
  // --- DATA STATE ---
  bool _isLoading = true;
  List<dynamic> _currentPayrollData = []; // Buffer for payroll records

  // Settings
  bool _use24HourFormat = false;
  bool _isDarkMode = false;
  TimeOfDay _shiftStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _shiftEnd = const TimeOfDay(hour: 17, minute: 0);

  // --- GETTERS ---
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
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
        // This will pull BOTH settings and payroll data
        await _pullAllFromCloud(); 
      }
    }

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
      
      await _pullAllFromCloud();
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
    await prefs.remove('isGuest');
    _isGuest = false;
    await _driveService.signOut();
    notifyListeners();
  }

  // --- 3. SETTINGS & PAYROLL LOGIC ---
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
    _syncAllToCloud(); 
  }

  // Called from Dashboard every time data is saved locally
  Future<void> syncPayrollToCloud(List<Map<String, dynamic>> data) async {
    _currentPayrollData = data;
    await _syncAllToCloud();
  }

  // --- 4. CLOUD SYNC ENGINE ---
  Future<void> _pullAllFromCloud() async {
    if (_isGuest) return;
    try {
      final cloudData = await _driveService.fetchCloudData();
      if (cloudData != null && cloudData.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();

        // A. RESTORE SETTINGS
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
          
          // Save cloud settings to local so they persist offline
          await prefs.setBool('use24HourFormat', _use24HourFormat);
          await prefs.setBool('isDarkMode', _isDarkMode);
          await prefs.setString('shiftStart', s['shiftStart']);
          await prefs.setString('shiftEnd', s['shiftEnd']);
        }

        // B. RESTORE PAYROLL DATA
        final payrollMap = cloudData.firstWhere(
          (element) => element.containsKey('payroll_data'),
          orElse: () => {},
        );

        if (payrollMap.isNotEmpty && payrollMap['payroll_data'] != null) {
          _currentPayrollData = payrollMap['payroll_data'];
          // Save cloud payroll to local storage (Matches Dashboard's kStorageKey)
          await prefs.setString('pay_periods_data', jsonEncode(_currentPayrollData));
        }
        
        notifyListeners();
      }
    } catch (e) {
      print("Cloud Pull Error: $e");
    }
  }

  Future<void> _syncAllToCloud() async {
    if (_isGuest) return;
    
    // 1. Package Settings
    final Map<String, dynamic> settingsData = {
      'use24HourFormat': _use24HourFormat,
      'isDarkMode': _isDarkMode,
      'shiftStart': "${_shiftStart.hour}:${_shiftStart.minute}",
      'shiftEnd': "${_shiftEnd.hour}:${_shiftEnd.minute}",
    };

    // 2. Package everything together
    final List<Map<String, dynamic>> fullBackup = [
      {'settings': settingsData},
      {'payroll_data': _currentPayrollData},
    ];

    await _driveService.syncToCloud(fullBackup);
  }
}