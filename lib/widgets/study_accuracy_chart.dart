import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'study_accuracy_service.dart';

/// 학습 기록(최근 7일 학습 단어 수) 그래프 위젯
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          Row(
            children: [
              const Icon(
                Icons.bar_chart,
                color: Color(0xFF4E6E99),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '최근 학습 기록',
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
            '최근 7일간 학습한 단어 개수',
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
                    : _buildBarChart(),
          ),

          const SizedBox(height: 12),

          // 평균 표시
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
            '단어 학습을 완료하면 그래프가 표시됩니다',
            style: GoogleFonts.notoSans(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// 막대 차트 위젯 (통통한 캡슐 + 요일/날짜 + 막대 안에 항상 count 표시)
  Widget _buildBarChart() {
    // 최대 7일치 데이터만 표시
    final displayRecords =
        _records.length > 7 ? _records.sublist(_records.length - 7) : _records;

    if (displayRecords.isEmpty) return _buildEmptyState();

    // Y축 최대값 계산 (최대 count + 여유)
    final maxCount =
        displayRecords.map((e) => e.count).reduce((a, b) => a > b ? a : b);
    final maxY = (maxCount == 0 ? 5 : maxCount + 1).toDouble();

    // 요일 라벨 (일 ~ 토, 한글)
    const weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

    final barGroups = displayRecords.asMap().entries.map((entry) {
      final index = entry.key;
      final record = entry.value;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: record.count.toDouble(),
            width: 32, // 통통한 막대
            borderRadius: BorderRadius.circular(32),
            color: const Color(0xFF4E6E99),
            borderSide: const BorderSide(
              color: Colors.black,
              width: 2,
            ),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxY,
              color: const Color(0xFF4E6E99).withOpacity(0.08),
            ),
          ),
        ],
      );
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final barCount = displayRecords.length;
        if (barCount == 0) return const SizedBox.shrink();

        return Stack(
          children: [
            // 실제 막대 차트
            BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                minY: 0,
                barGroups: barGroups,

                /// ✅ 막대 터치 시 말풍선(tooltip)으로 몇 개 학습했는지 표시
                barTouchData: BarTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    tooltipMargin: 12,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      // group.x == 우리가 넣은 index
                      final record = displayRecords[group.x.toInt()];
                      final weekdayIndex = record.date.weekday % 7;

                      return BarTooltipItem(
                        '${weekdayLabels[weekdayIndex]} '
                        '${record.date.month}/${record.date.day}\n'
                        '${record.count}개 학습',
                        GoogleFonts.notoSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),

                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY <= 5 ? 1 : (maxY / 5).ceilToDouble(),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey[300]!,
                    strokeWidth: 1,
                    dashArray: const [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value % 1 != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: Text(
                            value.toInt().toString(),
                            style: GoogleFonts.notoSans(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= displayRecords.length) {
                          return const SizedBox.shrink();
                        }

                        final record = displayRecords[index];
                        final weekdayIndex = record.date.weekday % 7;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              weekdayLabels[weekdayIndex],
                              style: GoogleFonts.notoSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF3D4C63),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${record.date.month}/${record.date.day}',
                              style: GoogleFonts.notoSans(
                                fontSize: 9,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // ✅ 막대 “안 위쪽 중앙”에 항상 보이는 count 텍스트 (0이면 표시 안 함)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final chartWidth = constraints.maxWidth;
                  final chartHeight = constraints.maxHeight;

                  return Stack(
                    children: List.generate(barGroups.length, (i) {
                      final record = displayRecords[i];
                      if (record.count == 0) return const SizedBox.shrink();

                      // 막대 x 위치 계산
                      final barWidth = chartWidth / barGroups.length;
                      final barCenterX = barWidth * (i + 0.5);

                      // 막대 높이 비율 → 실제 y값
                      final ratio = record.count / maxY;
                      final barTopY = chartHeight * (1 - ratio);

                      return Positioned(
                        left: barCenterX - 10, // 텍스트 가로 중심
                        top: barTopY + 8, // 막대 맨 위보다 조금 아래
                        child: Text(
                          '${record.count}',
                          style: GoogleFonts.notoSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// 평균 학습 개수 표시
  Widget _buildAverageDisplay() {
    final average = _records.fold<double>(
          0,
          (prev, record) => prev + record.count,
        ) /
        _records.length;

    Color averageColor;
    String averageText;

    if (average >= 10) {
      averageColor = Colors.green;
      averageText = '아주 열심히!';
    } else if (average >= 5) {
      averageColor = Colors.orange;
      averageText = '꾸준히 학습 중';
    } else {
      averageColor = Colors.red;
      averageText = '조금 더 해볼까요?';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: averageColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      // ✅ Row → Wrap (overflow 방지)
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Icon(
            Icons.trending_up,
            color: averageColor,
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            '하루 평균 학습 단어 수: ',
            style: GoogleFonts.notoSans(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            '${average.toStringAsFixed(1)}개',
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
