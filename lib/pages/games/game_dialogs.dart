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
