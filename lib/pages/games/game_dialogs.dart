import 'package:flutter/material.dart';

Future<void> showPauseDialog({
  required BuildContext context,
  DateTime? pauseStart,
  required VoidCallback onResume,
  required VoidCallback onExit,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 350,
        height: 350,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/dialog1.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "일시정지",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "게임을 계속하시겠습니까?",
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 35),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onResume();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFCC8C8),
                          foregroundColor: Colors.black,
                          minimumSize: const Size(80, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(0),
                            side:
                                const BorderSide(color: Colors.black, width: 2),
                          ),
                        ),
                        child: const Text('계속하기'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onExit();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4E6E99),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(80, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(0),
                            side:
                                const BorderSide(color: Colors.black, width: 2),
                          ),
                        ),
                        child: const Text('종료'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showGameOverDialog_game6({
  required BuildContext context,
  bool success = false,
  required int towerHeight,
  required VoidCallback onConfirm,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 350,
        height: 350,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/dialog2.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                success ? "게임 성공!" : "게임 종료",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                success
                    ? "축하합니다! 시간을 버티고 탑을 완성했습니다.\n총 쌓인 블록: $towerHeight"
                    : "총 쌓인 블록: $towerHeight",
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 35),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onConfirm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: success
                      ? const Color(0xFF4E6E99)
                      : const Color(0xFFFCC8C8),
                  foregroundColor: success ? Colors.white : Colors.black,
                  minimumSize: const Size(120, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                    side: const BorderSide(color: Colors.black, width: 2),
                  ),
                ),
                child: const Text('확인'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
