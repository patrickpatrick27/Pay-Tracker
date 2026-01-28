import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/data_models.dart';

void playClickSound(BuildContext context) {
  Feedback.forTap(context);
  SystemSound.play(SystemSoundType.click);
}

double timeToDouble(TimeOfDay t) => t.hour + t.minute / 60.0;

String formatTime(BuildContext context, TimeOfDay time, bool use24h) {
  final now = DateTime.now();
  final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  return DateFormat(use24h ? 'HH:mm' : 'h:mm a').format(dt);
}

// --- NEW HELPERS ---

/// Calculates rate per minute (Philippine Labor Code Standard for Lates)
double calculateMinuteRate(double hourlyRate) {
  return hourlyRate / 60.0;
}

/// Checks if a shift already exists in a list for the same date
bool isDuplicateShift(List<Shift> existingShifts, DateTime newDate) {
  return existingShifts.any((s) => 
    s.date.year == newDate.year &&
    s.date.month == newDate.month &&
    s.date.day == newDate.day
  );
}

/// Reusable Confirmation Dialog (For Delete Cutoff / Delete All)
Future<void> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String content,
  required VoidCallback onConfirm,
  bool isDestructive = false,
}) async {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text(
              isDestructive ? 'Delete' : 'Confirm', 
              style: TextStyle(color: isDestructive ? Colors.red : Colors.blue, fontWeight: FontWeight.bold)
            ),
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
          ),
        ],
      );
    },
  );
}
// -------------------

TimeOfDay roundTime(TimeOfDay time, {required bool isStart}) {
  int totalMinutes = time.hour * 60 + time.minute;
  int remainder = totalMinutes % 30;

  int roundedMinutes;
  if (remainder != 0) {
    if (isStart) {
      roundedMinutes = totalMinutes + (30 - remainder);
    } else {
      roundedMinutes = totalMinutes - remainder;
    }
  } else {
    roundedMinutes = totalMinutes;
  }

  int h = (roundedMinutes ~/ 60) % 24;
  int m = roundedMinutes % 60;
  return TimeOfDay(hour: h, minute: m);
}