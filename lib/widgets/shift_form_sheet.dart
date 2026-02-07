import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/data_models.dart';
import '../utils/helpers.dart';
import '../services/audio_service.dart';
import 'custom_pickers.dart';

class ShiftFormSheet extends StatefulWidget {
  final Shift? existingShift;
  final DateTime defaultDate;
  final TimeOfDay defaultStart;
  final TimeOfDay defaultEnd;
  final bool use24HourFormat;
  final String currencySymbol;
  final List<Shift> currentShifts; // To check for duplicates

  const ShiftFormSheet({
    super.key,
    this.existingShift,
    required this.defaultDate,
    required this.defaultStart,
    required this.defaultEnd,
    required this.use24HourFormat,
    required this.currencySymbol,
    required this.currentShifts,
  });

  @override
  State<ShiftFormSheet> createState() => _ShiftFormSheetState();
}

class _ShiftFormSheetState extends State<ShiftFormSheet> {
  late DateTime tempDate;
  late TimeOfDay tIn;
  late TimeOfDay tOut;
  late bool isManual;
  late bool isHoliday;
  late TextEditingController multiplierCtrl;
  late TextEditingController manualCtrl;
  late TextEditingController remarksCtrl;

  @override
  void initState() {
    super.initState();
    final s = widget.existingShift;
    tempDate = s?.date ?? widget.defaultDate;
    tIn = s?.rawTimeIn ?? widget.defaultStart;
    tOut = s?.rawTimeOut ?? widget.defaultEnd;
    isManual = s?.isManualPay ?? false;
    isHoliday = s?.isHoliday ?? false;
    multiplierCtrl = TextEditingController(text: s != null ? s.holidayMultiplier.toStringAsFixed(0) : "30");
    manualCtrl = TextEditingController(text: s?.manualAmount.toString() ?? "0");
    remarksCtrl = TextEditingController(text: s?.remarks ?? "");
  }

  void _submit() {
    AudioService().playClick();
    
    // Validation
    if (!isManual) {
      double inVal = tIn.hour + tIn.minute / 60.0;
      double outVal = tOut.hour + tOut.minute / 60.0;
      if (inVal >= outVal) {
        Navigator.pop(context, "INVALID_TIME");
        return;
      }
    }

    if (widget.existingShift == null && isDuplicateShift(widget.currentShifts, tempDate)) {
      Navigator.pop(context, "DUPLICATE_DATE");
      return;
    }

    // Create Result
    final resultShift = Shift(
      id: widget.existingShift?.id ?? const Uuid().v4(),
      date: tempDate,
      rawTimeIn: tIn,
      rawTimeOut: tOut,
      isManualPay: isManual,
      manualAmount: double.tryParse(manualCtrl.text) ?? 0.0,
      remarks: remarksCtrl.text.trim(),
      isHoliday: isHoliday,
      holidayMultiplier: double.tryParse(multiplierCtrl.text) ?? 0.0,
    );

    Navigator.pop(context, resultShift);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(widget.existingShift == null ? "Add Shift" : "Edit Shift", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.grey))
            ]),
            const SizedBox(height: 20),

            // Date Picker
            GestureDetector(
              onTap: () async {
                DateTime? picked = await showFastDatePicker(context, tempDate);
                if (picked != null) setState(() => tempDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(CupertinoIcons.calendar, color: Colors.blue),
                  const SizedBox(width: 12),
                  Text(DateFormat('MMM d, yyyy').format(tempDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // Manual Toggle
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Manual Pay Override", style: TextStyle(fontWeight: FontWeight.w500)),
              CupertinoSwitch(value: isManual, activeColor: Colors.blue, onChanged: (val) { AudioService().playClick(); setState(() => isManual = val); })
            ]),
            const Divider(height: 24),

            if (!isManual) ...[
              // Time Pickers
              Row(children: [
                Expanded(child: _buildTimeBox(context, "IN", tIn, (t) => setState(() => tIn = t))),
                const SizedBox(width: 12),
                Expanded(child: _buildTimeBox(context, "OUT", tOut, (t) => setState(() => tOut = t))),
              ]),
              const SizedBox(height: 20),

              // Holiday Toggle (Simplified for brevity, insert your fancy animation here if desired)
              Container(
                decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(4),
                child: Row(children: [
                  _buildToggleOption("Regular", !isHoliday, () => setState(() => isHoliday = false), primaryColor),
                  _buildToggleOption("Holiday / Rest", isHoliday, () => setState(() => isHoliday = true), Colors.orange),
                ]),
              ),
              
              if (isHoliday)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: multiplierCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Percent Increase (%)", suffixText: "%",
                      filled: true, fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
            ] else ...[
              TextField(
                controller: manualCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: "Amount", prefixText: "${widget.currencySymbol} ", border: const OutlineInputBorder()),
              )
            ],

            const SizedBox(height: 16),
            TextField(
              controller: remarksCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: "Remarks (Optional)",
                filled: true, fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _submit,
              child: const Text("Save Shift", style: TextStyle(fontWeight: FontWeight.bold)),
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBox(BuildContext context, String label, TimeOfDay time, Function(TimeOfDay) onTap) {
    return GestureDetector(
      onTap: () async {
        final t = await showFastTimePicker(context, time, widget.use24HourFormat);
        if (t != null) onTap(t);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.2))),
        child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 4),
          Text(formatTime(context, time, widget.use24HourFormat), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _buildToggleOption(String label, bool isActive, VoidCallback onTap, Color activeColor) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: isActive ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF404040) : Colors.white) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? activeColor : Colors.grey)),
        ),
      ),
    );
  }
}