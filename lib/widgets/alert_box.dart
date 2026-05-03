import 'package:flutter/material.dart';

class AlertBox extends StatelessWidget {
  final String alertText;

  const AlertBox({
    super.key,
    required this.alertText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              alertText,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}