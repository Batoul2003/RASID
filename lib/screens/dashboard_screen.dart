import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Enhancement: Added Firebase Auth
import 'package:flutter/material.dart';

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
    "temperature": "--",
    "irradiance": "--",
    "string1_voltage": "--",
    "string1_current": "--",
    "string2_voltage": "--",
    "string2_current": "--",
    "ac_voltage": "--",
    "ac_current": "--",
    "recent_alert": "No alerts yet.",
    "fault_type": "--",
    "fault_location": "--",
    "severity": "--",
    "last_updated": "--"
  };

  @override
  void initState() {
    super.initState();

    _dataRef.onValue.listen((event) {
      final data = event.snapshot.value;

      if (data != null && data is Map) {
        setState(() {
          pvData = Map<String, dynamic>.from(data);
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
    // Enhancement: Setup values for System Health Summary Card & Power/Efficiency Section
    double s1v = double.tryParse(pvData["string1_voltage"].toString()) ?? 0.0;
    double s1i = double.tryParse(pvData["string1_current"].toString()) ?? 0.0;
    double s2v = double.tryParse(pvData["string2_voltage"].toString()) ?? 0.0;
    double s2i = double.tryParse(pvData["string2_current"].toString()) ?? 0.0;

    double acV = double.tryParse(pvData["ac_voltage"].toString()) ?? 0.0;
    double acI = double.tryParse(pvData["ac_current"].toString()) ?? 0.0;

    double dcPower = (s1v * s1i) + (s2v * s2i);
    double acPower = acV * acI;
    double efficiency = dcPower > 0 ? (acPower / dcPower) * 100 : 0.0;
    efficiency = efficiency.clamp(0.0, 100.0);

    Color prColor = AppColors.severityRed;
    if (efficiency > 75) prColor = AppColors.severityGreen;
    else if (efficiency >= 50) prColor = AppColors.severityAmber;

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
                  Text(
                    "Severity: ${pvData["severity"]}",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
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
                  title: 'Voltage',
                  value: '${pvData["voltage"]} V',
                  icon: Icons.flash_on,
                  color: Colors.orange,
                ),
                StatusCard(
                  title: 'Current',
                  value: '${pvData["current"]} A',
                  icon: Icons.electric_bolt,
                  color: Colors.blue,
                ),
              ],
            ),
            Row(
              children: [
                StatusCard(
                  title: 'Temp',
                  value: '${pvData["temperature"]} °C',
                  icon: Icons.thermostat,
                  color: Colors.red,
                ),
                StatusCard(
                  title: 'Irradiance',
                  value: '${pvData["irradiance"]} W/m²',
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
              value: '${pvData["string1_voltage"]} V',
              icon: Icons.show_chart,
            ),
            SensorTile(
              label: 'String 1 Current',
              value: '${pvData["string1_current"]} A',
              icon: Icons.bolt,
            ),
            SensorTile(
              label: 'String 2 Voltage',
              value: '${pvData["string2_voltage"]} V',
              icon: Icons.show_chart,
            ),
            SensorTile(
              label: 'String 2 Current',
              value: '${pvData["string2_current"]} A',
              icon: Icons.bolt,
            ),

            const SizedBox(height: 20),
            const Text(
              'Inverter Output',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.navyDark,
              ),
            ),
            const SizedBox(height: 10),

            SensorTile(
              label: 'AC Output Voltage',
              value: '${pvData["ac_voltage"]} V',
              icon: Icons.power,
            ),
            SensorTile(
              label: 'AC Output Current',
              value: '${pvData["ac_current"]} A',
              icon: Icons.electrical_services,
            ),

            const SizedBox(height: 20),
            // Enhancement: Power & Efficiency Section
            const Text(
              'Power & Efficiency',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.navyDark,
              ),
            ),
            const SizedBox(height: 10),
            SensorTile(
              label: 'DC Power (Total)',
              value: '${dcPower.toStringAsFixed(1)} W',
              icon: Icons.solar_power,
            ),
            SensorTile(
              label: 'AC Power Output',
              value: '${acPower.toStringAsFixed(1)} W',
              icon: Icons.electric_meter,
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.analytics, color: AppColors.teal, size: 30),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'System Efficiency',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.navyDark,
                      ),
                    ),
                  ),
                  dcPower == 0 
                  ? const Text("N/A", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                  : Text(
                    '${efficiency.toStringAsFixed(1)} %',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: prColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
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
    final severityStr = pvData["severity"]?.toString().toLowerCase() ?? "";

    // Enhancement: Notification condition for Alerts tab
    final bool hasAlert = severityStr == 'high' || severityStr == 'critical' || severityStr == 'fault';

    final List<Widget> screens = [
      _buildDashboardContent(systemStatus),
      AlertsScreen(
        recentAlert: pvData["recent_alert"].toString(),
        faultType: pvData["fault_type"].toString(),
        faultLocation: pvData["fault_location"].toString(),
        severity: pvData["severity"].toString(),
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