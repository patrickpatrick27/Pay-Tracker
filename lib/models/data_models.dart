import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/calculations.dart';

class Shift {
  String id;
  DateTime date;
  TimeOfDay rawTimeIn;
  TimeOfDay rawTimeOut;
  bool isManualPay;
  double manualAmount;
  String remarks;
  bool isHoliday;
  double holidayMultiplier;

  Shift({
    required this.id,
    required this.date,
    required this.rawTimeIn,
    required this.rawTimeOut,
    this.isManualPay = false,
    this.manualAmount = 0.0,
    this.remarks = '',
    this.isHoliday = false,
    this.holidayMultiplier = 30.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    // We standardize on 'timeIn' for the future, but we can read both.
    'timeIn': '${rawTimeIn.hour}:${rawTimeIn.minute}',
    'timeOut': '${rawTimeOut.hour}:${rawTimeOut.minute}',
    'isManualPay': isManualPay,
    'manualAmount': manualAmount,
    'remarks': remarks,
    'isHoliday': isHoliday,
    'holidayMultiplier': holidayMultiplier,
  };

  factory Shift.fromJson(Map<String, dynamic> json) {
    // 1. SAFE TIME PARSER
    TimeOfDay parseTime(String? s) {
      if (s == null || !s.contains(':')) return const TimeOfDay(hour: 8, minute: 0);
      final parts = s.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    // 2. SAFE NUMBER PARSER (Handles Int vs Double)
    double safeDouble(dynamic val, double fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? fallback;
    }

    // 3. THE KEY FIX: Look for 'timeIn' (New) OR 'rawTimeIn' (Old)
    String? inTimeStr = json['timeIn'] ?? json['rawTimeIn'];
    String? outTimeStr = json['timeOut'] ?? json['rawTimeOut'];

    return Shift(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.parse(json['date']),
      
      // Use the resolved time strings
      rawTimeIn: parseTime(inTimeStr),
      rawTimeOut: parseTime(outTimeStr),
      
      isManualPay: json['isManualPay'] ?? false,
      manualAmount: safeDouble(json['manualAmount'], 0.0),
      remarks: json['remarks'] ?? '',
      
      isHoliday: json['isHoliday'] ?? false,
      holidayMultiplier: safeDouble(json['holidayMultiplier'], 30.0),
    );
  }

  // --- SMART LOGIC (Undertime & Lunch Fix) ---

  DateTime get _startDateTime {
    return DateTime(date.year, date.month, date.day, rawTimeIn.hour, rawTimeIn.minute);
  }

  DateTime get _endDateTime {
    DateTime start = _startDateTime;
    DateTime end = DateTime(date.year, date.month, date.day, rawTimeOut.hour, rawTimeOut.minute);

    // FIX: Only treat as "Next Day" if Out is strictly BEFORE In.
    if (end.isBefore(start)) {
      end = end.add(const Duration(days: 1));
    }
    return end;
  }

  double getRegularHours(TimeOfDay shiftStart, TimeOfDay shiftEnd, {bool isLateEnabled = true, bool roundEndTime = true}) {
    if (isManualPay) return 0.0;

    // Adjust Start (Late Logic)
    DateTime standardStart = DateTime(date.year, date.month, date.day, shiftStart.hour, shiftStart.minute);
    DateTime effectiveStart = _startDateTime;
    
    // Only apply grace if late enabled or arrived late
    if (!isLateEnabled && effectiveStart.isAfter(standardStart)) {
      effectiveStart = standardStart; 
    }

    // Adjust End (Undertime Logic)
    DateTime standardEnd = DateTime(date.year, date.month, date.day, shiftEnd.hour, shiftEnd.minute);
    if (standardEnd.isBefore(standardStart)) {
      standardEnd = standardEnd.add(const Duration(days: 1));
    }

    DateTime effectiveEnd = _endDateTime;

    // Cap at Standard End
    if (effectiveEnd.isAfter(standardEnd)) {
      effectiveEnd = standardEnd;
    }

    Duration regularDuration = effectiveEnd.difference(effectiveStart);
    double hours = regularDuration.inMinutes / 60.0;

    // AUTOMATIC UNPAID LUNCH: If shift > 6 hours, deduct 1 hour.
    if (hours > 6.0) {
      hours -= 1.0;
    }

    if (hours < 0) return 0.0; 
    return hours;
  }

  double getOvertimeHours(TimeOfDay shiftStart, TimeOfDay shiftEnd) {
    if (isManualPay) return 0.0;

    DateTime standardEnd = DateTime(date.year, date.month, date.day, shiftEnd.hour, shiftEnd.minute);
    DateTime standardStart = DateTime(date.year, date.month, date.day, shiftStart.hour, shiftStart.minute);
    
    if (standardEnd.isBefore(standardStart)) {
      standardEnd = standardEnd.add(const Duration(days: 1));
    }

    DateTime actualEnd = _endDateTime;

    if (actualEnd.isAfter(standardEnd)) {
      Duration ot = actualEnd.difference(standardEnd);
      return ot.inMinutes / 60.0;
    }
    return 0.0;
  }
}

class PayPeriod {
  String id;
  String name;
  DateTime start;
  DateTime end;
  DateTime lastEdited;
  double hourlyRate;
  List<Shift> shifts;

  PayPeriod({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.lastEdited,
    required this.hourlyRate,
    required this.shifts,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'lastEdited': lastEdited.toIso8601String(),
    'hourlyRate': hourlyRate,
    'shifts': shifts.map((s) => s.toJson()).toList(),
  };

  factory PayPeriod.fromJson(Map<String, dynamic> json) {
    return PayPeriod(
      id: json['id'],
      name: json['name'],
      start: DateTime.parse(json['start']),
      end: DateTime.parse(json['end']),
      lastEdited: json['lastEdited'] != null ? DateTime.parse(json['lastEdited']) : DateTime.now(),
      hourlyRate: (json['hourlyRate'] ?? 50.0).toDouble(),
      shifts: (json['shifts'] as List).map((s) => Shift.fromJson(s)).toList(),
    );
  }
  
  void updateName() {
    name = "${DateFormat('MMM d, yyyy').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}";
  }

  double getTotalRegularHours(TimeOfDay shiftStart, TimeOfDay shiftEnd) {
    return shifts.fold(0.0, (sum, s) => sum + s.getRegularHours(shiftStart, shiftEnd));
  }

  double getTotalOvertimeHours(TimeOfDay shiftStart, TimeOfDay shiftEnd) {
    return shifts.fold(0.0, (sum, s) => sum + s.getOvertimeHours(shiftStart, shiftEnd));
  }
  
  double getTotalPay(TimeOfDay shiftStart, TimeOfDay shiftEnd, {double? hourlyRate, bool enableLate = true, bool enableOt = true}) {
    double rate = hourlyRate ?? this.hourlyRate;
    double total = 0.0;
    
    for (var s in shifts) {
      if (s.isManualPay) {
        total += s.manualAmount;
        continue;
      }

      double reg = s.getRegularHours(shiftStart, shiftEnd, isLateEnabled: enableLate);
      double ot = enableOt ? s.getOvertimeHours(shiftStart, shiftEnd) : 0.0;
      
      double dailyPay = (reg * rate) + (ot * rate * 1.25);

      if (enableLate) {
         int lateMins = PayrollCalculator.calculateLateMinutes(s.rawTimeIn, shiftStart);
         if (lateMins > 0) {
           dailyPay -= (lateMins / 60.0) * rate;
         }
      }
      
      if (s.isHoliday && s.holidayMultiplier > 0) {
        dailyPay += dailyPay * (s.holidayMultiplier / 100.0);
      }
      
      total += (dailyPay > 0 ? dailyPay : 0);
    }
    return total;
  }
}