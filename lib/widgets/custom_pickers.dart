import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/helpers.dart';

Future<TimeOfDay?> showFastTimePicker(BuildContext context, TimeOfDay initial, bool use24h) async {
  playClickSound(context);
  final now = DateTime.now();
  DateTime tempDate = DateTime(now.year, now.month, now.day, initial.hour, initial.minute);
  final bool isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (BuildContext builder) {
      return SizedBox(
        height: 280,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(child: const Text('Cancel', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.of(context).pop()),
                  const Text("Select Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton(
                    child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)), 
                    onPressed: () => Navigator.of(context).pop(TimeOfDay.fromDateTime(tempDate))
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoTheme(
                data: CupertinoThemeData(brightness: isDark ? Brightness.dark : Brightness.light),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: tempDate,
                  use24hFormat: use24h,
                  onDateTimeChanged: (DateTime newDate) => tempDate = newDate,
                ),
              ),
            ),
          ],
        ),
      );
    }
  );
}

Future<DateTime?> showFastDatePicker(BuildContext context, DateTime initial, {DateTime? minDate, DateTime? maxDate}) async {
  playClickSound(context);
  DateTime safeInitial = initial;
  if (minDate != null && initial.isBefore(minDate)) safeInitial = minDate;
  
  DateTime tempDate = safeInitial;
  final bool isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (BuildContext builder) {
      return SizedBox(
        height: 280,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(child: const Text('Cancel', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.of(context).pop()),
                  const Text("Select Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton(
                    child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)), 
                    onPressed: () => Navigator.of(context).pop(tempDate)
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoTheme(
                data: CupertinoThemeData(brightness: isDark ? Brightness.dark : Brightness.light),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: safeInitial,
                  minimumDate: minDate ?? DateTime(2020),
                  maximumDate: maxDate ?? DateTime(2030),
                  onDateTimeChanged: (DateTime newDate) => tempDate = newDate,
                ),
              ),
            ),
          ],
        ),
      );
    }
  );
}