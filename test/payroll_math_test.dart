import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Ensure this package name matches your pubspec.yaml (likely 'work_app')
import 'package:work_app/utils/calculations.dart'; 

void main() {
  group('Payroll Calculator Tests', () {

    // --- 1. CORE UTILS TESTS ---
    
    test('timeToDouble converts TimeOfDay to double correctly', () {
      expect(PayrollCalculator.timeToDouble(const TimeOfDay(hour: 8, minute: 30)), 8.5);
      expect(PayrollCalculator.timeToDouble(const TimeOfDay(hour: 17, minute: 0)), 17.0);
      expect(PayrollCalculator.timeToDouble(const TimeOfDay(hour: 17, minute: 15)), 17.25);
    });

    test('roundTime rounds START times UP to next 30 min block', () {
      // 8:05 -> Should start paying at 8:30
      final t1 = PayrollCalculator.roundTime(const TimeOfDay(hour: 8, minute: 5), isStart: true);
      expect(t1.hour, 8);
      expect(t1.minute, 30);

      // 8:00 -> Stays 8:00
      final t2 = PayrollCalculator.roundTime(const TimeOfDay(hour: 8, minute: 0), isStart: true);
      expect(t2.hour, 8);
      expect(t2.minute, 0);

      // 8:35 -> 9:00
      final t3 = PayrollCalculator.roundTime(const TimeOfDay(hour: 8, minute: 35), isStart: true);
      expect(t3.hour, 9);
      expect(t3.minute, 0);
    });

    test('roundTime rounds END times DOWN to previous 30 min block', () {
      // 17:25 -> Should stop paying at 17:00
      final t1 = PayrollCalculator.roundTime(const TimeOfDay(hour: 17, minute: 25), isStart: false);
      expect(t1.hour, 17);
      expect(t1.minute, 0);

      // 17:30 -> Stays 17:30
      final t2 = PayrollCalculator.roundTime(const TimeOfDay(hour: 17, minute: 30), isStart: false);
      expect(t2.hour, 17);
      expect(t2.minute, 30);
    });

    // --- 2. LATE CALCULATOR TESTS ---

    test('calculateLateMinutes counts strictly late arrivals', () {
      final start = const TimeOfDay(hour: 8, minute: 0);
      
      // 8:15 -> 15 mins late
      expect(PayrollCalculator.calculateLateMinutes(const TimeOfDay(hour: 8, minute: 15), start), 15);
      
      // 8:00 -> 0 mins late (On time)
      expect(PayrollCalculator.calculateLateMinutes(const TimeOfDay(hour: 8, minute: 0), start), 0);
      
      // 7:55 -> 0 mins late (Early)
      expect(PayrollCalculator.calculateLateMinutes(const TimeOfDay(hour: 7, minute: 55), start), 0);
    });

    // --- 3. REGULAR HOURS TESTS ---

    test('calculateRegularHours basic 8-5 shift (9 hours - 1 hour lunch = 8.0)', () {
      final start = const TimeOfDay(hour: 8, minute: 0);
      final end = const TimeOfDay(hour: 17, minute: 0);
      
      double hours = PayrollCalculator.calculateRegularHours(
        rawIn: const TimeOfDay(hour: 8, minute: 0), 
        rawOut: const TimeOfDay(hour: 17, minute: 0), 
        shiftStart: start, 
        shiftEnd: end, 
        isLateEnabled: true
      );

      expect(hours, 8.0);
    });

    test('calculateRegularHours handles half day (8-12) correctly (No lunch deduction)', () {
      final start = const TimeOfDay(hour: 8, minute: 0);
      final end = const TimeOfDay(hour: 17, minute: 0);
      
      // 8:00 to 12:00 = 4 hours. Lunch deduction only happens if you cross 12:00-13:00.
      double hours = PayrollCalculator.calculateRegularHours(
        rawIn: const TimeOfDay(hour: 8, minute: 0), 
        rawOut: const TimeOfDay(hour: 12, minute: 0), 
        shiftStart: start, 
        shiftEnd: end, 
        isLateEnabled: true
      );

      expect(hours, 4.0);
    });

    test('calculateRegularHours caps hours at shift end (No unauthorized OT in regular hours)', () {
      final start = const TimeOfDay(hour: 8, minute: 0);
      final end = const TimeOfDay(hour: 17, minute: 0);
      
      // User worked until 19:00, but regular hours should stop at 17:00
      double hours = PayrollCalculator.calculateRegularHours(
        rawIn: const TimeOfDay(hour: 8, minute: 0), 
        rawOut: const TimeOfDay(hour: 19, minute: 0), 
        shiftStart: start, 
        shiftEnd: end, 
        isLateEnabled: true
      );

      expect(hours, 8.0); // Caps at 17:00 (minus lunch)
    });

    test('calculateRegularHours strict pay rounding check', () {
      final start = const TimeOfDay(hour: 8, minute: 0);
      final end = const TimeOfDay(hour: 17, minute: 0);
      
      // Logged out at 12:25.
      // If roundEndTime is TRUE: rounds down to 12:00. 
      // Duration: 8:00 to 12:00 = 4.0 hours.
      double hours = PayrollCalculator.calculateRegularHours(
        rawIn: const TimeOfDay(hour: 8, minute: 0), 
        rawOut: const TimeOfDay(hour: 12, minute: 25), 
        shiftStart: start, 
        shiftEnd: end, 
        isLateEnabled: true,
        roundEndTime: true,
      );

      expect(hours, 4.0);
    });

    // --- 4. OVERTIME TESTS ---

    test('calculateOvertimeHours works correctly', () {
      final shiftEnd = const TimeOfDay(hour: 17, minute: 0);
      
      // Out at 19:00 -> 2 hours OT
      expect(PayrollCalculator.calculateOvertimeHours(const TimeOfDay(hour: 19, minute: 0), shiftEnd), 2.0);
      
      // Out at 17:00 -> 0 hours OT
      expect(PayrollCalculator.calculateOvertimeHours(const TimeOfDay(hour: 17, minute: 0), shiftEnd), 0.0);
    });

    test('calculateOvertimeHours applies rounding', () {
      final shiftEnd = const TimeOfDay(hour: 17, minute: 0);
      
      // Out at 18:25 -> Rounds down to 18:00.
      // OT = 18.0 - 17.0 = 1.0 hours.
      expect(PayrollCalculator.calculateOvertimeHours(const TimeOfDay(hour: 18, minute: 25), shiftEnd), 1.0);
    });
  });
}