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
    'timeIn': '${rawTimeIn.hour}:${rawTimeIn.minute}',
    'timeOut': '${rawTimeOut.hour}:${rawTimeOut.minute}',
    'isManualPay': isManualPay,
    'manualAmount': manualAmount,
    'remarks': remarks,
    'isHoliday': isHoliday,
    'holidayMultiplier': holidayMultiplier,
  };

  factory Shift.fromJson(Map<String, dynamic> json) {
    TimeOfDay parseTime(String? s) {
      if (s == null || !s.contains(':')) return const TimeOfDay(hour: 8, minute: 0);
      final parts = s.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    double safeDouble(dynamic val, double fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? fallback;
    }

    String? inTimeStr = json['timeIn'] ?? json['rawTimeIn'];
    String? outTimeStr = json['timeOut'] ?? json['rawTimeOut'];

    return Shift(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.parse(json['date']),
      rawTimeIn: parseTime(inTimeStr),
      rawTimeOut: parseTime(outTimeStr),
      isManualPay: json['isManualPay'] ?? false,
      manualAmount: safeDouble(json['manualAmount'], 0.0),
      remarks: json['remarks'] ?? '',
      isHoliday: json['isHoliday'] ?? false,
      holidayMultiplier: safeDouble(json['holidayMultiplier'], 30.0),
    );
  }

  // --- TIME HELPERS ---
  
  TimeOfDay _snapTime(TimeOfDay raw) {
    int totalMinutes = raw.hour * 60 + raw.minute;
    int roundedMinutes = (totalMinutes / 30).round() * 30;
    int newHour = (roundedMinutes ~/ 60) % 24;
    int newMinute = roundedMinutes % 60;
    return TimeOfDay(hour: newHour, minute: newMinute);
  }

  int _toMins(TimeOfDay t) => t.hour * 60 + t.minute;

  DateTime _getDateTime(TimeOfDay t) {
    return DateTime(date.year, date.month, date.day, t.hour, t.minute);
  }

  double getRegularHours(TimeOfDay shiftStart, TimeOfDay shiftEnd, {bool isLateEnabled = true, bool snapToGrid = true}) {
    if (isManualPay) return 0.0;

    // 1. DETERMINE EFFECTIVE START TIME
    TimeOfDay effectiveIn = rawTimeIn;
    
    if (snapToGrid) {
      // Smart Logic: Snap only if ON TIME or EARLY.
      if (isLateEnabled && _toMins(rawTimeIn) > _toMins(shiftStart)) {
         effectiveIn = rawTimeIn; // Exact time (Late)
      } else {
         effectiveIn = _snapTime(rawTimeIn); // Snap (Early/OnTime)
      }
    }

    // 2. DETERMINE EFFECTIVE END TIME
    TimeOfDay effectiveOut = snapToGrid ? _snapTime(rawTimeOut) : rawTimeOut;

    // 3. CONVERT TO DATETIME
    DateTime startDt = DateTime(date.year, date.month, date.day, effectiveIn.hour, effectiveIn.minute);
    DateTime endDt = DateTime(date.year, date.month, date.day, effectiveOut.hour, effectiveOut.minute);
    
    // Handle Next Day Out
    if (endDt.isBefore(startDt)) {
      endDt = endDt.add(const Duration(days: 1));
    }

    // 4. DEFINE SHIFT BOUNDARIES
    DateTime standardStart = DateTime(date.year, date.month, date.day, shiftStart.hour, shiftStart.minute);
    DateTime standardEnd = DateTime(date.year, date.month, date.day, shiftEnd.hour, shiftEnd.minute);
    
    // Handle overnight standard shift
    if (standardEnd.isBefore(standardStart)) {
       standardEnd = standardEnd.add(const Duration(days: 1));
    }

    // --- NEW LOGIC: STRICT START TIME ---
    // Even if you arrive at 7:00 AM for an 8:00 AM shift, pay starts at 8:00 AM.
    if (startDt.isBefore(standardStart)) {
      startDt = standardStart;
    }

    // Cap at Shift End (Anything after is OT)
    if (endDt.isAfter(standardEnd)) {
      endDt = standardEnd;
    }

    // 5. CALCULATE DURATION
    Duration duration = endDt.difference(startDt);
    double hours = duration.inMinutes / 60.0;

    // 6. AUTOMATIC LUNCH DEDUCTION
    if (hours > 6.0) {
      hours -= 1.0;
    }

    return hours > 0 ? hours : 0.0;
  }

  double getOvertimeHours(TimeOfDay shiftStart, TimeOfDay shiftEnd, {bool snapToGrid = true}) {
    if (isManualPay) return 0.0;

    DateTime standardEnd = DateTime(date.year, date.month, date.day, shiftEnd.hour, shiftEnd.minute);
    DateTime standardStart = DateTime(date.year, date.month, date.day, shiftStart.hour, shiftStart.minute);
    
    if (standardEnd.isBefore(standardStart)) {
      standardEnd = standardEnd.add(const Duration(days: 1));
    }

    TimeOfDay tOut = snapToGrid ? _snapTime(rawTimeOut) : rawTimeOut;
    DateTime actualEnd = DateTime(date.year, date.month, date.day, tOut.hour, tOut.minute);
    
    DateTime startDt = _getDateTime(rawTimeIn);
    if (actualEnd.isBefore(startDt)) {
       actualEnd = actualEnd.add(const Duration(days: 1));
    }

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

  double getTotalPay(TimeOfDay shiftStart, TimeOfDay shiftEnd, {
    double? hourlyRate, 
    bool enableLate = true, 
    bool enableOt = true,
    bool snapToGrid = true 
  }) {
    double rate = hourlyRate ?? this.hourlyRate;
    double total = 0.0;
    
    for (var s in shifts) {
      if (s.isManualPay) {
        total += s.manualAmount;
        continue;
      }

      // Reg hours are now strictly clamped to start time
      double reg = s.getRegularHours(shiftStart, shiftEnd, isLateEnabled: enableLate, snapToGrid: snapToGrid);
      double ot = enableOt ? s.getOvertimeHours(shiftStart, shiftEnd, snapToGrid: snapToGrid) : 0.0;
      
      double dailyPay = (reg * rate) + (ot * rate * 1.25);
      
      // Holiday Multiplier
      if (s.isHoliday && s.holidayMultiplier > 0) {
        dailyPay += dailyPay * (s.holidayMultiplier / 100.0);
      }
      
      total += (dailyPay > 0 ? dailyPay : 0);
    }
    return total;
  }
}