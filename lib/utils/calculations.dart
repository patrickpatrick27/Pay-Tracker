import 'package:flutter/material.dart';

class PayrollCalculator {
  
  // --- CORE UTILS ---

  static double timeToDouble(TimeOfDay t) => t.hour + t.minute / 60.0;

  // Standard 30-minute block rounding
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

  // --- LATE CALCULATOR ---
  
  static int calculateLateMinutes(TimeOfDay actualIn, TimeOfDay shiftStart) {
    double actualVal = timeToDouble(actualIn);
    double startVal = timeToDouble(shiftStart);

    // Only count as late if they arrive STRICTLY after shift start
    if (actualVal > startVal) {
      int startMins = shiftStart.hour * 60 + shiftStart.minute;
      int inMins = actualIn.hour * 60 + actualIn.minute;
      return inMins - startMins;
    }
    return 0;
  }

  // --- HOURS CALCULATOR ---

  static double calculateRegularHours({
    required TimeOfDay rawIn, 
    required TimeOfDay rawOut, 
    required TimeOfDay shiftStart, 
    required TimeOfDay shiftEnd,
    required bool isLateEnabled,
    bool roundEndTime = true, // NEW: Controls strict pay vs. display duration
  }) {
    // 1. DETERMINE EFFECTIVE START TIME
    TimeOfDay effectiveIn;
    
    if (isLateEnabled) {
      // Logic A: "Base - Penalty"
      // Assume Shift Start (8:00) to allow full hours, specific penalty subtracted later.
      effectiveIn = shiftStart; 
      
      // If early (7:50), still clamp to 8:00.
      if (timeToDouble(rawIn) < timeToDouble(shiftStart)) {
        effectiveIn = shiftStart; 
      }
    } else {
      // Logic B: "Rounding"
      effectiveIn = roundTime(rawIn, isStart: true);
      if (timeToDouble(effectiveIn) < timeToDouble(shiftStart)) {
        effectiveIn = shiftStart;
      }
    }

    // 2. DETERMINE EFFECTIVE END TIME
    // If roundEndTime is TRUE (for Pay), we round 8:59 -> 8:30.
    // If roundEndTime is FALSE (for Display), we use 8:59.
    TimeOfDay effectiveOut = roundEndTime ? roundTime(rawOut, isStart: false) : rawOut;

    // 3. CALCULATE DURATION
    double start = timeToDouble(effectiveIn);
    double end = timeToDouble(effectiveOut);
    double limit = timeToDouble(shiftEnd);

    // Cap at shift end
    double actualEnd = (end > limit) ? limit : end;
    
    // Handle overnight shifts
    if (actualEnd < start) actualEnd += 24;

    double duration = actualEnd - start;

    // 4. LUNCH BREAK (Standard 1 Hour deduction)
    if (start <= 12.0 && actualEnd >= 13.0) duration -= 1.0;

    return duration > 0 ? duration : 0;
  }

  static double calculateOvertimeHours(TimeOfDay rawOut, TimeOfDay shiftEnd) {
    TimeOfDay paidOut = roundTime(rawOut, isStart: false);
    double end = timeToDouble(paidOut);
    double limit = timeToDouble(shiftEnd);
    
    if (end > limit) {
      return end - limit;
    }
    return 0.0;
  }
}