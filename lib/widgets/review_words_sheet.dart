import 'package:flutter/material.dart';

/// OCR로 추출된 단어 리스트를 검토/수정/삭제/추가할 수 있는 모달
Future<List<String>?> showReviewWordsSheet(
  BuildContext ctx, {
  required List<String> initialWords,
}) async {
  final controllers = initialWords.map((w) => TextEditingController(text: w)).toList();

  return showModalBottomSheet<List<String>>(
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
              height: MediaQuery.of(ctx).size.height * 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('추출된 단어를 확인/수정하세요',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: controllers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controllers[i],
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                                hintText: '단어',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setStateModal(() => controllers.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setStateModal(() => controllers.add(TextEditingController())),
                        icon: const Icon(Icons.add),
                        label: const Text('행 추가'),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4E6E99)),
                        onPressed: () {
                          final result = controllers
                              .map((c) => c.text.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                          Navigator.pop(context, result);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('확인'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
