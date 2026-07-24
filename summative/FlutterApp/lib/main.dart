import 'package:flutter/material.dart';
import 'prediction_screen.dart';
import 'theme.dart';

void main() {
  runApp(const TerraPredictApp());
}

class TerraPredictApp extends StatelessWidget {
  const TerraPredictApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TerraPredict',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const PredictionScreen(),
    );
  }
}