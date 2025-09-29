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

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WordMenuPage extends StatefulWidget {
  final int? wordbookId;

  const WordMenuPage({Key? key, this.wordbookId}) : super(key: key);

  @override
  State<WordMenuPage> createState() => _WordMenuPageState();
}

class WordItem {
  final int personalWordbookWordId; // 고유 ID
  String word; // 영단어
  String wordKr; // 한글 뜻 (백엔드와 일치)
  String meaning; // 뜻 (현재 코드에서는 wordKr과 동일하게 사용)
  bool favorite;

  WordItem({
    required this.personalWordbookWordId,
    required this.word,
    required this.wordKr,
    required this.meaning,
    this.favorite = false,
  });
}

class _WordMenuPageState extends State<WordMenuPage> {
  List<WordItem> _items = [];
  Map<String, int> _hsvValues = {'h': 120, 's': 255, 'v': 255};

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
    if (widget.wordbookId != null) {
      _fetchWords();
    }
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
    if (!t.toLowerCase().contains(target.toLowerCase())) {
      out.add('문장에 "$target" 단어가 포함되어야 해요.');
    }
    if (t.split(RegExp(r'\s+')).length < 4) {
      out.add('문장은 4단어 이상으로 작성해 주세요.');
    }
    if (!RegExp(r'[.!?]$').hasMatch(t)) {
      out.add('문장 끝에 마침표/물음표를 붙이면 더 좋아요.');
    }
    return out;
  }

  Future<void> _fetchWords() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final url = Uri.parse(
        'http://localhost:8080/api/v1/words/wordbook/${widget.wordbookId}');

    try {
      final res = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        // 서버 응답 구조에 맞게 변환
        final words = (data['words'] as List)
            .map((w) => WordItem(
                  personalWordbookWordId: w['personalWordbookWordId'], // 서버 ID
                  word: w['wordEn'],
                  wordKr: w['wordKr'],
                  meaning: w['meaning'],
                ))
            .toList();

        setState(() => _items = words);
        if (_items.isNotEmpty) _nextQuiz();
      } else if (res.statusCode == 400 || res.statusCode == 404) {
        final msg = jsonDecode(res.body)['message'] ?? '단어장 조회 실패';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('서버 오류')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
    }
  }

  Future<int?> _addWordToServer({
    required String wordEn,
    required String wordKr,
    required String meaning,
    int? personalWordbookId,
  }) async {
    final url = Uri.parse('http://localhost:8080/api/v1/words');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final body = jsonEncode({
      'wordEn': wordEn,
      'wordKr': wordKr,
      'meaning': meaning,
      'personalWordbookId': personalWordbookId,
    });

    try {
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (res.statusCode == 200) {
        await _fetchWords();
        final data = jsonDecode(res.body);
        return data['personalWordbookWordId'];
      } else {
        final msg = jsonDecode(res.body)['message'] ?? '오류';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
        return null;
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
      return null;
    }
  }

  Future<void> _showEditMenu(WordItem it) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('수정'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
          ],
        ),
      ),
    );

    if (choice == 'delete') {
      await _confirmDelete(it);
    } else if (choice == 'edit') {
      await _openEditDialog(it);
    }
  }

  Future<void> _openEditDialog(WordItem it) async {
    final enCtrl = TextEditingController(text: it.word);
    final meanCtrl = TextEditingController(text: it.meaning);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('단어 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: enCtrl,
              decoration: const InputDecoration(labelText: '영단어'),
            ),
            TextField(
              controller: meanCtrl,
              decoration: const InputDecoration(labelText: '뜻'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    // ✅ 서버에 수정 요청
    final success = await _updateWordOnServer(
      personalWordbookWordId: it.personalWordbookWordId,
      wordEn: enCtrl.text.trim(),
      wordKr: meanCtrl.text.trim(),
      meaning: meanCtrl.text.trim(),
    );

    // ✅ 서버 요청이 성공했을 때만 로컬 상태 업데이트
    if (success) {
      final idx = _items.indexWhere(
          (e) => e.personalWordbookWordId == it.personalWordbookWordId);
      if (idx >= 0) {
        setState(() {
          _items[idx] = WordItem(
            personalWordbookWordId: it.personalWordbookWordId,
            word: enCtrl.text.trim(),
            wordKr: meanCtrl.text.trim(),
            meaning: meanCtrl.text.trim(),
            favorite: it.favorite,
          );
        });
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"${enCtrl.text.trim()}" 수정됨')));
    }
  }

  Future<bool> _updateWordOnServer({
    required int personalWordbookWordId,
    required String wordEn,
    required String wordKr,
    required String meaning,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final url = Uri.parse('http://localhost:8080/api/v1/words');

    final body = jsonEncode({
      'personalWordbookWordId': personalWordbookWordId,
      'wordEn': wordEn,
      'wordKr': wordKr,
      'meaning': meaning,
    });

    try {
      final res = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (res.statusCode == 200) {
        return true;
      } else {
        final msg = jsonDecode(res.body)['message'] ?? '수정 실패';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오류: $msg')));
        return false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
      return false;
    }
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
              ],
            ),
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
            TabBarView(
              children: [
                _buildListView(_items),
                _buildListView(_items.where((e) => e.favorite).toList()),
                _buildQuizTab(_items),
              ],
            ),
            if (_uploading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.15),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF4E6E99),
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: _openAddMenu, // 수동 추가/이미지 추가 선택
        ),
      ),
    );
  }

  Future<void> _openAddMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.keyboard),
            title: const Text('직접 추가 (영단어/뜻 입력)'),
            onTap: () => Navigator.pop(context, 'manual'),
          ),
          ListTile(
            leading: const Icon(Icons.image_search),
            title: const Text('이미지로 추가 (형광펜 인식)'),
            onTap: () => Navigator.pop(context, 'image'),
          ),
        ]),
      ),
    );

    if (choice == 'manual') {
      await _openAddDialog();
    } else if (choice == 'image') {
      await _openImageSourceSheet();
    }
  }

  Future<void> _openAddDialog() async {
    final en = TextEditingController();
    final ko = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('단어 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: en,
                decoration: const InputDecoration(labelText: '영단어'),
                textInputAction: TextInputAction.next),
            TextField(
                controller: ko,
                decoration: const InputDecoration(labelText: '뜻')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('추가')),
        ],
      ),
    );

    if (ok != true) return;
    final w = en.text.trim();
    final m = ko.text.trim();
    if (w.isEmpty || m.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('영단어와 뜻을 모두 입력하세요.')));
      return;
    }

    final serverWordId = await _addWordToServer(
      wordEn: w,
      wordKr: m,
      meaning: m,
      personalWordbookId: widget.wordbookId,
    );

    if (serverWordId == null) return; // 서버 추가 실패 시 종료

    setState(() {
      _items.insert(
        0,
        WordItem(
          personalWordbookWordId: serverWordId,
          word: w,
          wordKr: m,
          meaning: m,
        ),
      );
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('"$w" 추가됨')));
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

  Future<void> _uploadFlow(Uint8List bytes, String filename) async {
    setState(() => _uploading = true);
    try {
      if (bytes.lengthInBytes > 8 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미지 크기가 너무 큽니다(최대 8MB).')));
        return;
      }

      // 1️⃣ 이미지에서 단어 추출
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

      // 2️⃣ 단어 확인/편집
      final edited = await showReviewWordsSheet(context, initialWords: words);
      if (edited == null || edited.isEmpty) return;

      // 3️⃣ 의미 정의
      List<DefinitionItem> defs;
      try {
        defs = await DjangoApi.defineWords(edited);
      } catch (_) {
        defs = edited
            .map((w) =>
                DefinitionItem(word: w, meaning: '', pos: '', example: ''))
            .toList();
      }

      final confirmed = await showReviewMeaningsSheet(context, defs: defs);
      if (confirmed == null || confirmed.isEmpty) return;

      // 4️⃣ 서버(DB) 저장 + 로컬 리스트 반영
      final exist = _items.map((e) => e.word.toLowerCase()).toSet();
      int addedCount = 0;

      for (final m in confirmed) {
        final w = (m['word'] ?? '').trim();
        final mean = (m['meaning'] ?? '').trim();
        if (w.isEmpty) continue;

        // 이미 없는 단어만 처리
        if (exist.add(w.toLowerCase())) {
          final serverWordId = await _addWordToServer(
            wordEn: w,
            wordKr: mean,
            meaning: mean,
            personalWordbookId: widget.wordbookId,
          );

          if (serverWordId != null) {
            setState(() {
              _items.insert(
                0,
                WordItem(
                  personalWordbookWordId: serverWordId,
                  word: w,
                  wordKr: mean,
                  meaning: mean,
                ),
              );
            });
            addedCount++;
          }
        }
      }

      if (addedCount > 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('단어장에 $addedCount개 추가됨')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('오류: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // === 여기부터 삭제(X 버튼) 관련 헬퍼 ===
  Future<void> _confirmDelete(WordItem it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제하시겠어요?'),
        content: Text('${it.word} - ${it.meaning}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제')),
        ],
      ),
    );

    if (ok == true) {
      final success = await _deleteWordFromServer(it.personalWordbookWordId);
      if (success) _removeItemById(it.personalWordbookWordId);
    }
  }

  void _removeItemById(int personalWordbookWordId) {
    final idx = _items
        .indexWhere((e) => e.personalWordbookWordId == personalWordbookWordId);
    if (idx >= 0) setState(() => _items.removeAt(idx));
  }

  Future<bool> _deleteWordFromServer(int personalWordbookWordId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final url =
        Uri.parse('http://localhost:8080/api/v1/words/$personalWordbookWordId');

    try {
      final res = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) return true;

      final msg = jsonDecode(res.body)['message'] ?? '삭제 실패';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('오류: $msg')));
      return false;
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
      return false;
    }
  }

  void _removeByWord(String word) {
    final idx =
        _items.indexWhere((e) => e.word.toLowerCase() == word.toLowerCase());
    if (idx >= 0) {
      setState(() => _items.removeAt(idx));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"$word" 삭제됨')));
    }
  }
  // === 삭제 헬퍼 끝 ===

  /// 리스트(내 단어/즐겨찾기) — 카드 내부 우측 상단 X 버튼
  Widget _buildListView(List<WordItem> data) {
    if (data.isEmpty) {
      return const Center(
        child: Text('단어가 없습니다',
            style: TextStyle(fontSize: 16, color: Colors.black54)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final it = data[i];

        return Stack(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 2,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                title: Text(it.word,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                subtitle: Text(it.meaning,
                    style: const TextStyle(color: Colors.black54)),
                trailing: IconButton(
                  icon: Icon(it.favorite ? Icons.star : Icons.star_border,
                      color: Colors.amber[700]),
                  onPressed: () => setState(() => it.favorite = !it.favorite),
                ),
                onTap: () => _showEditMenu(it),
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.black54),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _confirmDelete(it),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuizTab(List<WordItem> words) {
    if (words.isEmpty) {
      return const Center(
        child: Text('단어가 없습니다',
            style: TextStyle(fontSize: 16, color: Colors.black54)),
      );
    }

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
                    color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}
