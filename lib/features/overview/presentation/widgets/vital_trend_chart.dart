import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/clinical_theme.dart';

class VitalTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> vitals;

  const VitalTrendChart({super.key, required this.vitals});

  @override
  Widget build(BuildContext context) {
    if (vitals.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('ไม่มีข้อมูลความดันย้อนหลังสำหรับวาดกราฟ', style: TextStyle(color: ClinicalColors.textMuted))),
      );
    }

    // เตรียมจุดข้อมูลกราฟ (เรียงจากเก่าไปใหม่)
    final reversedVitals = vitals.reversed.toList();
    final List<FlSpot> sysSpots = [];
    final List<FlSpot> diaSpots = [];

    for (int i = 0; i < reversedVitals.length; i++) {
      final sys = (reversedVitals[i]['systolic'] as num?)?.toDouble() ?? 120.0;
      final dia = (reversedVitals[i]['diastolic'] as num?)?.toDouble() ?? 80.0;
      sysSpots.add(FlSpot(i.toDouble(), sys));
      diaSpots.add(FlSpot(i.toDouble(), dia));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _buildLegendItem('Systolic (ตัวบน)', ClinicalColors.criticalRed),
            _buildLegendItem('Diastolic (ตัวล่าง)', ClinicalColors.primaryEmerald),
            _buildLegendItem('Target Limit (140/90)', Colors.grey),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 20,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: ClinicalColors.borderLight,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < reversedVitals.length) {
                        final dateStr = '${reversedVitals[index]['recorded_at'] ?? ''}';
                        final datePart = dateStr.contains('T') ? dateStr.split('T').first.substring(5) : '';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(datePart, style: const TextStyle(fontSize: 10, color: ClinicalColors.textMuted)),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 35,
                    interval: 30,
                    getTitlesWidget: (value, meta) => Text(
                      '${value.toInt()}',
                      style: const TextStyle(fontSize: 10, color: ClinicalColors.textMuted),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minY: 50,
              maxY: 200,
              // เส้นประ Target Lines (140/90)
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: 140,
                    color: ClinicalColors.warningOrange.withOpacity(0.6),
                    strokeWidth: 1.5,
                    dashArray: [5, 5],
                  ),
                  HorizontalLine(
                    y: 90,
                    color: ClinicalColors.primaryEmerald.withOpacity(0.6),
                    strokeWidth: 1.5,
                    dashArray: [5, 5],
                  ),
                ],
              ),
              lineBarsData: [
                // เส้น SYS
                LineChartBarData(
                  spots: sysSpots,
                  isCurved: true,
                  color: ClinicalColors.criticalRed,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                ),
                // เส้น DIA
                LineChartBarData(
                  spots: diaSpots,
                  isCurved: true,
                  color: ClinicalColors.primaryEmerald,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: ClinicalColors.textMuted, fontWeight: FontWeight.w500)),
      ],
    );
  }
}