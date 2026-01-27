import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/helpers.dart';

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

  TimeOfDay getPaidTimeIn(TimeOfDay globalShiftStart) {
    TimeOfDay rounded = roundTime(rawTimeIn, isStart: true);
    double rVal = timeToDouble(rounded);
    double sVal = timeToDouble(globalShiftStart);
    return (rVal < sVal) ? globalShiftStart : rounded; 
  }

  TimeOfDay getPaidTimeOut() => roundTime(rawTimeOut, isStart: false);

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

  double getRegularHours(TimeOfDay globalStart, TimeOfDay globalEnd) {
    if (isManualPay) return 0;
    double start = timeToDouble(getPaidTimeIn(globalStart));
    double end = timeToDouble(getPaidTimeOut());
    double shiftEnd = timeToDouble(globalEnd);
    double actualRegularEnd = (end > shiftEnd) ? shiftEnd : end;
    if (actualRegularEnd < start) actualRegularEnd += 24;
    double duration = actualRegularEnd - start;
    if (start <= 12.0 && actualRegularEnd >= 13.0) duration -= 1.0; 
    return duration > 0 ? duration : 0;
  }

  double getOvertimeHours(TimeOfDay globalStart, TimeOfDay globalEnd) {
    if (isManualPay) return 0;
    double end = timeToDouble(getPaidTimeOut());
    double shiftEnd = timeToDouble(globalEnd);
    if (end > shiftEnd) return end - shiftEnd;
    return 0;
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

  double getTotalPay(TimeOfDay start, TimeOfDay end) {
    double total = 0;
    for (var shift in shifts) {
      if (shift.isManualPay) {
        total += shift.manualAmount;
      } else {
        total += (shift.getRegularHours(start, end) * hourlyRate) + 
                 (shift.getOvertimeHours(start, end) * hourlyRate * 1.25);
      }
    }
    return total;
  }

  double getTotalRegularHours(TimeOfDay start, TimeOfDay end) {
    double sum = 0;
    for(var s in shifts) if(!s.isManualPay) sum += s.getRegularHours(start, end);
    return sum;
  }
  
  double getTotalOvertimeHours(TimeOfDay start, TimeOfDay end) {
    double sum = 0;
    for(var s in shifts) if(!s.isManualPay) sum += s.getOvertimeHours(start, end);
    return sum;
  }

  void updateName() {
    name = "${DateFormat('MMM d, yyyy').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}";
  }
}