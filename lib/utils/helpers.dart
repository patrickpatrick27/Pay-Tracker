import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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

TimeOfDay roundTime(TimeOfDay time, {required bool isStart}) {
  int totalMinutes = time.hour * 60 + time.minute;
  int remainder = totalMinutes % 30;
  // int roundedMinutes = totalMinutes; // Unused variable removed

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