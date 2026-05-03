import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/alert_box.dart';
import '../theme/app_colors.dart'; // Enhancement: Added AppColors

class AlertsScreen extends StatelessWidget {
  final String recentAlert;
  final String faultType;
  final String faultLocation;
  final String severity;

  const AlertsScreen({
    super.key,
    required this.recentAlert,
    required this.faultType,
    required this.faultLocation,
    required this.severity,
  });

  // Enhancement: Semantic color coding for severity
  Color _getSeverityColor(String sev) {
    switch (sev.toLowerCase()) {
      case 'low':
        return AppColors.severityGreen;
      case 'medium':
      case 'warning':
        return AppColors.severityAmber;
      case 'high':
      case 'critical':
      case 'fault':
        return AppColors.severityRed;
      default:
        return Colors.grey;
    }
  }

  // Enhancement: Clear alert action
  void _clearAlert() {
    FirebaseDatabase.instance.ref().child('pv_data').update({
      "recent_alert": "No alerts yet.",
      "fault_type": "--",
      "fault_location": "--",
      "severity": "--",
    });
  }

  @override
  Widget build(BuildContext context) {
    final String fTypeLower = faultType.toLowerCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Alerts'),
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Fault Type: $faultType"),
                  Text("Location: $faultLocation"),
                  Row(
                    children: [
                      const Text("Severity: "),
                      // Enhancement: Severity color coded badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getSeverityColor(severity),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          severity,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.alertDarkRed, AppColors.alertRed],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fault Alerts',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Recent System Warning',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'This page shows the latest detected alert from the PV monitoring system.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Recent Alert',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.navyDark,
              ),
            ),
            const SizedBox(height: 12),

            AlertBox(
              alertText: recentAlert,
            ),

            const SizedBox(height: 24),

            const Text(
              'Suggested Action',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.navyDark,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Check the affected PV string, inspect for shading or dust accumulation, verify sensor readings, and confirm inverter operation if necessary.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Typical Fault Causes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.navyDark,
              ),
            ),
            const SizedBox(height: 10),

            // Enhancement: Dynamic highlighting based on faultType
            _buildInfoCard(
              icon: Icons.cloud,
              title: 'Partial Shading',
              description:
                  'A drop in one string current may indicate shading from nearby objects or uneven sunlight exposure.',
              highlight: fTypeLower.contains("shading"),
            ),
            _buildInfoCard(
              icon: Icons.cleaning_services,
              title: 'Dust or Soiling',
              description:
                  'Gradual reduction in current under strong irradiance can suggest dirt accumulation on PV panels.',
              highlight: fTypeLower.contains("dust") || fTypeLower.contains("soiling"),
            ),
            _buildInfoCard(
              icon: Icons.link_off,
              title: 'Open-Circuit / Loose Connection',
              description:
                  'Zero or unstable current values may indicate string disconnection or poor wiring contact.',
              highlight: fTypeLower.contains("open") || fTypeLower.contains("disconnect"),
            ),
            _buildInfoCard(
              icon: Icons.power_off,
              title: 'Inverter Issue',
              description:
                  'Abnormal AC voltage or AC current can indicate inverter-side fault or output instability.',
              highlight: fTypeLower.contains("inverter"),
            ),

            const SizedBox(height: 24),
            // Enhancement: Clear Alert Button
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.alertRed,
                side: const BorderSide(color: AppColors.alertRed),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _clearAlert,
              child: const Text(
                'Clear Alert',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    bool highlight = false, // Enhancement: Highlight parameter
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        // Enhancement: Amber left border if highlighted
        border: highlight
            ? const Border(left: BorderSide(color: AppColors.amber, width: 6))
            : null,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.red.withOpacity(0.1),
            child: Icon(icon, color: Colors.red),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navyDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}