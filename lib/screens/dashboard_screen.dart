import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Enhancement: Added Firebase Auth
import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import 'alerts_screen.dart';
import 'details_screen.dart';
import 'history_screen.dart'; // Enhancement: Added history screen tab
import 'login_screen.dart';
import '../widgets/status_card.dart';
import '../widgets/sensor_tile.dart';
import '../widgets/alert_box.dart';
import '../theme/app_colors.dart'; // Enhancement: AppColors

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseReference _dataRef =
      FirebaseDatabase.instance.ref().child('pv_data');

  int _selectedIndex = 0;

  Map<String, dynamic> pvData = {
    "system_status": "Loading...",
    "voltage": "--",
    "current": "--",
    "ambient_temp": "--",
    "string1_temp": "--",
    "string2_temp": "--",
    "string1_voltage": "--",
    "string2_voltage": "--",
    "string1_current": "--",
    "string2_current": "--",
    "irradiance": "--",
    "dc_power": "--",
    "system_efficiency": "--",
    "fault_type": "--",
    "fault_location": "--",
    "recent_alert": "No alerts yet.",
    "alert_timestamp": "--"
  };

  String _lastNotifiedTimestamp = "";

  @override
  void initState() {
    super.initState();

    _dataRef.onValue.listen((event) {
      final data = event.snapshot.value;

      if (data != null && data is Map) {
        final newPvData = Map<String, dynamic>.from(data);
        
        // Check for new alerts
        final updateTime = newPvData["recent_alert"]?.toString() ?? "";
        final hasNewAlert = updateTime.isNotEmpty && updateTime != "No alerts yet." && updateTime != _lastNotifiedTimestamp;

        if (hasNewAlert) {
          _lastNotifiedTimestamp = updateTime;
          NotificationService().showLocalNotification(
            title: "System Alert: ${newPvData["fault_type"] ?? "Unknown"}",
            body: updateTime,
          );

          // Save alert to /pv_alerts history so the History Screen can display it
          final int ts = newPvData["timestamp"] is int
              ? newPvData["timestamp"] as int
              : DateTime.now().millisecondsSinceEpoch ~/ 1000;
          FirebaseDatabase.instance.ref().child('pv_alerts/$ts').set({
            "fault_type":     newPvData["fault_type"]    ?? "--",
            "fault_location": newPvData["fault_location"] ?? "--",
            "recent_alert":   updateTime,
            "timestamp":      ts,
          });
        }

        setState(() {
          pvData = newPvData;
        });
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Color getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('fault')) return AppColors.alertRed;
    if (s.contains('warning')) return AppColors.amber;
    return AppColors.severityGreen;
  }

  /// Formats a raw sensor value to 2 decimal places.
  /// Returns the original string unchanged if it is not a valid number.
  String _fmt(dynamic raw) {
    final d = double.tryParse(raw.toString());
    return d != null ? d.toStringAsFixed(2) : raw.toString();
  }

  // Enhancement: Added logout logic
  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Widget _buildDashboardContent(String systemStatus) {
    // Setup values for System Health Summary Card & Power Section
    double s1v = double.tryParse(pvData["string1_voltage"].toString()) ?? 0.0;
    double s1i = double.tryParse(pvData["string1_current"].toString()) ?? 0.0;
    double s2v = double.tryParse(pvData["string2_voltage"].toString()) ?? 0.0;
    double s2i = double.tryParse(pvData["string2_current"].toString()) ?? 0.0;

    double dcPower = double.tryParse(pvData["dc_power"].toString()) ?? 0.0;
    if (dcPower == 0.0) {
      dcPower = (s1v * s1i) + (s2v * s2i);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('RASID Dashboard'),
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
        // Enhancement: Logout IconButton
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Enhancement: System Health Summary Card (Richer Layout)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.navyDark, AppColors.navyMid],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'System Status',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            systemStatus,
                            style: TextStyle(
                              color: getStatusColor(systemStatus),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: getStatusColor(systemStatus),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                ],
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Fault Type: ${pvData["fault_type"]}",
                    style: const TextStyle(fontSize: 15),
                  ),
                  Text(
                    "Location: ${pvData["fault_location"]}",
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.navyDark,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                StatusCard(
                  title: 'Total Voltage',
                  value: '${_fmt(pvData["voltage"])} V',
                  icon: Icons.flash_on,
                  color: Colors.orange,
                ),
                StatusCard(
                  title: 'Total Current',
                  value: '${_fmt(pvData["current"])} A',
                  icon: Icons.electric_bolt,
                  color: Colors.blue,
                ),
              ],
            ),
            Row(
              children: [
                StatusCard(
                  title: 'Ambient Temp',
                  value: '${_fmt(pvData["ambient_temp"])} °C',
                  icon: Icons.thermostat,
                  color: Colors.red,
                ),
                StatusCard(
                  title: 'Irradiance',
                  value: '${_fmt(pvData["irradiance"])} W/m²',
                  icon: Icons.wb_sunny,
                  color: AppColors.amber,
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Text(
              'String-Level Monitoring',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.navyDark,
              ),
            ),
            const SizedBox(height: 10),

            SensorTile(
              label: 'String 1 Voltage',
              value: '${_fmt(pvData["string1_voltage"])} V',
              icon: Icons.show_chart,
            ),
            SensorTile(
              label: 'String 1 Current',
              value: '${_fmt(pvData["string1_current"])} A',
              icon: Icons.bolt,
            ),
            SensorTile(
              label: 'String 1 Temperature',
              value: '${_fmt(pvData["string1_temp"])} °C',
              icon: Icons.thermostat,
            ),
            SensorTile(
              label: 'String 2 Voltage',
              value: '${_fmt(pvData["string2_voltage"])} V',
              icon: Icons.show_chart,
            ),
            SensorTile(
              label: 'String 2 Current',
              value: '${_fmt(pvData["string2_current"])} A',
              icon: Icons.bolt,
            ),
            SensorTile(
              label: 'String 2 Temperature',
              value: '${_fmt(pvData["string2_temp"])} °C',
              icon: Icons.thermostat,
            ),
            // ATTENTION: FOR TESTING ONLY
            //ElevatedButton(
              //  onPressed: () async {
                //  await NotificationService().showLocalNotification(
                //  title: 'Test Alert',
                //  body: 'PV fault notification is working!',
                //);
              //},
              //child: const Text('Test Notification'),
            //),

            const SizedBox(height: 20),
            const Text(
              'Power Output',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.navyDark,
              ),
            ),
            const SizedBox(height: 10),
            SensorTile(
              label: 'DC Power (Total)',
              value: '${dcPower.toStringAsFixed(2)} W',
              icon: Icons.solar_power,
            ),

            const SizedBox(height: 20),
            const Text(
              'Recent Alert',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.navyDark,
              ),
            ),
            const SizedBox(height: 10),

            AlertBox(
              alertText: pvData["recent_alert"].toString(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final systemStatus = pvData["system_status"].toString();
    final recentAlert = pvData["recent_alert"]?.toString() ?? "";
    final bool hasAlert = recentAlert.isNotEmpty && recentAlert != "No alerts yet.";

    final List<Widget> screens = [
      _buildDashboardContent(systemStatus),
      AlertsScreen(
        recentAlert: pvData["recent_alert"].toString(),
        faultType: pvData["fault_type"].toString(),
        faultLocation: pvData["fault_location"].toString(),
      ),
      DetailsScreen(
        pvData: pvData,
      ),
      // Enhancement: Added History Screen
      const HistoryScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppColors.navyDark,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // To prevent shifting with 4 items
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            // Enhancement: Notification Badge
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.warning_amber_rounded),
                if (hasAlert)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Alerts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.info_outline),
            label: 'Details',
          ),
          // Enhancement: 4th tab for History
          const BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'History',
          ),
        ],
      ),
    );
  }
}