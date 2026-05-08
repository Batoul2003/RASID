import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_colors.dart';

// Enhancement: Added new HistoryScreen to display real-time historical charts + alerts history
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseReference _historyRef =
      FirebaseDatabase.instance.ref().child('pv_history');
  final DatabaseReference _alertsRef =
      FirebaseDatabase.instance.ref().child('pv_alerts');

  List<Map<String, dynamic>> _historyData = [];
  List<Map<String, dynamic>> _alertsData = [];
  bool _isLoading = true;
  bool _alertsLoading = true;

  @override
  void initState() {
    super.initState();

    // Listen to sensor history
    _historyRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        List<Map<String, dynamic>> tempList = [];
        data.forEach((key, value) {
          if (value is Map) {
            tempList.add(Map<String, dynamic>.from(value));
          }
        });
        if (tempList.length > 20) {
          tempList = tempList.sublist(tempList.length - 20);
        }
        if (mounted) {
          setState(() {
            _historyData = tempList;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _historyData = [];
            _isLoading = false;
          });
        }
      }
    });

    // Listen to alerts history
    _alertsRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        List<Map<String, dynamic>> alertList = [];
        data.forEach((key, value) {
          if (value is Map) {
            final entry = Map<String, dynamic>.from(value);
            entry['_key'] = key.toString(); // store key for ordering
            alertList.add(entry);
          }
        });

        // Sort by timestamp descending (newest first); fallback to key order
        alertList.sort((a, b) {
          final ta = a['timestamp']?.toString() ?? a['_key'].toString();
          final tb = b['timestamp']?.toString() ?? b['_key'].toString();
          return tb.compareTo(ta);
        });

        // Limit to last 50 alerts
        if (alertList.length > 50) {
          alertList = alertList.sublist(0, 50);
        }

        if (mounted) {
          setState(() {
            _alertsData = alertList;
            _alertsLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _alertsData = [];
            _alertsLoading = false;
          });
        }
      }
    });
  }

  // ── Sensor Chart ─────────────────────────────────────────────────────────────
  Widget _buildChart(String title, String dataKey, Color lineColor,
      {double? minY}) {
    if (_historyData.isEmpty) return const SizedBox();

    List<FlSpot> spots = [];
    for (int i = 0; i < _historyData.length; i++) {
      double val =
          double.tryParse(_historyData[i][dataKey].toString()) ?? 0.0;
      spots.add(FlSpot(i.toDouble(), val));
    }

    return Container(
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
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.navyDark,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                  bottomTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (_historyData.length - 1).toDouble(),
                minY: minY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: lineColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: lineColor.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ── Single Alert Tile ─────────────────────────────────────────────────────────
  Widget _buildAlertTile(Map<String, dynamic> alert) {
    final String faultType = alert['fault_type']?.toString() ?? '--';
    final String location = alert['fault_location']?.toString() ?? '--';
    final String message = alert['recent_alert']?.toString() ?? '--';
    final String timestamp = alert['timestamp']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: AppColors.navyDark, width: 5),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFE8EAF0),
            child: Icon(Icons.warning_amber_rounded, color: AppColors.navyDark, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  faultType,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navyDark,
                  ),
                ),
                if (location != '--') ...[
                  const SizedBox(height: 4),
                  Text(
                    'Location: $location',
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black87, height: 1.4),
                ),
                if (timestamp.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          timestamp,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Alerts History Section ────────────────────────────────────────────────────
  Widget _buildAlertsHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        // Section header card
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
          child: Row(
            children: [
              const Icon(Icons.history, color: Colors.white, size: 32),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alerts History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_alertsData.length} recorded alert${_alertsData.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_alertsLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_alertsData.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    color: AppColors.severityGreen, size: 28),
                SizedBox(width: 10),
                Text(
                  'No alerts recorded yet.',
                  style: TextStyle(color: Colors.black54, fontSize: 15),
                ),
              ],
            ),
          )
        else
          ...(_alertsData.map((alert) => _buildAlertTile(alert))),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Performance History'),
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  // ── Charts header ────────────────────────────────────────────
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
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Visualizing Past 20 Readings',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Performance History',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Charts (only shown if history data exists) ────────────────
                  if (_historyData.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bar_chart, size: 28, color: Colors.grey),
                          SizedBox(width: 10),
                          Text('No sensor history available yet.',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  else ...[
                    _buildChart('Voltage (V)', 'voltage', AppColors.teal,
                        minY: 0),
                    _buildChart('Current (A)', 'current', AppColors.amber,
                        minY: 0),
                    _buildChart('Ambient Temperature (°C)', 'ambient_temp',
                        AppColors.severityRed),
                    _buildChart('String 1 Temperature (°C)', 'string1_temp',
                        Colors.orange),
                    _buildChart('String 2 Temperature (°C)', 'string2_temp',
                        Colors.deepOrange),
                    _buildChart('Irradiance (W/m²)', 'irradiance',
                        AppColors.amber, minY: 0),
                  ],

                  // ── Alerts History ────────────────────────────────────────────
                  _buildAlertsHistory(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
