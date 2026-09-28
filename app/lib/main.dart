import 'package:flutter/material.dart';

import 'game_controller.dart';
import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = GameController();
  await controller.loadSavedServer();
  runApp(WorstAnswerApp(controller: controller));
}

class WorstAnswerApp extends StatelessWidget {
  const WorstAnswerApp({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Worst Answer Wins',
      debugShowCheckedModeBanner: false,
      theme: buildPartyTheme(),
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.room == null) {
            return HomeScreen(controller: controller);
          }
          return GameScreen(controller: controller);
        },
      ),
    );
  }
}
