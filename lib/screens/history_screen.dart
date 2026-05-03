import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_colors.dart';

// Enhancement: Added new HistoryScreen to display real-time historical charts
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseReference _historyRef = FirebaseDatabase.instance.ref().child('pv_history');
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _historyRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        List<Map<String, dynamic>> tempList = [];
        data.forEach((key, value) {
          if (value is Map) {
            tempList.add(Map<String, dynamic>.from(value));
          }
        });
        
        // Ensure chronological order if possible or just limit to 20
        // We'll just take the last 20 entries
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
  }

  Widget _buildChart(String title, String dataKey, Color lineColor, {double? minY}) {
    if (_historyData.isEmpty) return const SizedBox();

    List<FlSpot> spots = [];
    double maxX = _historyData.length.toDouble();
    double minX = 0;
    
    for (int i = 0; i < _historyData.length; i++) {
        double val = double.tryParse(_historyData[i][dataKey].toString()) ?? 0.0;
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
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: minX,
                maxX: maxX - 1,
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
          : _historyData.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No history available yet.", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
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
                      _buildChart('Voltage (V)', 'voltage', AppColors.teal, minY: 0),
                      _buildChart('Current (A)', 'current', AppColors.amber, minY: 0),
                      _buildChart('Temperature (°C)', 'temperature', AppColors.severityRed),
                      _buildChart('Irradiance (W/m²)', 'irradiance', AppColors.amber, minY: 0),
                    ],
                  ),
                ),
    );
  }
}
