import 'package:flutter/material.dart';
import '../models/data_models.dart';

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

  static double calculateLateDeductionAmount(int lateMinutes, double hourlyRate) {
    // Formula: (Hourly Rate / 60) * Late Minutes
    if (lateMinutes <= 0) return 0.0;
    double minuteRate = hourlyRate / 60.0;
    return minuteRate * lateMinutes;
  }

  // --- PAYROLL HOURS CALCULATION ---

  static double getRegularHours(Shift shift, TimeOfDay globalStart, TimeOfDay globalEnd) {
    if (shift.isManualPay) return 0;

    // 1. Get Rounded Times
    TimeOfDay paidIn = roundTime(shift.rawTimeIn, isStart: true);
    TimeOfDay paidOut = roundTime(shift.rawTimeOut, isStart: false);

    // 2. Ensure Paid Time In isn't earlier than Global Shift Start
    double rVal = timeToDouble(paidIn);
    double sVal = timeToDouble(globalStart);
    if (rVal < sVal) paidIn = globalStart;

    // 3. Calculate Duration
    double start = timeToDouble(paidIn);
    double end = timeToDouble(paidOut);
    double limit = timeToDouble(globalEnd);

    // Cap at shift end
    double actualEnd = (end > limit) ? limit : end;
    
    // Handle overnight shifts (crossing midnight)
    if (actualEnd < start) actualEnd += 24;

    double duration = actualEnd - start;

    // 4. Deduct Lunch Break (Auto-deduct 1 hour if working through 12-1 PM)
    if (start <= 12.0 && actualEnd >= 13.0) duration -= 1.0;

    return duration > 0 ? duration : 0;
  }

  static double getOvertimeHours(Shift shift, TimeOfDay globalEnd) {
    if (shift.isManualPay) return 0;
    
    TimeOfDay paidOut = roundTime(shift.rawTimeOut, isStart: false);
    double end = timeToDouble(paidOut);
    double limit = timeToDouble(globalEnd);

    if (end > limit) {
      return end - limit;
    }
    return 0;
  }

  // --- TOTALS ---

  static double calculateTotalPay(PayPeriod period, TimeOfDay start, TimeOfDay end) {
    double total = 0;
    
    for (var shift in period.shifts) {
      if (shift.isManualPay) {
        total += shift.manualAmount;
      } else {
        // Base Pay
        double regHours = getRegularHours(shift, start, end);
        double otHours = getOvertimeHours(shift, end);
        double grossShiftPay = (regHours * period.hourlyRate) + (otHours * period.hourlyRate * 1.25);

        // Deduct Late (Exact Minutes)
        // Note: Regular Hours calculation often rounds time, but Lates are usually exact.
        // We calculate late deduction separately and subtract it from the Gross.
        int lateMins = calculateLateMinutes(shift.rawTimeIn, start);
        double lateDeduction = calculateLateDeductionAmount(lateMins, period.hourlyRate);

        total += (grossShiftPay - lateDeduction);
      }
    }
    return total;
  }
}