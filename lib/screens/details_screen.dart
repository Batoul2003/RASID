import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DetailsScreen extends StatefulWidget {
  final Map<String, dynamic> pvData;

  const DetailsScreen({
    super.key,
    required this.pvData,
  });

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  int _selectedTab = 0; // 0 for Live Performance, 1 for Technical Specs

  /// Formats a raw sensor value to 2 decimal places.
  /// Returns the original string unchanged if it is not a valid number.
  String _fmt(dynamic raw) {
    final d = double.tryParse(raw.toString());
    return d != null ? d.toStringAsFixed(2) : raw.toString();
  }

  Widget buildDetailTile(String label, String value) {
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
                color: AppColors.navyDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.navyMid,
            ),
          )
        ],
      ),
    );
  }

  Widget buildCategoryCard(String title, IconData headerIcon, Color accentColor, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(headerIcon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navyDark,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Divider(height: 1, thickness: 1.2),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget buildSpecRow(IconData icon, String label, String value, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.navyDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double s1v = double.tryParse(widget.pvData["string1_voltage"].toString()) ?? 0.0;
    double s1i = double.tryParse(widget.pvData["string1_current"].toString()) ?? 0.0;
    double s2v = double.tryParse(widget.pvData["string2_voltage"].toString()) ?? 0.0;
    double s2i = double.tryParse(widget.pvData["string2_current"].toString()) ?? 0.0;

    double dcPower = double.tryParse(widget.pvData["dc_power"].toString()) ?? 0.0;
    if (dcPower == 0.0) {
      dcPower = (s1v * s1i) + (s2v * s2i);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('System Details'),
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Styled Banner at the Top
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
                    'Detailed telemetry values and technical panel configurations.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Premium Custom Tab Switcher (Pill style)
            Container(
              height: 52,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? AppColors.navyDark : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          'Live Performance',
                          style: TextStyle(
                            color: _selectedTab == 0 ? Colors.white : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? AppColors.navyDark : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          'Technical Specs',
                          style: TextStyle(
                            color: _selectedTab == 1 ? Colors.white : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab Content Switcher
            if (_selectedTab == 0) ...[
              const Text(
                'Live Parameters',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navyDark,
                ),
              ),
              const SizedBox(height: 12),
              buildDetailTile('System Status', widget.pvData["system_status"].toString()),
              buildDetailTile('Total DC Power', '${dcPower.toStringAsFixed(2)} W'),
              buildDetailTile('Voltage', '${_fmt(widget.pvData["voltage"])} V'),
              buildDetailTile('Current', '${_fmt(widget.pvData["current"])} A'),
              buildDetailTile('Ambient Temp', '${_fmt(widget.pvData["ambient_temp"])} °C'),
              buildDetailTile('String 1 Temp', '${_fmt(widget.pvData["string1_temp"])} °C'),
              buildDetailTile('String 2 Temp', '${_fmt(widget.pvData["string2_temp"])} °C'),
              buildDetailTile('Irradiance', '${_fmt(widget.pvData["irradiance"])} W/m²'),
              buildDetailTile('String 1 Voltage', '${_fmt(widget.pvData["string1_voltage"])} V'),
              buildDetailTile('String 1 Current', '${_fmt(widget.pvData["string1_current"])} A'),
              buildDetailTile('String 2 Voltage', '${_fmt(widget.pvData["string2_voltage"])} V'),
              buildDetailTile('String 2 Current', '${_fmt(widget.pvData["string2_current"])} A'),
            ] else ...[
              const Text(
                'Panel Specifications',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navyDark,
                ),
              ),
              const SizedBox(height: 12),
              
              // Group 1: General Characteristics
              buildCategoryCard(
                'General Characteristics',
                Icons.grid_view_rounded,
                AppColors.teal,
                [
                  buildSpecRow(Icons.layers_outlined, 'Cell Type', 'Monocrystalline', AppColors.teal),
                  buildSpecRow(Icons.aspect_ratio_rounded, 'Dimensions (L x W)', '1045 mm x 758 mm', AppColors.teal),
                  buildSpecRow(Icons.percent_rounded, 'Module Efficiency', '17 - 18%', AppColors.teal),
                  buildSpecRow(Icons.donut_large_rounded, 'Fill Factor', '0.79', AppColors.teal),
                  buildSpecRow(Icons.thermostat_outlined, 'Operating Temperature', '-20°C to 90°C', AppColors.teal),
                ],
              ),

              // Group 2: Electrical Ratings (STC)
              buildCategoryCard(
                'Electrical Ratings (STC)',
                Icons.offline_bolt_rounded,
                AppColors.amber,
                [
                  buildSpecRow(Icons.wb_sunny_rounded, 'Maximum Power (Pmax)', '150 W', AppColors.amber),
                  buildSpecRow(Icons.flash_on_rounded, 'Maximum Power Voltage (Vmp)', '18 V', AppColors.amber),
                  buildSpecRow(Icons.electric_bolt_rounded, 'Maximum Power Current (Imp)', '8.57 A', AppColors.amber),
                  buildSpecRow(Icons.alt_route_rounded, 'Open Circuit Voltage (Voc)', '21.5 V', AppColors.amber),
                  buildSpecRow(Icons.shuffle_rounded, 'Short Circuit Current (Isc)', '9.59 A', AppColors.amber),
                ],
              ),

              // Group 3: Temperature Coefficients
              buildCategoryCard(
                'Temperature Coefficients',
                Icons.device_thermostat_rounded,
                Colors.orange,
                [
                  buildSpecRow(Icons.trending_down_rounded, 'Voltage Temp Coefficient', '-0.33% / °C', Colors.orange),
                  buildSpecRow(Icons.trending_up_rounded, 'Current Temp Coefficient', '+0.05% / °C', Colors.orange),
                  buildSpecRow(Icons.trending_down_rounded, 'Power Temp Coefficient', '-0.40% / °C', Colors.orange),
                ],
              ),

              // Group 4: Warranty & Service Life
              buildCategoryCard(
                'Warranty & Service Life',
                Icons.workspace_premium_rounded,
                AppColors.severityGreen,
                [
                  buildSpecRow(
                    Icons.security_rounded,
                    'Years of Service',
                    '> 90% after 10 years\n> 80% after 20 years',
                    AppColors.severityGreen,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}