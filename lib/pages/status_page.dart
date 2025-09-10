import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StudyGraphPage extends StatelessWidget {
  const StudyGraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("공부 그래프")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LineChart(
          LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: [
                  FlSpot(0, 1.5),
                  FlSpot(1, 2.0),
                  FlSpot(2, 1.0),
                  FlSpot(3, 3.0),
                ],
                isCurved: true,
                color: Colors.green,
                barWidth: 3,
                dotData: FlDotData(show: true),
              ),
            ],
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final labels = ['월', '화', '수', '목', '금', '토', '일'];
                    final index = value.toInt() % labels.length;
                    return Text(labels[index]);
                  },
                ),
              ),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
            ),
            gridData: FlGridData(show: true),
          ),
        ),
      ),
    );
  }
}
