// word_image_fixed.dart - PDF 업로드 지원 버전
import 'dart:typed_data';
import 'dart:io' show File;
import 'dart:math' as math;

import 'word_loading.dart';
import 'word_meaning.dart';
import 'mean_loading.dart';

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

  final Uint8List? initialBytes;
  final String? initialFilename;

  const WordImagePage({
    Key? key,
    required this.wordbookId,
    required this.hsvValues,
    this.initialBytes,
    this.initialFilename,
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
  Map<String, Set<String>> _selectedMeanings = {};

  bool _loading = false;
  String _backgroundImage = "assets/images/background/letter_open.png";

  // ✉️ 애니메이션 & OCR 대기 이미지
  bool _showLetterAnim = false;
  Uint8List? _pendingBytes;
  String? _pendingFilename;

  String _normalize(String s) => s.toLowerCase().trim();

  @override
  void initState() {
    super.initState();

    if (widget.initialBytes != null && widget.initialFilename != null) {
      _pendingBytes = widget.initialBytes;
      _pendingFilename = widget.initialFilename;
      _backgroundImage = "assets/images/background/mailbox.png";
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        setState(() => _showLetterAnim = true);
      });
    }
  }

  // ============================================================================
  // ✅ 이미지/PDF 선택 (통합)
  // ============================================================================
  Future<void> _openFileSourceSheet() async {
    final isDesktop = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (isDesktop) {
      // 데스크톱: FilePicker로 이미지 + PDF 선택
      await _pickFileDesktop();
      return;
    }

    // 모바일: 카메라/갤러리/PDF 선택 Bottom Sheet
    final selection = await showModalBottomSheet<String>(
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
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('앨범에서 선택'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF 파일 선택'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
          ],
        ),
      ),
    );

    if (selection == null) return;

    if (selection == 'camera' || selection == 'gallery') {
      await _pickImageMobile(selection == 'camera'
          ? ImageSource.camera
          : ImageSource.gallery);
    } else if (selection == 'pdf') {
      await _pickPdfMobile();
    }
  }

  /// 데스크톱: FilePicker로 이미지 + PDF 선택
  Future<void> _pickFileDesktop() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'pdf'], // ✅ PDF 추가
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
        const SnackBar(content: Text('파일을 불러오지 못했습니다.')),
      );
      return;
    }

    // ✅ 파일 크기 체크 (20MB)
    if (bytes.lengthInBytes > 20 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일 크기가 너무 큽니다 (최대 20MB).')),
      );
      return;
    }

    await _uploadAndExtract(bytes, f.name);
  }

  /// 모바일: ImagePicker로 사진/갤러리 선택
  Future<void> _pickImageMobile(ImageSource source) async {
    final x = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (x == null) return;

    final bytes = await x.readAsBytes();
    await _uploadAndExtract(bytes, x.name);
  }

  /// 모바일: FilePicker로 PDF 선택
  Future<void> _pickPdfMobile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
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
        const SnackBar(content: Text('PDF 파일을 불러오지 못했습니다.')),
      );
      return;
    }

    // ✅ 파일 크기 체크 (20MB)
    if (bytes.lengthInBytes > 20 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF 크기가 너무 큽니다 (최대 20MB).')),
      );
      return;
    }

    await _uploadAndExtract(bytes, f.name);
  }

  // ============================================================================
  // ✅ FastAPI OCR 업로드 (이미지 + PDF 통합)
  // ============================================================================
  Future<void> _uploadAndExtract(Uint8List bytes, String filename) async {
    // 파일 확장자 검증
    final ext = filename.toLowerCase().split('.').last;
    final allowedExtensions = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'pdf'];

    if (!allowedExtensions.contains(ext)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('지원하지 않는 파일 형식입니다: .$ext\n'
              '지원 형식: PNG, JPG, JPEG, GIF, WEBP, PDF'),
        ),
      );
      return;
    }

    // 애니메이션 시작
    setState(() {
      _pendingBytes = bytes;
      _pendingFilename = filename;
      _backgroundImage = "assets/images/background/mailbox.png";
      _showLetterAnim = true;
    });
  }

  // ============================================================================
  // ✅ OCR 실제 수행 (애니메이션 후)
  // ============================================================================
  void _startOcrAfterAnim() {
    final bytes = _pendingBytes;
    final filename = _pendingFilename;

    if (bytes == null || filename == null) return;

    _pendingBytes = null;
    _pendingFilename = null;

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WordLoadingPage(
          task: () async {
            try {
              final fastApiUrl = UrlConfig.fastApiBaseUrl;
              final uri = Uri.parse('$fastApiUrl/api/ocr/extract');

              print('[OCR] 📡 Sending OCR request');
              print('[OCR] 📄 File: $filename');
              print('[OCR] 📦 Size: ${bytes.lengthInBytes} bytes');
              print('[OCR] 🌐 Endpoint: $uri');

              // JWT 토큰 가져오기
              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString('jwt_token') ?? '';

              // ✅ Content-Type 자동 감지
              String contentType = 'application/octet-stream';
              final ext = filename.toLowerCase().split('.').last;
              if (ext == 'png') {
                contentType = 'image/png';
              } else if (ext == 'jpg' || ext == 'jpeg') {
                contentType = 'image/jpeg';
              } else if (ext == 'gif') {
                contentType = 'image/gif';
              } else if (ext == 'webp') {
                contentType = 'image/webp';
              } else if (ext == 'pdf') {
                contentType = 'application/pdf'; // ✅ PDF MIME 타입
              }

              print('[OCR] 📋 Content-Type: $contentType');

              // ✅ MultipartRequest 생성
              final request = http.MultipartRequest('POST', uri)
                ..headers.addAll({
                  'ngrok-skip-browser-warning': '69420',
                  'Ngrok-Skip-Browser-Warning': '69420',
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                  if (token.isNotEmpty) 'Authorization': 'Bearer $token',
                })
                ..files.add(
                  http.MultipartFile.fromBytes(
                    'file', // ✅ 서버가 요구하는 필드명: 'file'
                    bytes,
                    filename: filename,
                    contentType: http.MediaType.parse(contentType),
                  ),
                );

              print('[OCR] 🚀 Uploading...');

              // ✅ 타임아웃 5분 (PDF 처리 시간 고려)
              final streamed = await request
                  .send()
                  .timeout(const Duration(minutes: 5));
              final response = await http.Response.fromStream(streamed);

              print('[OCR] 📥 Response: ${response.statusCode}');

              if (!mounted) return;

              if (response.statusCode == 200) {
                final decoded = jsonDecode(utf8.decode(response.bodyBytes));
                print('[OCR] ✅ Success: ${decoded}');

                if (decoded is Map && decoded['words'] is List) {
                  final words = List<String>.from(decoded['words']);

                  // ✅ PDF의 경우 페이지 수 출력 (옵션)
                  if (decoded.containsKey('pages')) {
                    print('[OCR] 📖 PDF Pages: ${decoded['pages']}');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('PDF ${decoded['pages']}페이지 처리 완료'),
                      ),
                    );
                  }

                  setState(() {
                    _wordsToAdd = words.map(_normalize).toList();
                    _step = 1;
                    _backgroundImage =
                        "assets/images/background/word_list.png";
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('OCR 결과 형식이 올바르지 않습니다.'),
                    ),
                  );
                }
              } else if (response.statusCode == 400) {
                // 클라이언트 오류 (파일 형식, 디코딩 실패 등)
                final error = jsonDecode(response.body)['error'] ?? '알 수 없는 오류';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('업로드 오류: $error')),
                );
              } else if (response.statusCode == 500) {
                // 서버 오류
                final error = jsonDecode(response.body)['error'] ?? '서버 오류';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('서버 오류: $error')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('OCR 실패 (${response.statusCode})'),
                  ),
                );
              }
            } catch (e) {
              print('[OCR] ❌ Error: $e');
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('OCR 요청 실패: $e')),
              );
            }
          },
        ),
      ),
    );
  }

  // ============================================================================
  // ✅ 단어 뜻 조회
  // ============================================================================
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

  // ============================================================================
  // ✅ 단어장 저장
  // ============================================================================
  Future<void> _saveToWordbook() async {
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
          // 배경
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

          // 콘텐츠
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
                              label: const Text('이미지/PDF로 단어 추가'),
                              onPressed: _loading ? null : _openFileSourceSheet,
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
                      padding: const EdgeInsets.fromLTRB(30, 70, 30, 100),
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
                      padding: const EdgeInsets.fromLTRB(40, 60, 35, 80),
                      child: ListView.builder(
                        itemCount: _wordsWithMeanings.length,
                        itemBuilder: (_, i) {
                          final word = _wordsWithMeanings.keys.elementAt(i);
                          final meanings = _wordsWithMeanings[word]!;
                          final selectedSet = _selectedMeanings[word]!;

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final screenW = MediaQuery.of(context).size.width;
                              const double totalSafeHorizontal = 80.0;
                              final double cardWidth = math.min(
                                  420.0,
                                  math.max(
                                      200.0, screenW - totalSafeHorizontal));

                              return Center(
                                child: SizedBox(
                                  width: math.min(
                                      500.0, screenW - totalSafeHorizontal),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 10),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 20),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                              label: Text(
                                                m.wordKr,
                                                style: TextStyle(
                                                  color: selectedSet
                                                          .contains(m.wordKr)
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                              ),
                                              selected: isSelected,
                                              selectedColor:
                                                  const Color(0xFF4E6E99),
                                              backgroundColor:
                                                  const Color(0xFFF6F0E9),
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
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ✉️ 편지 애니메이션
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
                  bottom: (_step == 1 || _step == 2) ? 50 : 130),
              child: (_step == 1 || _step == 2)
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 140,
                          child: ElevatedButton(
                            onPressed: _loading
                                ? null
                                : (_step == 1
                                    ? () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            fullscreenDialog: true,
                                            builder: (_) => MeanLoadingPage(
                                                task: _fetchMeanings),
                                          ),
                                        );
                                      }
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
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 140,
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
      label: const Text("이미지/PDF로 단어 추가"),
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
