import 'dart:convert';
import 'package:flutter/material.dart';

class SyncConflictDialog extends StatelessWidget {
  final String localJson;
  final String cloudJson;
  final VoidCallback onKeepCloud;
  final VoidCallback onKeepDevice;

  const SyncConflictDialog({
    super.key,
    required this.localJson,
    required this.cloudJson,
    required this.onKeepCloud,
    required this.onKeepDevice,
  });

  int _countTotalShifts(List<dynamic> periodList) {
    int total = 0;
    for (var p in periodList) {
      if (p['shifts'] != null) total += (p['shifts'] as List).length;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    List localList = jsonDecode(localJson);
    List cloudList = jsonDecode(cloudJson);
    int localShifts = _countTotalShifts(localList);
    int cloudShifts = _countTotalShifts(cloudList);

    return AlertDialog(
      title: const Text("Sync Conflict"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("The data on your device is different from the Cloud."),
          const SizedBox(height: 16),
          _buildRow(Icons.phone_android, "This Device", "${localList.length} Cutoffs • $localShifts Shifts", Colors.blue),
          const SizedBox(height: 8),
          _buildRow(Icons.cloud, "Google Drive", "${cloudList.length} Cutoffs • $cloudShifts Shifts", Colors.orange),
          const SizedBox(height: 16),
          const Text("Which version do you want to keep?", style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        TextButton(onPressed: () { Navigator.pop(context); onKeepCloud(); }, child: const Text("Keep Cloud")),
        FilledButton(onPressed: () { Navigator.pop(context); onKeepDevice(); }, child: const Text("Keep Device")),
      ],
    );
  }

  Widget _buildRow(IconData icon, String label, String sub, Color color) {
    return Row(children: [
      Icon(icon, color: color),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ])
    ]);
  }
}