import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/data_models.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';
import '../widgets/custom_pickers.dart';
import '../services/data_manager.dart'; 
import 'period_detail_screen.dart';
import 'settings_screen.dart';

class PayPeriodListScreen extends StatefulWidget {
  final bool use24HourFormat;
  final bool isDarkMode;
  final TimeOfDay shiftStart;
  final TimeOfDay shiftEnd;
  final Function({bool? isDark, bool? is24h, TimeOfDay? shiftStart, TimeOfDay? shiftEnd}) onUpdateSettings;

  const PayPeriodListScreen({
    super.key, 
    required this.use24HourFormat, 
    required this.isDarkMode,
    required this.shiftStart,
    required this.shiftEnd,
    required this.onUpdateSettings,
  });

  @override
  State<PayPeriodListScreen> createState() => _PayPeriodListScreenState();
}

class _PayPeriodListScreenState extends State<PayPeriodListScreen> {
  List<PayPeriod> periods = [];
  final NumberFormat currency = NumberFormat("#,##0.00", "en_US");

  @override
  void initState() {
    super.initState();
    // Load local data immediately
    _loadData();
    
    // Listen for DataManager changes (like Cloud Pull finishing)
    // This ensures data appears automatically on login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final manager = Provider.of<DataManager>(context, listen: false);
      manager.addListener(() {
        if (mounted) _loadData();
      });
    });
  }

  // --- DATA LOADING ---
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check main storage key. DataManager wipes this on logout.
    String? data = prefs.getString(kStorageKey); 
    
    // Safety check: if main key missing but backup key exists
    if (data == null && prefs.containsKey('pay_tracker_data')) {
      data = prefs.getString('pay_tracker_data');
    }

    if (data != null) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        setState(() {
          periods = decoded.map((e) => PayPeriod.fromJson(e)).toList();
        });
      } catch (e) { }
    } else {
      // CLEAR LIST: If data is null (meaning we logged out), wipe the UI list
      setState(() {
        periods = [];
      });
    }
  }

  // --- DATA SAVING ---
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = periods.map((e) => e.toJson()).toList();
    final String jsonData = jsonEncode(jsonList);
    
    // 1. Save Locally
    await prefs.setString(kStorageKey, jsonData);

    // 2. Auto-sync in background
    if (mounted) {
      Provider.of<DataManager>(context, listen: false).syncPayrollToCloud(jsonList);
    }
  }

  // --- MANUAL SYNC ACTION ---
  void _performManualSync() async {
    final manager = Provider.of<DataManager>(context, listen: false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [CircularProgressIndicator(strokeWidth: 2), SizedBox(width: 10), Text("Syncing...")]),
        duration: Duration(seconds: 1),
      )
    );

    // Ensure DataManager has the latest UI data before syncing
    final List<Map<String, dynamic>> jsonList = periods.map((e) => e.toJson()).toList();
    await manager.syncPayrollToCloud(jsonList);

    // Force Push
    String result = await manager.manualSync();

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result),
        backgroundColor: result.contains("Failed") ? Colors.red : Colors.green,
      ));
    }
  }

  // --- ACTIONS ---

  void _sortPeriods(String type) {
    if (mounted) playClickSound(context); 
    setState(() {
      if (type == 'newest') periods.sort((a, b) => b.start.compareTo(a.start));
      else if (type == 'oldest') periods.sort((a, b) => a.start.compareTo(b.start)); 
      else if (type == 'edited') periods.sort((a, b) => b.lastEdited.compareTo(a.lastEdited));
    });
    _saveData();
  }

  void _openSettings() {
    playClickSound(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(
      isDarkMode: widget.isDarkMode,
      use24HourFormat: widget.use24HourFormat,
      shiftStart: widget.shiftStart,
      shiftEnd: widget.shiftEnd,
      onUpdate: widget.onUpdateSettings,
      onDeleteAll: () async {
          // Local Delete Logic
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(kStorageKey);
          setState(() { periods = []; });
          // Wipe cloud too if needed
          if (mounted) Provider.of<DataManager>(context, listen: false).syncPayrollToCloud([]);
      },
      onExportReport: _exportReportText,
      onBackup: _backupDataJSON,
      onRestore: _restoreDataJSON,
    )));
  }

  void _createNewPeriod() async {
    DateTime now = DateTime.now();
    DateTime defaultStart = (now.day <= 15) ? DateTime(now.year, now.month, 1) : DateTime(now.year, now.month, 16);
    playClickSound(context);
    DateTime? start = await showFastDatePicker(context, defaultStart);
    if (start == null) return;
    if (!mounted) return;
    
    int lastDayOfMonth = DateTime(start.year, start.month + 1, 0).day;
    DateTime defaultEnd = (start.day <= 15) ? DateTime(start.year, start.month, 15) : DateTime(start.year, start.month, lastDayOfMonth);
    if (defaultEnd.isBefore(start)) defaultEnd = DateTime(start.year, start.month, lastDayOfMonth);

    DateTime? end = await showFastDatePicker(context, defaultEnd, minDate: start);
    if (end == null) return;

    final newPeriod = PayPeriod(
      id: const Uuid().v4(),
      name: "${DateFormat('MMM d, yyyy').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}",
      start: start, end: end, lastEdited: DateTime.now(), hourlyRate: 50.0, shifts: [],
    );
    setState(() {
      periods.insert(0, newPeriod);
      periods.sort((a, b) => b.start.compareTo(a.start));
    });
    _saveData();
    _openPeriod(newPeriod);
  }

  void _openPeriod(PayPeriod period) async {
    playClickSound(context);
    period.lastEdited = DateTime.now();
    _saveData();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PeriodDetailScreen(
      period: period, 
      use24HourFormat: widget.use24HourFormat,
      shiftStart: widget.shiftStart,
      shiftEnd: widget.shiftEnd,
    )));
    _saveData();
    setState(() {});
  }
  
  void _deletePeriod(int index) {
    playClickSound(context);
    setState(() { periods.removeAt(index); });
    _saveData();
  }

  void _exportReportText() {
    StringBuffer sb = StringBuffer();
    for (var p in periods) {
      sb.writeln("${p.name} (Total: ₱ ${currency.format(p.getTotalPay(widget.shiftStart, widget.shiftEnd))})");
    }
    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Readable Report copied!"), backgroundColor: Colors.green));
  }
  
  void _backupDataJSON() {
    String jsonString = jsonEncode(periods.map((e) => e.toJson()).toList());
    Clipboard.setData(ClipboardData(text: jsonString));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Backup Code copied!"), backgroundColor: Colors.teal));
  }

  void _restoreDataJSON(String jsonString) { /* existing logic */ }

  @override
  Widget build(BuildContext context) {
    return Consumer<DataManager>(
      builder: (context, dataManager, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Payroll Cutoffs"),
            actions: [
              // 1. SYNC BUTTON (Visible only if logged in)
              if (!dataManager.isGuest)
                IconButton(
                  icon: const Icon(Icons.cloud_sync),
                  tooltip: "Force Sync",
                  onPressed: _performManualSync,
                ),

              // 2. SORT
              IconButton(
                icon: const Icon(Icons.sort),
                tooltip: "Sort",
                onPressed: () => _sortPeriods('newest'), 
              ),
              
              // 3. SETTINGS
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: "Settings",
                onPressed: _openSettings,
              ),

              // 4. PROFILE MENU
              PopupMenuButton<String>(
                offset: const Offset(0, 45),
                icon: CircleAvatar(
                  radius: 14,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  backgroundImage: dataManager.userPhoto != null ? NetworkImage(dataManager.userPhoto!) : null,
                  child: dataManager.userPhoto == null ? const Icon(Icons.person, size: 16, color: Colors.white) : null,
                ),
                itemBuilder: (context) {
                  if (dataManager.isGuest) {
                    return [
                      const PopupMenuItem(
                         value: 'login',
                         child: Row(
                           children: [Icon(Icons.login, size: 20), SizedBox(width: 8), Text("Log In to Sync")],
                         ),
                      )
                    ];
                  }
                  return [
                    PopupMenuItem(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Signed in as:", style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(dataManager.userEmail ?? "User", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [Icon(Icons.logout, color: Colors.red, size: 20), SizedBox(width: 8), Text("Logout", style: TextStyle(color: Colors.red))],
                      ),
                    ),
                  ];
                },
                onSelected: (value) {
                  if (value == 'logout') {
                    // Wipes local data, signs out, and reloads UI
                    dataManager.logout().then((_) {
                       if (mounted) _loadData();
                    });
                  } else if (value == 'login') {
                     dataManager.logout(); 
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: periods.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 20),
                      Text("No Pay Trackers Found", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _createNewPeriod,
                        icon: const Icon(Icons.add),
                        label: const Text("Create New Tracker"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary, 
                          foregroundColor: Colors.white
                        ),
                      )
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: periods.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = periods.removeAt(oldIndex);
                    periods.insert(newIndex, item);
                    _saveData();
                  },
                  itemBuilder: (context, index) {
                    final p = periods[index];
                    return Dismissible(
                      key: Key(p.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        playClickSound(context);
                        return await showDialog(context: context, builder: (ctx) => AlertDialog(
                          title: const Text("Delete Tracker?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                          ],
                        ));
                      },
                      onDismissed: (direction) => _deletePeriod(index),
                      child: GestureDetector(
                        onTap: () => _openPeriod(p),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                             title: Text(p.name, style: TextStyle(fontWeight: FontWeight.bold)),
                             subtitle: Text("${p.shifts.length} shifts"),
                             trailing: Text("₱${currency.format(p.getTotalPay(widget.shiftStart, widget.shiftEnd))}", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: _createNewPeriod,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }
}