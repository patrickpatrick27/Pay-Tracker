import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/helpers.dart';
import '../utils/calculations.dart'; // Import the new calculator

class Shift {
  String id;
  DateTime date;
  TimeOfDay rawTimeIn;
  TimeOfDay rawTimeOut;
  bool isManualPay; 
  double manualAmount;

  Shift({
    required this.id,
    required this.date,
    required this.rawTimeIn,
    required this.rawTimeOut,
    this.isManualPay = false,
    this.manualAmount = 0.0,
  });

  // Duplicate Check Helper
  @override
  bool operator ==(Object other) =>
      other is Shift &&
      other.date.year == date.year &&
      other.date.month == date.month &&
      other.date.day == date.day;

  @override
  int get hashCode => date.hashCode;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'rawTimeIn': '${rawTimeIn.hour}:${rawTimeIn.minute}',
        'rawTimeOut': '${rawTimeOut.hour}:${rawTimeOut.minute}',
        'isManualPay': isManualPay,
        'manualAmount': manualAmount,
      };

  factory Shift.fromJson(Map<String, dynamic> json) {
    final tIn = json['rawTimeIn'].split(':');
    final tOut = json['rawTimeOut'].split(':');
    return Shift(
      id: json['id'],
      date: DateTime.parse(json['date']),
      rawTimeIn: TimeOfDay(hour: int.parse(tIn[0]), minute: int.parse(tIn[1])),
      rawTimeOut: TimeOfDay(hour: int.parse(tOut[0]), minute: int.parse(tOut[1])),
      isManualPay: json['isManualPay'] ?? false,
      manualAmount: (json['manualAmount'] ?? 0.0).toDouble(),
    );
  }

  // --- SHORTCUTS TO CALCULATOR (Single Shift) ---
  // These allow you to do shift.getRegularHours() if needed
  double getRegularHours(TimeOfDay globalStart, TimeOfDay globalEnd) {
    return PayrollCalculator.getRegularHours(this, globalStart, globalEnd);
  }

  double getOvertimeHours(TimeOfDay globalStart, TimeOfDay globalEnd) {
    return PayrollCalculator.getOvertimeHours(this, globalEnd);
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
        'id': id, 'name': name, 'start': start.toIso8601String(), 'end': end.toIso8601String(),
        'lastEdited': lastEdited.toIso8601String(), 'hourlyRate': hourlyRate,
        'shifts': shifts.map((s) => s.toJson()).toList(),
      };

  factory PayPeriod.fromJson(Map<String, dynamic> json) {
    return PayPeriod(
      id: json['id'], name: json['name'],
      start: DateTime.parse(json['start']), end: DateTime.parse(json['end']),
      lastEdited: json['lastEdited'] != null ? DateTime.parse(json['lastEdited']) : DateTime.now(),
      hourlyRate: json['hourlyRate'].toDouble(),
      shifts: (json['shifts'] as List).map((s) => Shift.fromJson(s)).toList(),
    );
  }

  // --- RESTORED CONVENIENCE METHODS (Bridging to Calculator) ---

  // 1. Total Pay
  double getTotalPay(TimeOfDay startShift, TimeOfDay endShift) {
    return PayrollCalculator.calculateTotalPay(this, startShift, endShift);
  }

  // 2. Total Regular Hours
  double getTotalRegularHours(TimeOfDay startShift, TimeOfDay endShift) {
    double sum = 0;
    for (var s in shifts) {
      sum += PayrollCalculator.getRegularHours(s, startShift, endShift);
    }
    return sum;
  }
  
  // 3. Total Overtime Hours
  double getTotalOvertimeHours(TimeOfDay startShift, TimeOfDay endShift) {
    double sum = 0;
    for (var s in shifts) {
      sum += PayrollCalculator.getOvertimeHours(s, endShift);
    }
    return sum;
  }

  void updateName() {
    name = "${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}";
  }
}