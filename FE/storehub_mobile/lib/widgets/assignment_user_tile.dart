import 'package:flutter/material.dart';

/// Shared, quiet presentation for assigning managers and staff.
class AssignmentUserTile extends StatelessWidget {
  final String name;
  final String email;
  final String? status;
  final String actionLabel;
  final bool busy;
  final VoidCallback? onAssign;

  const AssignmentUserTile(
      {super.key,
      required this.name,
      required this.email,
      this.status,
      this.actionLabel = 'Gán',
      this.busy = false,
      this.onAssign});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(children: [
          const CircleAvatar(
              backgroundColor: Color(0xFFF1F5F9),
              foregroundColor: Color(0xFF334155),
              child: Icon(Icons.person_outline)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(email,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF64748B))),
                if (status != null) ...[
                  const SizedBox(height: 5),
                  Text(status!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B))),
                ],
              ])),
          const SizedBox(width: 8),
          SizedBox(
              width: 76,
              child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: busy ? null : onAssign,
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(actionLabel))),
        ]),
      ),
    );
  }
}
