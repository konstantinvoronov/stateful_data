import 'package:flutter/material.dart';
import 'package:stateful_data_example/quote_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'stateful_data example app',
      home: const QuoteScreen(),
    );
  }
}