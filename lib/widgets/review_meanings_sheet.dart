import 'package:flutter/material.dart';
import '../models/definition_item.dart';

/// ChatGPT 뜻 채운 결과를 최종 확인/수정하여 단어장에 넣는 모달
/// 반환: [{word, meaning}] 리스트
Future<List<Map<String, String>>?> showReviewMeaningsSheet(
  BuildContext ctx, {
  required List<DefinitionItem> defs,
}) async {
  final ctrls = defs
      .map((m) => {
            'word': TextEditingController(text: m.word),
            'meaning': TextEditingController(text: m.meaning),
            'pos': TextEditingController(text: m.pos),
            'example': TextEditingController(text: m.example),
          })
      .toList();

  return showModalBottomSheet<List<Map<String, String>>>(
    context: ctx,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (context, setStateModal) {
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('뜻을 확인/수정하세요',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: ctrls.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final c = ctrls[i];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              Expanded(
                                child: TextField(
                                  controller: c['word'],
                                  decoration: const InputDecoration(
                                    isDense: true, border: OutlineInputBorder(), labelText: '단어',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setStateModal(() => ctrls.removeAt(i)),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            TextField(
                              controller: c['meaning'],
                              decoration: const InputDecoration(
                                isDense: true, border: OutlineInputBorder(), labelText: '뜻(한국어)',
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: c['pos'],
                              decoration: const InputDecoration(
                                isDense: true, border: OutlineInputBorder(), labelText: '품사(선택)',
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: c['example'],
                              decoration: const InputDecoration(
                                isDense: true, border: OutlineInputBorder(), labelText: '예문(선택, 영어)',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    OutlinedButton.icon(
                      onPressed: () => setStateModal(() => ctrls.add({
                        'word': TextEditingController(),
                        'meaning': TextEditingController(),
                        'pos': TextEditingController(),
                        'example': TextEditingController(),
                      })),
                      icon: const Icon(Icons.add),
                      label: const Text('행 추가'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4E6E99)),
                      onPressed: () {
                        final result = <Map<String, String>>[];
                        for (final c in ctrls) {
                          final w = c['word']!.text.trim();
                          final m = c['meaning']!.text.trim();
                          if (w.isEmpty) continue;
                          result.add({'word': w, 'meaning': m});
                        }
                        Navigator.pop(context, result);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('추가'),
                    ),
                  ]),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
