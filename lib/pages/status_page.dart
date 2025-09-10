import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

class StudyGraphPage extends StatefulWidget {
  const StudyGraphPage({super.key});

  @override
  State<StudyGraphPage> createState() => _StudyGraphPageState();
}

class _StudyGraphPageState extends State<StudyGraphPage> {
  String nextReviewDate = "-"; // 서버에서 받아올 다음 복습일
  List<DateTime> reviewedDates = []; // 복습 완료 날짜 리스트
  List<FlSpot> studySpots = []; // 공부 시간 그래프 데이터

  final String userId = "user123"; // 예시
  final int wordId = 1;

  @override
  void initState() {
    super.initState();
    _fetchNextReview();
    _loadStudyData();
  }

  // 서버에서 nextReviewAt 가져오기
  Future<void> _fetchNextReview() async {
    final url = Uri.parse(
      "http://localhost:8080/api/personal-words/review/$wordId/$userId",
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          nextReviewDate = data['nextReviewAt'];
          // 기존 데이터에서 복습 완료 날짜 기록 (등록일 등)
          reviewedDates.add(DateTime.parse(data['registeredAt']));
        });
      } else {
        setState(() {
          nextReviewDate = "불러오기 실패";
        });
      }
    } catch (e) {
      setState(() {
        nextReviewDate = "네트워크 오류";
      });
    }
  }

  // 오늘 복습 완료 버튼 클릭 시
  Future<void> _markReviewedToday() async {
    final today = DateTime.now();
    final url = Uri.parse(
      "http://localhost:8080/api/personal-words/review/$wordId/$userId",
    );
    try {
      final response = await http.put(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          nextReviewDate = data['nextReviewAt'];
          reviewedDates.add(today);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("오늘 복습 완료!")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("복습 업데이트 실패: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("네트워크 오류: $e")));
    }
  }

  // 공부 시간 데이터 로드 (예시로 랜덤 생성)
  void _loadStudyData() {
    studySpots = [
      FlSpot(0, 1.5),
      FlSpot(1, 2.0),
      FlSpot(2, 1.0),
      FlSpot(3, 3.0),
      FlSpot(4, 2.5),
      FlSpot(5, 0.5),
      FlSpot(6, 2.0),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("공부 현황")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "다음 복습일: $nextReviewDate",
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _markReviewedToday,
              child: const Text("오늘 복습 완료"),
            ),
            const SizedBox(height: 20),
            Text(
              "복습한 날: ${reviewedDates.map((d) => d.toIso8601String().substring(0, 10)).join(", ")}",
            ),
            const SizedBox(height: 20),
            Expanded(
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 6,
                  lineBarsData: [
                    LineChartBarData(
                      spots: studySpots,
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
                          final index = value.toInt();
                          if (index < 0 || index >= labels.length)
                            return const SizedBox();
                          return Text(labels[index]);
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
