// word_digital_doc.dart - 디지털 문서 이미지에서 형광펜 색상 선택 및 단어 추출
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'dart:io' show File;

import 'word_loading.dart';
import 'word_meaning.dart';
import 'mean_loading.dart';
import '../../config/url_config.dart';

class WordDigitalDocPage extends StatefulWidget {
  final int wordbookId;

  const WordDigitalDocPage({
    Key? key,
    required this.wordbookId,
  }) : super(key: key);

  @override
  State<WordDigitalDocPage> createState() => _WordDigitalDocPageState();
}

class _WordDigitalDocPageState extends State<WordDigitalDocPage> {
  final ImagePicker _imagePicker = ImagePicker();

  int _step = 0; // 0=이미지 선택, 1=픽셀 선택, 2=단어 리스트, 3=의미 선택
  Uint8List? _imageBytes;
  String? _imageFilename;
  ui.Image? _decodedImage;

  // 선택된 HSV 값
  int _selectedH = 0;
  int _selectedS = 0;
  int _selectedV = 0;

  List<String> _wordsToAdd = [];
  Map<String, List<WordMeaning>> _wordsWithMeanings = {};
  Map<String, Set<String>> _selectedMeanings = {};

  bool _loading = false;

  // 확대/축소 컨트롤러
  final TransformationController _transformController = TransformationController();

  String _normalize(String s) => s.toLowerCase().trim();

  @override
  void initState() {
    super.initState();
    // 페이지 시작 시 바로 이미지 선택
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickImageFromGallery();
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  /// 갤러리에서 이미지 선택
  Future<void> _pickImageFromGallery() async {
    final isDesktop = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;

    Uint8List? bytes;
    String? filename;

    if (isDesktop) {
      // 데스크톱: FilePicker 사용
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (res == null || res.files.isEmpty) {
        if (mounted) Navigator.pop(context); // 취소 시 페이지 닫기
        return;
      }
      final f = res.files.single;
      bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
      filename = f.name;
    } else {
      // 모바일: ImagePicker 사용
      final x = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
        maxWidth: 3000,
      );
      if (x == null) {
        if (mounted) Navigator.pop(context); // 취소 시 페이지 닫기
        return;
      }
      bytes = await x.readAsBytes();
      filename = x.name;
    }

    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지를 불러오지 못했습니다.')),
      );
      Navigator.pop(context);
      return;
    }

    // 이미지 디코딩
    final decodedImage = await _decodeImage(bytes);
    if (decodedImage == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지를 디코딩할 수 없습니다.')),
      );
      Navigator.pop(context);
      return;
    }

    setState(() {
      _imageBytes = bytes;
      _imageFilename = filename;
      _decodedImage = decodedImage;
      _step = 1; // 픽셀 선택 단계로 이동
    });
  }

  /// 이미지 디코딩 (dart:ui)
  Future<ui.Image?> _decodeImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      print('❌ 이미지 디코딩 실패: $e');
      return null;
    }
  }

  /// 터치한 위치의 픽셀 색상 가져오기 (RGB → HSV 변환)
  Future<void> _onImageTap(Offset localPosition, Size widgetSize) async {
    if (_decodedImage == null || _imageBytes == null) return;

    // ✅ InteractiveViewer의 변환 행렬에서 scale과 translation 추출
    final Matrix4 transform = _transformController.value;
    final double scale = transform.getMaxScaleOnAxis();
    final double translateX = transform.getTranslation().x;
    final double translateY = transform.getTranslation().y;

    // 터치한 위치를 변환 행렬로 역변환 (확대/이동 고려)
    final double transformedX = (localPosition.dx - translateX) / scale;
    final double transformedY = (localPosition.dy - translateY) / scale;

    // 실제 이미지 크기
    final imageWidth = _decodedImage!.width;
    final imageHeight = _decodedImage!.height;

    // 화면에 표시된 이미지 크기 계산 (fit: BoxFit.contain 고려)
    final widgetAspectRatio = widgetSize.width / widgetSize.height;
    final imageAspectRatio = imageWidth / imageHeight;

    double displayWidth, displayHeight;
    double offsetX = 0, offsetY = 0;

    if (widgetAspectRatio > imageAspectRatio) {
      // 위젯이 더 넓음 → 세로 기준으로 맞춤
      displayHeight = widgetSize.height;
      displayWidth = displayHeight * imageAspectRatio;
      offsetX = (widgetSize.width - displayWidth) / 2;
    } else {
      // 위젯이 더 좁음 → 가로 기준으로 맞춤
      displayWidth = widgetSize.width;
      displayHeight = displayWidth / imageAspectRatio;
      offsetY = (widgetSize.height - displayHeight) / 2;
    }

    // 역변환된 좌표에서 오프셋 제거
    final adjustedX = transformedX - offsetX;
    final adjustedY = transformedY - offsetY;

    // 이미지 표시 영역을 벗어난 경우 무시
    if (adjustedX < 0 || adjustedX > displayWidth || adjustedY < 0 || adjustedY > displayHeight) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지 영역을 터치해주세요')),
      );
      return;
    }

    // 화면 좌표를 실제 이미지 픽셀 좌표로 변환
    final scaleX = imageWidth / displayWidth;
    final scaleY = imageHeight / displayHeight;

    final x = (adjustedX * scaleX).clamp(0, imageWidth - 1).toInt();
    final y = (adjustedY * scaleY).clamp(0, imageHeight - 1).toInt();

    // 픽셀 데이터 가져오기
    final byteData = await _decodedImage!.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return;

    final pixelIndex = (y * imageWidth + x) * 4;
    final r = byteData.getUint8(pixelIndex);
    final g = byteData.getUint8(pixelIndex + 1);
    final b = byteData.getUint8(pixelIndex + 2);

    print('🎨 터치한 픽셀 좌표: (x: $x, y: $y)');
    print('🎨 RGB 값: R=$r, G=$g, B=$b');

    // RGB → HSV 변환
    final hsv = _rgbToHsv(r, g, b);

    print('🎨 HSV 변환 결과: H=${hsv['h']}, S=${hsv['s']}, V=${hsv['v']}');

    setState(() {
      _selectedH = hsv['h']!;
      _selectedS = hsv['s']!;
      _selectedV = hsv['v']!;
    });

    // 색상 선택 완료 후 확인 다이얼로그
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('색상 선택 완료'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('선택한 픽셀 색상:'),
            const SizedBox(height: 8),
            Text('RGB: ($r, $g, $b)', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('OpenCV HSV 값:'),
            const SizedBox(height: 4),
            Text('• H (색상): $_selectedH (0-179)'),
            Text('• S (채도): $_selectedS (0-255)'),
            Text('• V (명도): $_selectedV (0-255)'),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('색상 미리보기: '),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, r, g, b),
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '이 색상으로 형광펜을 인식하시겠습니까?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('다시 선택'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4E6E99),
              foregroundColor: Colors.white,
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // FastAPI로 전송
      await _sendToHighlightAPI();
    }
  }

  /// RGB → HSV 변환 (OpenCV 범위: H(0-179), S(0-255), V(0-255))
  Map<String, int> _rgbToHsv(int r, int g, int b) {
    final rNorm = r / 255.0;
    final gNorm = g / 255.0;
    final bNorm = b / 255.0;

    final max = math.max(rNorm, math.max(gNorm, bNorm));
    final min = math.min(rNorm, math.min(gNorm, bNorm));
    final delta = max - min;

    // Hue 계산 (0-360 범위로 먼저 계산)
    double h = 0;
    if (delta != 0) {
      if (max == rNorm) {
        h = 60 * (((gNorm - bNorm) / delta) % 6);
      } else if (max == gNorm) {
        h = 60 * (((bNorm - rNorm) / delta) + 2);
      } else {
        h = 60 * (((rNorm - gNorm) / delta) + 4);
      }
    }
    if (h < 0) h += 360;

    // ✅ OpenCV 범위로 변환
    // H: 0-360 → 0-179 (OpenCV는 8bit로 H를 저장하므로 절반)
    final hOpenCV = (h / 2).round();

    // Saturation 계산 (0-255)
    final s = (max == 0) ? 0 : (delta / max) * 255;

    // Value 계산 (0-255)
    final v = max * 255;

    return {
      'h': hOpenCV,
      's': s.round(),
      'v': v.round(),
    };
  }

  /// FastAPI /api/highlight/process로 전송
  Future<void> _sendToHighlightAPI() async {
    if (_imageBytes == null || _imageFilename == null) return;

    setState(() => _loading = true);

    // WordLoadingPage로 이동하며 OCR 처리
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WordLoadingPage(
          task: () async {
            try {
              final fastApiUrl = UrlConfig.fastApiBaseUrl;
              final uri = Uri.parse('$fastApiUrl/api/highlight/process');

              print('[Highlight] 📡 Sending request to: $uri');
              print('[Highlight] 🎨 HSV: H=$_selectedH, S=$_selectedS, V=$_selectedV');

              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString('jwt_token') ?? '';

              final request = http.MultipartRequest('POST', uri)
                ..headers.addAll({
                  'ngrok-skip-browser-warning': '69420',
                  if (token.isNotEmpty) 'Authorization': 'Bearer $token',
                })
                ..fields['h'] = _selectedH.toString()
                ..fields['s'] = _selectedS.toString()
                ..fields['v'] = _selectedV.toString()
                ..files.add(
                  http.MultipartFile.fromBytes(
                    'image',  // ✅ FastAPI가 기대하는 필드명
                    _imageBytes!,
                    filename: _imageFilename,
                  ),
                );

              final streamed = await request.send();
              final response = await http.Response.fromStream(streamed);

              print('[Highlight] 📥 Response status: ${response.statusCode}');

              if (!mounted) return;

              if (response.statusCode == 200) {
                final decoded = jsonDecode(utf8.decode(response.bodyBytes));

                // ✅ 디버깅: FastAPI 응답 전체 출력
                print('[Highlight] 📦 FastAPI 전체 응답: $decoded');

                if (decoded is Map && decoded['words'] is List) {
                  final words = List<String>.from(decoded['words']);

                  // ✅ 디버깅: 추출된 단어 개수 출력
                  print('[Highlight] 🔤 FastAPI가 반환한 단어 개수: ${words.length}');
                  print('[Highlight] 📝 단어 리스트: $words');

                  setState(() {
                    _wordsToAdd = words.map(_normalize).toList();
                    print('[Highlight] ✅ _wordsToAdd에 저장된 단어 개수: ${_wordsToAdd.length}');
                    print('[Highlight] 📋 _wordsToAdd 내용: $_wordsToAdd');
                    _step = 2;
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('단어 인식 결과가 올바르지 않습니다.')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('형광펜 인식 오류 (${response.statusCode})'),
                  ),
                );
              }
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('형광펜 인식 실패: $e')),
              );
            } finally {
              if (mounted) setState(() => _loading = false);
            }
          },
        ),
      ),
    );
  }

  /// 단어 뜻 조회
  Future<void> _fetchMeanings() async {
    if (_wordsToAdd.isEmpty) return;

    // ✅ 디버깅: Spring에 전송하기 전 단어 개수 확인
    print('[Spring 전송] 📤 전송할 단어 개수: ${_wordsToAdd.length}');
    print('[Spring 전송] 📝 전송할 단어 리스트: $_wordsToAdd');

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    setState(() => _loading = true);

    final url = Uri.parse(
      'https://semiconical-shela-loftily.ngrok-free.dev/api/words/save-from-api',
    );

    final requestBody = jsonEncode({'wordsEn': _wordsToAdd});
    print('[Spring 전송] 📦 Request Body: $requestBody');
    print('[Spring 전송] 📏 Body 크기: ${requestBody.length} bytes');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        },
        body: requestBody,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        // ✅ 디버깅: Spring 응답 출력
        print('[Spring 응답] 📥 응답 전체: $decoded');

        final List results = decoded is List
            ? decoded
            : (decoded is Map && decoded['results'] is List
                ? decoded['results']
                : []);

        // ✅ 디버깅: results 배열 크기 출력
        print('[Spring 응답] 🔢 results 배열 크기: ${results.length}');

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

        // ✅ 디버깅: 최종 뜻 조회 결과
        print('[Spring 응답] ✅ 뜻 조회 성공한 단어 개수: ${newMeanings.length}');
        print('[Spring 응답] 📚 조회된 단어: ${newMeanings.keys.toList()}');

        setState(() {
          _wordsWithMeanings = newMeanings;
          _selectedMeanings = {
            for (var w in newMeanings.keys) w: <String>{},
          };
          _step = 3;
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
      backgroundColor: const Color(0xFFF6F0E9),
      appBar: AppBar(
        title: Text(_step == 1
            ? '형광펜 색상 선택'
            : _step == 2
                ? '인식된 단어'
                : _step == 3
                    ? '단어 뜻 선택'
                    : '디지털 문서 추가'),
        backgroundColor: const Color(0xFF4E6E99),
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_step == 0) {
      // 이미지 선택 중 (로딩)
      return const Center(child: CircularProgressIndicator());
    } else if (_step == 1) {
      // 픽셀 선택 화면
      return _buildPixelPickerView();
    } else if (_step == 2) {
      // 단어 리스트
      return _buildWordListView();
    } else if (_step == 3) {
      // 의미 선택
      return _buildMeaningSelectionView();
    }
    return const SizedBox.shrink();
  }

  /// 픽셀 선택 화면 (확대/축소 가능)
  Widget _buildPixelPickerView() {
    if (_imageBytes == null) {
      return const Center(child: Text('이미지를 불러올 수 없습니다.'));
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            '형광펜 색상이 칠해진 픽셀을 터치하세요\n(확대/축소 가능)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // ✅ Expanded 영역의 정확한 크기
              final widgetSize = Size(constraints.maxWidth, constraints.maxHeight);

              return InteractiveViewer(
                transformationController: _transformController,
                minScale: 1.0,
                maxScale: 5.0,
                child: GestureDetector(
                  onTapDown: (details) {
                    // ✅ 터치한 위치를 로컬 좌표로 변환
                    final RenderBox box = context.findRenderObject() as RenderBox;
                    final localPosition = box.globalToLocal(details.globalPosition);

                    print('🎯 터치 위치: ${localPosition.dx}, ${localPosition.dy}');
                    print('📐 위젯 크기: ${widgetSize.width} x ${widgetSize.height}');

                    _onImageTap(localPosition, widgetSize);
                  },
                  child: Center(
                    child: Image.memory(
                      _imageBytes!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.zoom_in),
                label: const Text('확대'),
                onPressed: () {
                  final currentScale = _transformController.value.getMaxScaleOnAxis();
                  if (currentScale < 5.0) {
                    _transformController.value = Matrix4.identity()..scale(currentScale + 0.5);
                  }
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.zoom_out),
                label: const Text('축소'),
                onPressed: () {
                  final currentScale = _transformController.value.getMaxScaleOnAxis();
                  if (currentScale > 1.0) {
                    _transformController.value = Matrix4.identity()..scale(currentScale - 0.5);
                  }
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('초기화'),
                onPressed: () {
                  _transformController.value = Matrix4.identity();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 단어 리스트 화면
  Widget _buildWordListView() {
    return Column(
      children: [
        Expanded(
          child: _wordsToAdd.isEmpty
              ? const Center(child: Text('인식된 단어가 없습니다.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _wordsToAdd.length,
                  itemBuilder: (_, i) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.bookmark),
                      title: Text(_wordsToAdd[i]),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _loading
                    ? null
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => MeanLoadingPage(task: _fetchMeanings),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFCC8C8),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(120, 45),
                ),
                child: const Text('뜻 조회'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4E6E99),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 45),
                ),
                child: const Text('나가기'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 의미 선택 화면
  Widget _buildMeaningSelectionView() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _wordsWithMeanings.length,
            itemBuilder: (_, i) {
              final word = _wordsWithMeanings.keys.elementAt(i);
              final meanings = _wordsWithMeanings[word]!;
              final selectedSet = _selectedMeanings[word]!;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        word,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: meanings.map((m) {
                          final isSelected = selectedSet.contains(m.wordKr);
                          return ChoiceChip(
                            label: Text(
                              m.wordKr,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF4E6E99),
                            backgroundColor: const Color(0xFFF6F0E9),
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
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _loading ? null : _saveToWordbook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFCC8C8),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(120, 45),
                ),
                child: const Text('저장'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4E6E99),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 45),
                ),
                child: const Text('나가기'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
