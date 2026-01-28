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
  bool _isUnsynced = false; // State for the Red Dot

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final manager = Provider.of<DataManager>(context, listen: false);
      manager.addListener(() {
        if (mounted) _loadData();
      });
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('pay_tracker_data');
    if (data == null) data = prefs.getString(kStorageKey); 

    if (data != null) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        setState(() {
          periods = decoded.map((e) => PayPeriod.fromJson(e)).toList();
        });
      } catch (e) { }
    } else {
      setState(() { periods = []; });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = periods.map((e) => e.toJson()).toList();
    final String jsonData = jsonEncode(jsonList);
    
    await prefs.setString(kStorageKey, jsonData);
    await prefs.setString('pay_tracker_data', jsonData);

    // Mark as unsynced locally until manual sync is pressed
    setState(() {
      _isUnsynced = true;
    });

    if (mounted) {
      // Auto-push is nice, but we keep the red dot logic for the manual confirmation
      Provider.of<DataManager>(context, listen: false).syncPayrollToCloud(jsonList);
    }
  }

  void _performManualSync() async {
    final manager = Provider.of<DataManager>(context, listen: false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [CircularProgressIndicator(strokeWidth: 2), SizedBox(width: 10), Text("Syncing...")]),
        duration: Duration(seconds: 1),
      )
    );

    final List<Map<String, dynamic>> localJson = periods.map((e) => e.toJson()).toList();
    String result = await manager.smartSync(localJson);

    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // If sync successful, remove red dot
      if (!result.contains("Error")) {
        setState(() => _isUnsynced = false);
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result),
        backgroundColor: result.contains("Error") ? Colors.red : Colors.green,
      ));
    }
  }

  // --- ACTIONS ---

  void _confirmDeleteAll() {
    showConfirmationDialog(
      context: context,
      title: "Delete ALL Data?",
      content: "WARNING: This will wipe all payroll history from this device and the cloud. This cannot be undone.",
      isDestructive: true,
      onConfirm: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(kStorageKey);
        await prefs.remove('pay_tracker_data');
        setState(() { periods = []; });
        if (mounted) {
          Provider.of<DataManager>(context, listen: false).syncPayrollToCloud([]);
        }
      }
    );
  }

  void _confirmDeletePeriod(int index) {
    showConfirmationDialog(
      context: context,
      title: "Delete Cutoff?",
      content: "Are you sure you want to delete the cutoff for ${periods[index].name}?",
      isDestructive: true,
      onConfirm: () {
        playClickSound(context);
        setState(() { periods.removeAt(index); });
        _saveData();
      }
    );
  }

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
      onDeleteAll: _confirmDeleteAll, // Passed the confirmation method
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
    // Wait for return to refresh UI totals
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PeriodDetailScreen(
      period: period, 
      use24HourFormat: widget.use24HourFormat,
      shiftStart: widget.shiftStart,
      shiftEnd: widget.shiftEnd,
    )));
    _saveData();
    setState(() {});
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
            title: const Text("Payroll Cutoffs", style: TextStyle(fontWeight: FontWeight.bold)),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.sort),
                tooltip: "Sort",
                onPressed: () => _sortPeriods('newest'), 
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: "Settings",
                onPressed: _openSettings,
              ),
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
                    return [const PopupMenuItem(value: 'login', child: Text("Log In to Sync"))];
                  }
                  return [
                    PopupMenuItem(enabled: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Signed in as:", style: TextStyle(fontSize: 10, color: Colors.grey)), Text(dataManager.userEmail ?? "User", style: TextStyle(fontWeight: FontWeight.bold))])),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, color: Colors.red, size: 20), SizedBox(width: 8), Text("Logout", style: TextStyle(color: Colors.red))])),
                  ];
                },
                onSelected: (value) {
                  if (value == 'logout') {
                    dataManager.logout().then((_) { if (mounted) _loadData(); });
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
                        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
                      )
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: periods.length,
                  itemBuilder: (context, index) {
                    final p = periods[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openPeriod(p),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text("${p.shifts.length} Shifts", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("₱${currency.format(p.getTotalPay(widget.shiftStart, widget.shiftEnd))}", 
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.green)),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => _confirmDeletePeriod(index),
                                    child: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
          // SYNC FAB WITH RED DOT
          floatingActionButton: Stack(
            alignment: Alignment.topRight,
            children: [
              FloatingActionButton(
                onPressed: (!dataManager.isGuest) ? _performManualSync : () {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Login required to sync.")));
                },
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.cloud_sync, color: Colors.white),
              ),
              if (_isUnsynced && !dataManager.isGuest)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}