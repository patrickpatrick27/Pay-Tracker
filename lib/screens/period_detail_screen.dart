import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/data_models.dart';
import '../utils/helpers.dart';
import '../widgets/custom_pickers.dart';

class PeriodDetailScreen extends StatefulWidget {
  final PayPeriod period;
  final bool use24HourFormat;
  final TimeOfDay shiftStart;
  final TimeOfDay shiftEnd;
  
  const PeriodDetailScreen({
    super.key, 
    required this.period, 
    required this.use24HourFormat,
    required this.shiftStart,
    required this.shiftEnd,
  });

  @override
  State<PeriodDetailScreen> createState() => _PeriodDetailScreenState();
}

class _PeriodDetailScreenState extends State<PeriodDetailScreen> {
  late TextEditingController _rateController;
  final NumberFormat currency = NumberFormat("#,##0.00", "en_US");

  @override
  void initState() {
    super.initState();
    _rateController = TextEditingController(text: widget.period.hourlyRate.toString());
  }

  void _editPeriodDates() async {
    playClickSound(context);
    DateTime? newStart = await showFastDatePicker(context, widget.period.start);
    if (newStart == null) return;

    if (!mounted) return;
    DateTime? newEnd = await showFastDatePicker(context, widget.period.end, minDate: newStart);
    if (newEnd == null) return;

    setState(() {
      widget.period.start = newStart;
      widget.period.end = newEnd;
      widget.period.updateName();
      widget.period.lastEdited = DateTime.now();
    });
  }

  void _showShiftDialog({Shift? existingShift}) async {
    playClickSound(context);

    DateTime tempDate = existingShift?.date ?? widget.period.start;
    if (existingShift == null) {
      DateTime now = DateTime.now();
      if (now.isAfter(widget.period.start) && now.isBefore(widget.period.end)) tempDate = now;
    }

    TimeOfDay tIn = existingShift?.rawTimeIn ?? widget.shiftStart;
    TimeOfDay tOut = existingShift?.rawTimeOut ?? widget.shiftEnd;
    
    bool isManual = existingShift?.isManualPay ?? false;
    TextEditingController manualCtrl = TextEditingController(text: existingShift?.manualAmount.toString() ?? "0");

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color dlgBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: dlgBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(existingShift == null ? "Add Shift" : "Edit Shift", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
                    ],
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async {
                      DateTime? picked = await showFastDatePicker(context, tempDate);
                      if (picked != null) setModalState(() => tempDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, color: Colors.blue),
                          const SizedBox(width: 12),
                          const Text("Date: ", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          Text(DateFormat('MMM d, yyyy').format(tempDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("I don't know my time", style: TextStyle(fontWeight: FontWeight.w500)),
                      Switch(value: isManual, activeColor: Colors.blue, onChanged: (val) { playClickSound(context); setModalState(() => isManual = val); }),
                    ],
                  ),
                  const Divider(height: 24),
                  if (!isManual) ...[
                     Row(
                       children: [
                         Expanded(
                           child: GestureDetector(
                             onTap: () async {
                               final t = await showFastTimePicker(context, tIn, widget.use24HourFormat);
                               if (t!=null) setModalState(() => tIn = t);
                             },
                             child: Container(
                               padding: const EdgeInsets.all(16),
                               decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.2))),
                               child: Column(
                                 children: [
                                   const Text("TIME IN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                                   const SizedBox(height: 4),
                                   Text(formatTime(context, tIn, widget.use24HourFormat), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                 ],
                                ),
                             ),
                           ),
                         ),
                         const SizedBox(width: 12),
                         Expanded(
                           child: GestureDetector(
                             onTap: () async {
                               final t = await showFastTimePicker(context, tOut, widget.use24HourFormat);
                               if (t!=null) setModalState(() => tOut = t);
                             },
                             child: Container(
                               padding: const EdgeInsets.all(16),
                               decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.2))),
                               child: Column(
                                 children: [
                                   const Text("TIME OUT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                                   const SizedBox(height: 4),
                                   Text(formatTime(context, tOut, widget.use24HourFormat), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                 ],
                               ),
                             ),
                           ),
                         ),
                       ],
                     ),
                  ] else ...[
                     TextField(
                       controller: manualCtrl, keyboardType: TextInputType.number,
                       style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                       decoration: const InputDecoration(labelText: "Enter Amount", border: OutlineInputBorder(), prefixText: "₱ "),
                     )
                  ],
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text("SAVE SHIFT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      onPressed: () { playClickSound(context); Navigator.pop(context, true); },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      }
    ).then((saved) {
      if (saved == true) {
        setState(() {
          if (existingShift != null) {
            existingShift.date = tempDate;
            existingShift.rawTimeIn = tIn; existingShift.rawTimeOut = tOut;
            existingShift.isManualPay = isManual; existingShift.manualAmount = double.tryParse(manualCtrl.text) ?? 0.0;
          } else {
            widget.period.shifts.add(Shift(
              id: const Uuid().v4(), date: tempDate, rawTimeIn: tIn, rawTimeOut: tOut,
              isManualPay: isManual, manualAmount: double.tryParse(manualCtrl.text) ?? 0.0,
            ));
          }
          widget.period.shifts.sort((a, b) => b.date.compareTo(a.date));
          widget.period.lastEdited = DateTime.now();
        });
        final prefs = SharedPreferences.getInstance().then((p) {}); 
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _editPeriodDates,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.period.name),
              const SizedBox(width: 8),
              Icon(Icons.edit, size: 16, color: subTextColor),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("HOURLY RATE", style: TextStyle(fontWeight: FontWeight.bold, color: subTextColor)),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _rateController, keyboardType: TextInputType.number, textAlign: TextAlign.right,
                          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                          decoration: const InputDecoration(border: InputBorder.none, prefixText: "₱ "),
                          onChanged: (val) {
                            setState(() {
                              widget.period.hourlyRate = double.tryParse(val) ?? 50;
                              widget.period.lastEdited = DateTime.now();
                            });
                          },
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text("₱ ${currency.format(widget.period.getTotalPay(widget.shiftStart, widget.shiftEnd))}", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
                Text("TOTAL PAYOUT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: subTextColor, letterSpacing: 1.5)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatBox("REGULAR HRS", widget.period.getTotalRegularHours(widget.shiftStart, widget.shiftEnd).toStringAsFixed(1), Theme.of(context).textTheme.bodyLarge!.color!, subTextColor),
                    Container(width: 1, height: 30, color: Colors.grey[300]),
                    _buildStatBox("OVERTIME HRS", widget.period.getTotalOvertimeHours(widget.shiftStart, widget.shiftEnd).toStringAsFixed(1), Colors.blue, subTextColor),
                  ],
                )
              ],
            ),
          ),
          Expanded(
            child: widget.period.shifts.isEmpty 
              ? Center(child: Text("Tap '+' to add a work day", style: TextStyle(color: subTextColor)))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 20, bottom: 100, left: 16, right: 16),
                  itemCount: widget.period.shifts.length,
                  itemBuilder: (ctx, i) {
                    final s = widget.period.shifts[i];
                    return Dismissible(
                      key: Key(s.id),
                      direction: DismissDirection.endToStart,
                      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.delete, color: Colors.white)),
                      confirmDismiss: (direction) async {
                          playClickSound(context);
                          return await showDialog(context: context, builder: (ctx) => AlertDialog(
                            title: const Text("Delete Shift?"), content: const Text("Are you sure you want to remove this work day?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                            ],
                          ));
                      },
                      onDismissed: (direction) { playClickSound(context); setState(() { widget.period.shifts.removeAt(i); widget.period.lastEdited = DateTime.now(); }); },
                      child: GestureDetector(
                        onTap: () => _showShiftDialog(existingShift: s), 
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  children: [
                                    Text(DateFormat('MMM').format(s.date).toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    Text(DateFormat('dd').format(s.date), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (s.isManualPay)
                                      Text("Flat Pay: ₱${currency.format(s.manualAmount)}", style: const TextStyle(fontWeight: FontWeight.bold))
                                    else ...[
                                      Text("${formatTime(context, s.rawTimeIn, widget.use24HourFormat)} - ${formatTime(context, s.rawTimeOut, widget.use24HourFormat)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      RichText(
                                        text: TextSpan(
                                          style: TextStyle(color: subTextColor, fontSize: 12),
                                          children: [
                                            TextSpan(text: "Reg: ${s.getRegularHours(widget.shiftStart, widget.shiftEnd).toStringAsFixed(1)}"),
                                            if (s.getOvertimeHours(widget.shiftStart, widget.shiftEnd) > 0)
                                              TextSpan(text: " • OT: ${s.getOvertimeHours(widget.shiftStart, widget.shiftEnd).toStringAsFixed(1)}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                          ]
                                        ),
                                      )
                                    ]
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showShiftDialog(), 
        icon: const Icon(Icons.add, color: Colors.white), label: const Text("Add Shift", style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color valueColor, Color labelColor) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: valueColor)),
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: labelColor)),
    ]);
  }
}