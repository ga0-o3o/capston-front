// word_image.dart
import 'dart:typed_data';
import 'dart:io' show File;

import 'word_loading.dart';
import 'word_meaning.dart';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ✅ 중앙 URL 관리 import
import '../../config/url_config.dart';

class WordImagePage extends StatefulWidget {
  final int wordbookId;
  final Map<String, int> hsvValues;

  const WordImagePage({
    Key? key,
    required this.wordbookId,
    required this.hsvValues,
  }) : super(key: key);

  @override
  State<WordImagePage> createState() => _WordImagePageState();
}

class _WordImagePageState extends State<WordImagePage> {
  final ImagePicker _imagePicker = ImagePicker();

  int _step = 0; // 0=초기, 1=단어리스트, 2=의미리스트
  List<String> _wordsToAdd = [];
  Map<String, List<WordMeaning>> _wordsWithMeanings = {};

  /// ✅ 단어별로 "선택된 한국어 뜻"을 저장
  ///   - key: wordEn (표제어)
  ///   - value: 선택된 wordKr 문자열 집합
  Map<String, Set<String>> _selectedMeanings = {};

  bool _loading = false; // 뜻 조회 / 저장 시 버튼 비활성용 정도로만 사용
  String _backgroundImage = "assets/images/background/letter_open.png";

  // ✉️ 애니메이션 & OCR 대기 이미지
  bool _showLetterAnim = false;
  Uint8List? _pendingBytes;
  String? _pendingFilename;

  String _normalize(String s) => s.toLowerCase().trim();

  @override
  void initState() {
    super.initState();
  }

  // 이미지 선택 (카메라 / 앨범 / 파일)
  Future<void> _openImageSourceSheet() async {
    final isDesktop = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (isDesktop) {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.single;
      final bytes = f.bytes ??
          (f.path != null ? await File(f.path!).readAsBytes() : null);
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지를 불러오지 못했습니다.')),
        );
        return;
      }
      await _uploadAndExtract(bytes, f.name);
      return;
    }

    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('사진 촬영'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('앨범에서 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (src == null) return;

    final x = await _imagePicker.pickImage(
      source: src,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    await _uploadAndExtract(bytes, x.name);
  }

  /// 🔤 FastAPI OCR 이미지 업로드 및 단어 추출
  Future<void> _uploadAndExtract(Uint8List bytes, String filename) async {
    // 1) 파일 크기 체크 (8MB 초과 시 바로 에러)
    if (bytes.lengthInBytes > 8 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지 크기가 너무 큽니다(최대 8MB).')),
      );
      return;
    }

    // 2) 애니메이션을 위한 데이터 저장 & 배경+편지 애니 시작
    setState(() {
      _pendingBytes = bytes;
      _pendingFilename = filename;
      _backgroundImage = "assets/images/background/mailbox.png"; // 📮 배경 변경
      _showLetterAnim = true; // ✉️ letter.png 애니 시작
    });
  }

  /// ✉️ 애니메이션이 끝난 뒤에 실제 OCR를 수행하면서 WordLoadingPage로 이동
  void _startOcrAfterAnim() {
    final bytes = _pendingBytes;
    final filename = _pendingFilename;

    if (bytes == null || filename == null) return;

    // 한 번만 사용하도록 비워두기
    _pendingBytes = null;
    _pendingFilename = null;

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WordLoadingPage(
          // ✅ 이 task 안에서 실제 OCR 네트워크 요청 수행
          task: () async {
            try {
              // ✅ UrlConfig에서 FastAPI URL 자동으로 가져옴
              final fastApiUrl = UrlConfig.fastApiBaseUrl;
              final uri = Uri.parse('$fastApiUrl/api/ocr/extract');

              print('[OCR] 📡 Sending OCR request to: $uri');
              print('[OCR] 🌐 FastAPI URL: $fastApiUrl');

              // ✅ JWT 토큰 가져오기
              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString('jwt_token') ?? '';

              final request = http.MultipartRequest('POST', uri)
                ..headers.addAll({
                  'ngrok-skip-browser-warning': '69420',
                  if (token.isNotEmpty) 'Authorization': 'Bearer $token',
                })
                ..files.add(
                  http.MultipartFile.fromBytes('file', bytes,
                      filename: filename),
                );

              final streamed = await request.send();
              final response = await http.Response.fromStream(streamed);

              print('[OCR] 📥 Response status: ${response.statusCode}');

              if (!mounted) return;

              if (response.statusCode == 200) {
                final decoded = jsonDecode(utf8.decode(response.bodyBytes));
                if (decoded is Map && decoded['words'] is List) {
                  final words = List<String>.from(decoded['words']);

                  setState(() {
                    _wordsToAdd = words.map(_normalize).toList();
                    _step = 1;
                    _backgroundImage = "assets/images/background/word_list.png";
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('단어 인식 결과가 올바르지 않습니다.')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('FastAPI OCR 오류 (${response.statusCode})'),
                  ),
                );
              }
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('OCR 요청 실패: $e')),
              );
            }
          },
        ),
      ),
    );
    // WordLoadingPage는 task 끝나면 스스로 pop됨
  }

  /// 단어 뜻 조회
  Future<void> _fetchMeanings() async {
    if (_wordsToAdd.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    setState(() => _loading = true);

    final url = Uri.parse(
      'https://semiconical-shela-loftily.ngrok-free.dev/api/words/save-from-api',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'wordsEn': _wordsToAdd}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final List results = decoded is List
            ? decoded
            : (decoded is Map && decoded['results'] is List
                ? decoded['results']
                : []);

        final Map<String, List<WordMeaning>> newMeanings = {};
        for (final item in results) {
          if (item is! Map) continue;
          final canonical =
              (item['wordEn'] ?? item['canonical'])?.toString().trim();
          if (canonical == null || canonical.isEmpty) continue;
          final raw = item['wordMeanings'] ?? item['meanings'];
          if (raw is! List) continue;

          final list = <WordMeaning>[];
          for (final e in raw) {
            if (e is Map && e['wordKr'] != null) {
              list.add(
                WordMeaning(
                  wordId: e['wordId'],
                  wordKr: e['wordKr'],
                ),
              );
            }
          }
          if (list.isNotEmpty) newMeanings[canonical] = list;
        }

        setState(() {
          _wordsWithMeanings = newMeanings;
          // ✅ 단어별 선택된 뜻은 처음에는 비어 있는 집합
          _selectedMeanings = {
            for (var w in newMeanings.keys) w: <String>{},
          };
          _step = 2;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('뜻 조회 실패: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('뜻 조회 중 오류: $e')),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  /// 단어장 저장
  Future<void> _saveToWordbook() async {
    // ✅ "선택된 뜻이 하나 이상 있는 단어"만 저장
    final selectedData = _wordsWithMeanings.entries
        .where((e) => (_selectedMeanings[e.key]?.isNotEmpty ?? false))
        .map(
          (e) => {
            'wordEn': e.key,
            'wordKrList': _selectedMeanings[e.key]!.toList(),
          },
        )
        .toList();

    if (selectedData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장할 단어가 없습니다.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    setState(() => _loading = true);
    final url = Uri.parse(
      'https://semiconical-shela-loftily.ngrok-free.dev/api/words/personal-wordbook/${widget.wordbookId}',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'words': selectedData}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단어가 단어장에 등록되었습니다.')),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 실패: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 중 오류: $e')),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ✅ 배경만 확대
          Transform.scale(
            scale: _backgroundImage == "assets/images/background/word_list.png"
                ? 1.1
                : 1.4,
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(_backgroundImage),
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),

          // ✅ 실제 내용 (버튼/리스트 등)은 원래 크기 유지
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                if (_step == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 180),
                    child: Center(
                      child: _showLetterAnim
                          ? const SizedBox.shrink()
                          : ElevatedButton.icon(
                              icon: const Icon(Icons.image_search),
                              label: const Text('이미지로 단어 추가'),
                              onPressed:
                                  _loading ? null : _openImageSourceSheet,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFCC8C8),
                                foregroundColor: Colors.black,
                                minimumSize: const Size(100, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(0),
                                ),
                              ),
                            ),
                    ),
                  )
                else if (_step == 1)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(40, 60, 40, 80),
                      child: ListView.builder(
                        itemCount: _wordsToAdd.length,
                        itemBuilder: (_, i) => ListTile(
                          leading: const Icon(Icons.bookmark),
                          title: Text(_wordsToAdd[i]),
                        ),
                      ),
                    ),
                  )
                else if (_step == 2)
                  Expanded(
                    child: Padding(
                      // 🔹 전체 영역 패딩 (위/아래 살짝 줄임)
                      padding: const EdgeInsets.fromLTRB(40, 60, 35, 80),
                      child: ListView.builder(
                        itemCount: _wordsWithMeanings.length,
                        itemBuilder: (_, i) {
                          final word = _wordsWithMeanings.keys.elementAt(i);
                          final meanings = _wordsWithMeanings[word]!;
                          final selectedSet = _selectedMeanings[word]!;

                          return Container(
                            // 🔹 단어 묶음 간 여백 — 위아래 12px 정도로 자연스럽게
                            margin: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 10),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  word,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: meanings.map((m) {
                                    final isSelected =
                                        selectedSet.contains(m.wordKr);
                                    return ChoiceChip(
                                      label: Text(m.wordKr),
                                      selected: isSelected,
                                      selectedColor: const Color(0xFFFCC8C8),
                                      onSelected: (v) {
                                        setState(() {
                                          if (v) {
                                            selectedSet.add(m.wordKr);
                                          } else {
                                            selectedSet.remove(m.wordKr);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ✉️ 편지 축소 애니메이션 오버레이
          if (_showLetterAnim)
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: 0.0),
                duration: const Duration(milliseconds: 3000),
                onEnd: () {
                  if (!mounted) return;
                  setState(() => _showLetterAnim = false);
                  _startOcrAfterAnim();
                },
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: value,
                      child: child,
                    ),
                  );
                },
                child: Image.asset(
                  'assets/images/background/letter.png',
                  width: 260,
                ),
              ),
            ),

          // 하단 버튼
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: (_step == 1 || _step == 2) ? 30 : 100),
              child: (_step == 1 || _step == 2)
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 왼쪽: 뜻 조회 / 저장 버튼
                        SizedBox(
                          width: 140, // ✅ 가로폭 지정
                          child: ElevatedButton(
                            onPressed: _loading
                                ? null
                                : (_step == 1
                                    ? _fetchMeanings
                                    : _saveToWordbook),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFCC8C8),
                              foregroundColor: Colors.black,
                              minimumSize: const Size(0, 45),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                                side: BorderSide(color: Colors.black, width: 2),
                              ),
                            ),
                            child: Text(_step == 1 ? '뜻 조회' : '저장'),
                          ),
                        ),
                        const SizedBox(width: 20), // 버튼 간 간격
                        // 오른쪽: 나가기 버튼
                        SizedBox(
                          width: 140, // ✅ 가로폭 지정
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4E6E99),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 45),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                                side: BorderSide(color: Colors.black, width: 2),
                              ),
                            ),
                            child: const Text('나가기',
                                style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    )
                  : ElevatedButton(
                      // step 0일 때는 나가기만 단독
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4E6E99),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(150, 45),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                          side: BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                      child: const Text('나가기', style: TextStyle(fontSize: 16)),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class WordImageUploader extends StatelessWidget {
  final int? wordbookId;
  final Map<String, int> hsvValues;

  const WordImageUploader({
    Key? key,
    this.wordbookId,
    required this.hsvValues,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.image_search, color: Colors.black),
      label: const Text("이미지로 단어 추가"),
      onPressed: () {
        if (wordbookId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('단어장이 선택되지 않았습니다.')),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WordImagePage(
              wordbookId: wordbookId!,
              hsvValues: hsvValues,
            ),
          ),
        );
      },
    );
  }
}
