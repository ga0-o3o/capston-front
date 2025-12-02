import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 단어장 추가/수정용 다이얼로그
Future<String?> showWordbookNameDialog(BuildContext context,
    {String? initial}) async {
  final controller = TextEditingController(text: initial ?? "");
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 330,
        height: 330,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/dialog1.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              initial == null ? '새 단어장 추가' : '단어장 이름 수정',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLength: 12,
              maxLengthEnforcement:
                  MaxLengthEnforcement.enforced, // ★ 실제로 입력 차단
              decoration: const InputDecoration(
                counterText: "",
                labelText: '단어장 이름',
                filled: true,
                fillColor: Colors.white70,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFCC8C8),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(100, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  child: const Text('취소'),
                ),

                // ✅ 검증 포함된 "추가/수정" 버튼 (딱 하나만)
                ElevatedButton(
                  onPressed: () {
                    final text = controller.text.trim();

                    if (text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("단어장 이름을 입력해주세요.")),
                      );
                      return;
                    }

                    if (text.length > 12) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("단어장 이름은 12자 이내로 입력해주세요.")),
                      );
                      return;
                    }

                    Navigator.pop(context, true); // ← 검증 통과 후 OK
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E6E99),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(100, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  child: Text(initial == null ? '추가' : '수정'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  if (ok != true) return null;
  return controller.text.trim();
}

// 단어장 삭제 확인용 다이얼로그
Future<bool> showDeleteWordbookDialog(
    BuildContext context, String title) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 330,
        height: 330,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/dialog1.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '"$title" 단어장을 \n삭제하시겠습니까?',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFCC8C8),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(80, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E6E99),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(80, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  child: const Text('삭제'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  return ok == true;
}
