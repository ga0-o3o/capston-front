import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/study_accuracy_service.dart';

/// 학습 정확도 그래프 위젯
class StudyAccuracyChart extends StatefulWidget {
  const StudyAccuracyChart({Key? key}) : super(key: key);

  @override
  State<StudyAccuracyChart> createState() => _StudyAccuracyChartState();
}

class _StudyAccuracyChartState extends State<StudyAccuracyChart> {
  List<StudyAccuracyRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // 최근 7일 데이터 불러오기
      final records = await StudyAccuracyService.loadRecentRecords(7);

      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[ERROR] Failed to load chart data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          Row(
            children: [
              Icon(
                Icons.bar_chart,
                color: const Color(0xFF4E6E99),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '학습 정확도',
                style: GoogleFonts.notoSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3D4C63),
                ),
              ),
              const Spacer(),
              // 새로고침 버튼
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadData,
                color: const Color(0xFF4E6E99),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 부제목
          Text(
            '최근 7일간 학습 정확도',
            style: GoogleFonts.notoSans(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),

          // 그래프
          SizedBox(
            height: 200,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? _buildEmptyState()
                    : _buildChart(),
          ),

          const SizedBox(height: 8),

          // 평균 정확도 표시
          if (_records.isNotEmpty) _buildAverageDisplay(),
        ],
      ),
    );
  }

  /// 빈 상태 위젯
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            '아직 학습 기록이 없습니다',
            style: GoogleFonts.notoSans(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '학습을 완료하면 정확도가 표시됩니다',
            style: GoogleFonts.notoSans(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// 차트 위젯
  Widget _buildChart() {
    // 최대 7일치 데이터만 표시
    final displayRecords = _records.length > 7
        ? _records.sublist(_records.length - 7)
        : _records;

    // 차트 데이터 생성
    final spots = displayRecords.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.accuracy);
    }).toList();

    // Y축 최대값 계산 (100% 또는 최대 정확도 + 10)
    final maxY = 100.0;
    final minY = 0.0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= displayRecords.length) {
                  return const SizedBox();
                }

                final date = displayRecords[index].date;
                final label = '${date.month}/${date.day}';

                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    label,
                    style: GoogleFonts.notoSans(
                      fontSize: 10,
                      color: Colors.grey[700],
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 20,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: GoogleFonts.notoSans(
                    fontSize: 10,
                    color: Colors.grey[700],
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: Colors.grey[300]!),
            bottom: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        minX: 0,
        maxX: (displayRecords.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF4E6E99),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: const Color(0xFF4E6E99),
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF4E6E99).withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => const Color(0xFF3D4C63),
            tooltipRoundedRadius: 8,
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                final index = touchedSpot.x.toInt();
                if (index < 0 || index >= displayRecords.length) {
                  return null;
                }

                final record = displayRecords[index];
                final date = '${record.date.month}/${record.date.day}';
                final accuracy = record.accuracy.toStringAsFixed(1);

                return LineTooltipItem(
                  '$date\n$accuracy%',
                  GoogleFonts.notoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  /// 평균 정확도 표시
  Widget _buildAverageDisplay() {
    final average = _records.fold<double>(
          0,
          (prev, record) => prev + record.accuracy,
        ) /
        _records.length;

    Color averageColor;
    String averageText;

    if (average >= 80) {
      averageColor = Colors.green;
      averageText = '우수';
    } else if (average >= 60) {
      averageColor = Colors.orange;
      averageText = '보통';
    } else {
      averageColor = Colors.red;
      averageText = '노력 필요';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: averageColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.trending_up,
            color: averageColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '평균 정확도: ',
            style: GoogleFonts.notoSans(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            '${average.toStringAsFixed(1)}%',
            style: GoogleFonts.notoSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: averageColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($averageText)',
            style: GoogleFonts.notoSans(
              fontSize: 12,
              color: averageColor,
            ),
          ),
        ],
      ),
    );
  }
}
