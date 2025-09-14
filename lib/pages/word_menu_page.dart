import 'dart:math';
import 'dart:typed_data';
import 'dart:io' show File;

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../models/word_item.dart';
import '../models/definition_item.dart';
import '../services/django_api.dart';
import '../widgets/review_words_sheet.dart';
import '../widgets/review_meanings_sheet.dart';

class WordMenuPage extends StatefulWidget {
  const WordMenuPage({super.key});
  @override
  State<WordMenuPage> createState() => _WordMenuPageState();
}

class _WordMenuPageState extends State<WordMenuPage> {
  // HSV 기본값
  Map<String, int> _hsvValues = {'h': 120, 's': 255, 'v': 255};

  final _items = <WordItem>[
    WordItem(word: 'highlight', meaning: '강조하다'),
    WordItem(word: 'extract', meaning: '추출하다'),
    WordItem(word: 'category', meaning: '부문'),
  ];

  final _imagePicker = ImagePicker();
  bool _uploading = false;

  final _rnd = Random();
  final _meanCtrl = TextEditingController();
  final _compCtrl = TextEditingController();
  final _meanFocus = FocusNode();
  late WordItem _cur;

  @override
  void initState() {
    super.initState();
    if (_items.isNotEmpty) _nextQuiz();
  }

  @override
  void dispose() {
    _meanCtrl.dispose();
    _compCtrl.dispose();
    _meanFocus.dispose();
    super.dispose();
  }

  void _nextQuiz() {
    if (_items.isEmpty) return;
    _cur = _items[_rnd.nextInt(_items.length)];
    _meanCtrl.clear();
    _compCtrl.clear();
    setState(() {});
    Future.delayed(
        const Duration(milliseconds: 30), () => _meanFocus.requestFocus());
  }

  bool _isMeaningCorrect() =>
      _meanCtrl.text.trim().toLowerCase() == _cur.meaning.trim().toLowerCase();

  List<String> _validateComposition(String s, String target) {
    final t = s.trim();
    final out = <String>[];
    if (t.isEmpty) return out;
    if (!t.toLowerCase().contains(target.toLowerCase()))
      out.add('문장에 "$target" 단어가 포함되어야 해요.');
    if (t.split(RegExp(r'\s+')).length < 4) out.add('문장은 4단어 이상으로 작성해 주세요.');
    if (!RegExp(r'[.!?]$').hasMatch(t)) out.add('문장 끝에 마침표/물음표를 붙이면 더 좋아요.');
    return out;
  }

  Future<void> _confirmQuiz() async {
    final mean = _meanCtrl.text.trim();
    if (mean.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('뜻을 먼저 입력하세요.')));
      return;
    }
    if (!_isMeaningCorrect()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('오답 😅  정답: ${_cur.meaning}')));
      return;
    }
    final comp = _compCtrl.text.trim();
    if (comp.isNotEmpty) {
      final issues = _validateComposition(comp, _cur.word);
      if (issues.isNotEmpty) {
        await showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
          builder: (_) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('작문을 조금만 고쳐볼까요?',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...issues.map((e) => Row(
                      children: [const Text('• '), Expanded(child: Text(e))])),
                  const SizedBox(height: 8),
                  Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('닫기'))),
                ]),
          ),
        );
        return;
      }
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('정답! 🎉')));
    _nextQuiz();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F0E9),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF6F0E9),
          elevation: 0,
          title: const Text('단어장', style: TextStyle(color: Colors.black87)),
          iconTheme: const IconThemeData(color: Colors.black87),
          bottom: const TabBar(
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.black45,
            indicatorColor: Color(0xFF4E6E99),
            tabs: [Tab(text: '내 단어'), Tab(text: '즐겨찾기'), Tab(text: '퀴즈')],
          ),
        ),
        body: Stack(
          children: [
            TabBarView(children: [
              _buildListView(_items),
              _buildListView(_items.where((e) => e.favorite).toList()),
              _buildQuizTab(),
            ]),
            if (_uploading)
              Positioned.fill(
                child: Container(
                    color: Colors.black.withOpacity(0.15),
                    child: const Center(child: CircularProgressIndicator())),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF4E6E99),
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: _openImageSourceSheet,
        ),
      ),
    );
  }

  Future<void> _openImageSourceSheet() async {
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    if (kIsWeb || isDesktop) {
      final res = await FilePicker.platform.pickFiles(
          type: FileType.image, allowMultiple: false, withData: true);
      if (res == null || res.files.isEmpty) return;
      final f = res.files.single;
      final bytes = f.bytes ??
          (f.path != null ? await File(f.path!).readAsBytes() : null);
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('이미지를 불러오지 못했습니다.')));
        return;
      }
      await _uploadFlow(bytes, f.name);
      return;
    }

    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('사진 촬영'),
              onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('앨범에서 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      ),
    );
    if (src == null) return;

    final x = await _imagePicker.pickImage(
        source: src, imageQuality: 85, maxWidth: 1600);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    await _uploadFlow(bytes, x.name);
  }

  /// 업로드 → OCR 단어 → 1차 검토 → 정의 조회 → 2차 검토 → 단어장 반영
  Future<void> _uploadFlow(Uint8List bytes, String filename) async {
    setState(() => _uploading = true);
    try {
      if (bytes.lengthInBytes > 8 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미지 크기가 너무 큽니다(최대 8MB).')));
        return;
      }

      // 1) 업로드 + OCR
      final words = await DjangoApi.uploadAndExtract(
        bytes: bytes,
        filename: filename,
        h: _hsvValues['h']!,
        s: _hsvValues['s']!,
        v: _hsvValues['v']!,
      );
      if (words.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('인식된 단어가 없습니다.')));
        return;
      }

      // 2) 1차 검토/수정
      final edited = await showReviewWordsSheet(context, initialWords: words);
      if (edited == null || edited.isEmpty) return;

      // 3) 정의 조회 (백엔드 → ChatGPT)
      List<DefinitionItem> defs;
      try {
        defs = await DjangoApi.defineWords(edited);
      } catch (_) {
        // 실패 시 수동 입력 모드
        defs = edited
            .map((w) =>
                DefinitionItem(word: w, meaning: '', pos: '', example: ''))
            .toList();
      }

      // 4) 2차 검토(뜻/품사/예문 수정) → 단어장 반영
      final confirmed = await showReviewMeaningsSheet(context, defs: defs);
      if (confirmed == null || confirmed.isEmpty) return;

      setState(() {
        final exist = _items.map((e) => e.word.toLowerCase()).toSet();
        for (final m in confirmed) {
          final w = (m['word'] ?? '').trim();
          final mean = (m['meaning'] ?? '').trim();
          if (w.isEmpty) continue;
          if (exist.add(w.toLowerCase())) {
            _items.add(WordItem(word: w, meaning: mean));
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('단어장에 ${confirmed.length}개 추가')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('오류: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _buildListView(List<WordItem> data) {
    if (data.isEmpty) return const Center(child: Text('아직 단어가 없습니다.'));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final it = data[i];
        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            title: Text(it.word,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            subtitle:
                Text(it.meaning, style: const TextStyle(color: Colors.black54)),
            trailing: IconButton(
              icon: Icon(it.favorite ? Icons.star : Icons.star_border,
                  color: Colors.amber[700]),
              onPressed: () => setState(() => it.favorite = !it.favorite),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuizTab() {
    if (_items.isEmpty)
      return const Center(child: Text('퀴즈를 위해 최소 1개 이상의 단어가 필요합니다.'));
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Center(
            child: Text(_cur.word,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 56, fontWeight: FontWeight.w800)),
          ),
        ),
        TextField(
          controller: _meanCtrl,
          focusNode: _meanFocus,
          maxLines: 1,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _confirmQuiz(),
          decoration: InputDecoration(
            labelText: '뜻(필수)',
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _compCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: '작문 (선택: 단어 포함, 4단어↑ 권장)',
            hintText: '예) I can easily use this word in a sentence.',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4E6E99),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _confirmQuiz,
            child: const Text('확인',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                )),
          ),
        ),
      ]),
    );
  }
}
