import 'package:flutter/material.dart';

class DetailsScreen extends StatelessWidget {
  final Map<String, dynamic> pvData;

  const DetailsScreen({
    super.key,
    required this.pvData,
  });

  Widget buildDetailTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF0B1F3A),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('System Details'),
        backgroundColor: const Color(0xFF0B1F3A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B1F3A), Color(0xFF12345A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Details',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Full PV Data Overview',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Detailed values collected from the PV monitoring system.',
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
              'Live Parameters',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B1F3A),
              ),
            ),
            const SizedBox(height: 12),

            buildDetailTile('System Status', pvData["system_status"].toString()),
            buildDetailTile('Voltage', '${pvData["voltage"]} V'),
            buildDetailTile('Current', '${pvData["current"]} A'),
            buildDetailTile('Temperature', '${pvData["temperature"]} °C'),
            buildDetailTile('Irradiance', '${pvData["irradiance"]} W/m²'),
            buildDetailTile('String 1 Voltage', '${pvData["string1_voltage"]} V'),
            buildDetailTile('String 1 Current', '${pvData["string1_current"]} A'),
            buildDetailTile('String 2 Voltage', '${pvData["string2_voltage"]} V'),
            buildDetailTile('String 2 Current', '${pvData["string2_current"]} A'),
            buildDetailTile('AC Voltage', '${pvData["ac_voltage"]} V'),
            buildDetailTile('AC Current', '${pvData["ac_current"]} A'),
            buildDetailTile('Recent Alert', pvData["recent_alert"].toString()),
          ],
        ),
      ),
    );
  }
}