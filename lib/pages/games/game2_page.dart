import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class Game2 extends FlameGame {
  @override
  Future<void> onLoad() async {
    super.onLoad();
    // 게임 초기화, 이미지/스프라이트 불러오기 등
  }

  @override
  void update(double dt) {
    // 게임 로직 업데이트
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    // 화면에 그리기
    super.render(canvas);
  }
}

class Game2Page extends StatelessWidget {
  const Game2Page({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("게임 2")),
      body: GameWidget(game: Game2()), // FlameGame 위젯
    );
  }
}
