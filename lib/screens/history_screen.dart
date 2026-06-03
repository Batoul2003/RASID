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

  List<Map<String, dynamic>> _parseHistoryData(dynamic data) {
    List<Map<String, dynamic>> list = [];
    if (data == null) return list;
    if (data is Map) {
      data.forEach((key, value) {
        if (value is Map) {
          list.add(Map<String, dynamic>.from(value));
        }
      });
    } else if (data is List) {
      for (var value in data) {
        if (value is Map) {
          list.add(Map<String, dynamic>.from(value));
        }
      }
    }
    return list;
  }

  List<Map<String, dynamic>> _parseAlertsData(dynamic data) {
    List<Map<String, dynamic>> list = [];
    if (data == null) return list;
    if (data is Map) {
      data.forEach((key, value) {
        if (value is Map) {
          final entry = Map<String, dynamic>.from(value);
          entry['_key'] = key.toString();
          list.add(entry);
        }
      });
    } else if (data is List) {
      for (int i = 0; i < data.length; i++) {
        final value = data[i];
        if (value is Map) {
          final entry = Map<String, dynamic>.from(value);
          entry['_key'] = i.toString();
          list.add(entry);
        }
      }
    }
    return list;
  }

  @override
  void initState() {
    super.initState();

    // Listen to sensor history
    _historyRef.onValue.listen((event) {
      final data = event.snapshot.value;
      List<Map<String, dynamic>> tempList = _parseHistoryData(data);
      if (tempList.length > 500) {
        tempList = tempList.sublist(tempList.length - 500);
      }
      if (mounted) {
        setState(() {
          _historyData = tempList;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      debugPrint("Error loading history: $error");
      if (mounted) {
        setState(() {
          _historyData = [];
          _isLoading = false;
        });
      }
    });

    // Listen to alerts history
    _alertsRef.onValue.listen((event) {
      final data = event.snapshot.value;
      List<Map<String, dynamic>> alertList = _parseAlertsData(data);

      // Sort by timestamp descending (newest first); fallback to key order
      alertList.sort((a, b) {
        final ta = a['timestamp']?.toString() ?? a['_key']?.toString() ?? '';
        final tb = b['timestamp']?.toString() ?? b['_key']?.toString() ?? '';
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
    }, onError: (error) {
      debugPrint("Error loading alerts: $error");
      if (mounted) {
        setState(() {
          _alertsData = [];
          _alertsLoading = false;
        });
      }
    });
  }

  DateTime? _parseEntryTime(Map<String, dynamic> entry) {
    final ts = entry['timestamp'] ?? entry['time'] ?? entry['_key'];
    if (ts == null) return null;
    
    // Try parsing as ISO string
    DateTime? dt = DateTime.tryParse(ts.toString());
    if (dt != null) return dt;
    
    // Try parsing as Milliseconds/Seconds since Epoch (if it's a number)
    final numVal = num.tryParse(ts.toString());
    if (numVal != null) {
      if (numVal > 9999999999) { // likely milliseconds
        return DateTime.fromMillisecondsSinceEpoch(numVal.toInt());
      } else { // likely seconds
        return DateTime.fromMillisecondsSinceEpoch((numVal * 1000).toInt());
      }
    }
    return null;
  }

  // ── Sensor Chart ─────────────────────────────────────────────────────────────
  Widget _buildChart(String title, String dataKey, Color lineColor, DateTime oneDayAgo,
      {double? minY}) {
    if (_historyData.isEmpty) return const SizedBox();

    final double referenceEndHours = 24.0;
    List<FlSpot> spots = [];

    // Map historical entries to spots representing decimal hours elapsed in the 24h window
    for (var entry in _historyData) {
      final dt = _parseEntryTime(entry);
      if (dt != null) {
        final double hoursSinceStart = dt.difference(oneDayAgo).inSeconds / 3600.0;
        if (hoursSinceStart >= 0.0 && hoursSinceStart <= referenceEndHours) {
          double val = double.tryParse(entry[dataKey].toString()) ?? 0.0;
          spots.add(FlSpot(hoursSinceStart, val));
        }
      }
    }

    // Ensure spots are sorted chronologically on x-axis
    spots.sort((a, b) => a.x.compareTo(b.x));

    if (spots.isEmpty) {
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
            const SizedBox(height: 12),
            const Text(
              'No readings captured in the past 24 hours.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
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
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  drawHorizontalLine: false,
                  getDrawingVerticalLine: (value) {
                    return const FlLine(
                      color: Colors.black12,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 2, // Tick every 2 hours
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value > 24) return const SizedBox();
                        final timeAtValue = oneDayAgo.add(Duration(minutes: (value * 60).toInt()));
                        final hourStr = "${timeAtValue.hour.toString().padLeft(2, '0')}:00";
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 6,
                          child: Text(
                            hourStr,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 24,
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
    // Determine the sliding 24-hour time frame relative to the latest available reading
    DateTime referenceTime = DateTime.now();
    if (_historyData.isNotEmpty) {
      for (var entry in _historyData) {
        final dt = _parseEntryTime(entry);
        if (dt != null && dt.isAfter(referenceTime)) {
          referenceTime = dt;
        }
      }
    }
    final oneDayAgo = referenceTime.subtract(const Duration(hours: 24));

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
                          'Visualizing Past 24 Hours',
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
                    _buildChart('Voltage (V)', 'voltage', AppColors.teal, oneDayAgo,
                        minY: 0),
                    _buildChart('Current (A)', 'current', AppColors.amber, oneDayAgo,
                        minY: 0),
                    _buildChart('Ambient Temperature (°C)', 'ambient_temp',
                        AppColors.severityRed, oneDayAgo),
                    _buildChart('String 1 Temperature (°C)', 'string1_temp',
                        Colors.orange, oneDayAgo),
                    _buildChart('String 2 Temperature (°C)', 'string2_temp',
                        Colors.deepOrange, oneDayAgo),
                    _buildChart('Irradiance (W/m²)', 'irradiance',
                        AppColors.amber, oneDayAgo, minY: 0),
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
