import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../theme/app_colors.dart';

// Enhancement: Added new HistoryScreen to display real-time historical charts + alerts history
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseReference _alertsRef =
      FirebaseDatabase.instance.ref().child('pv_alerts');

  List<Map<String, dynamic>> _alertsData = [];
  bool _isLoading = true;

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
          _isLoading = false;
        });
      }
    }, onError: (error) {
      debugPrint("Error loading alerts: $error");
      if (mounted) {
        setState(() {
          _alertsData = [];
          _isLoading = false;
        });
      }
    });
  }



  String _formatTimestamp(String timestampRaw) {
    if (timestampRaw.isEmpty) return '';
    final intVal = int.tryParse(timestampRaw);
    DateTime? dateTime;
    if (intVal != null) {
      if (timestampRaw.length == 10) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(intVal * 1000).toLocal();
      } else if (timestampRaw.length >= 13) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(intVal).toLocal();
      } else {
        dateTime = DateTime.fromMillisecondsSinceEpoch(intVal * 1000).toLocal();
      }
    } else {
      dateTime = DateTime.tryParse(timestampRaw)?.toLocal();
    }

    if (dateTime == null) {
      return timestampRaw;
    }

    final year = dateTime.year;
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute';
  }

  // ── Single Alert Tile ─────────────────────────────────────────────────────────
  Widget _buildAlertTile(Map<String, dynamic> alert) {
    final String faultType = alert['fault_type']?.toString() ?? '--';
    final String location = alert['fault_location']?.toString() ?? '--';
    final String message = alert['recent_alert']?.toString() ?? '--';
    final String timestampRaw = alert['timestamp']?.toString() ?? '';
    final String formattedTimestamp = _formatTimestamp(timestampRaw);

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
                if (formattedTimestamp.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          formattedTimestamp,
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

        if (_isLoading)
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


    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Alerts History'),
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
                  // ── Alerts History ────────────────────────────────────────────
                  _buildAlertsHistory(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
