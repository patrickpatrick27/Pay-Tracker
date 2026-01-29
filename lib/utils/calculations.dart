import 'package:flutter/material.dart';

class PayrollCalculator {
  
  // --- CORE TIME MATH ---

  static double timeToDouble(TimeOfDay t) => t.hour + t.minute / 60.0;

  static TimeOfDay roundTime(TimeOfDay time, {required bool isStart}) {
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

  // --- PHILIPPINE LABOR CODE: LATE DEDUCTIONS ---
  
  static int calculateLateMinutes(TimeOfDay actualIn, TimeOfDay shiftStart) {
    int startMins = shiftStart.hour * 60 + shiftStart.minute;
    int inMins = actualIn.hour * 60 + actualIn.minute;
    
    // Only deduct if they arrived AFTER the start time
    if (inMins > startMins) {
      return inMins - startMins;
    }
    return 0;
  }

  // --- HOURS CALCULATION (Pure logic, no Shift object dependency) ---

  static double calculateRegularHours(TimeOfDay rawIn, TimeOfDay rawOut, TimeOfDay shiftStart, TimeOfDay shiftEnd) {
    // 1. Get Rounded Times
    TimeOfDay paidIn = roundTime(rawIn, isStart: true);
    TimeOfDay paidOut = roundTime(rawOut, isStart: false);

    // 2. Ensure Paid Time In isn't earlier than Global Shift Start
    double rVal = timeToDouble(paidIn);
    double sVal = timeToDouble(shiftStart);
    if (rVal < sVal) paidIn = shiftStart;

    // 3. Calculate Duration
    double start = timeToDouble(paidIn);
    double end = timeToDouble(paidOut);
    double limit = timeToDouble(shiftEnd);

    // Cap at shift end (Regular hours stop at shift end)
    double actualEnd = (end > limit) ? limit : end;
    
    // Handle overnight shifts (crossing midnight)
    if (actualEnd < start) actualEnd += 24;

    double duration = actualEnd - start;

    // 4. Deduct Lunch Break (Auto-deduct 1 hour if working through 12-1 PM)
    if (start <= 12.0 && actualEnd >= 13.0) duration -= 1.0;

    return duration > 0 ? duration : 0;
  }

  static double calculateOvertimeHours(TimeOfDay rawIn, TimeOfDay rawOut, TimeOfDay shiftEnd) {
    TimeOfDay paidOut = roundTime(rawOut, isStart: false);
    double end = timeToDouble(paidOut);
    double limit = timeToDouble(shiftEnd);

    // Handle overnight logic for OT if needed, but standard logic:
    if (end > limit) {
      return end - limit;
    }
    return 0.0;
  }
}