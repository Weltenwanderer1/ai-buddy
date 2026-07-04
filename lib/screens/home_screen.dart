import 'package:flutter/material.dart';
import 'chat_screen.dart';

/// HomeScreen ohne Bottom Navigation — nur Chat mit Zugriff über
/// das Top-Menü.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: ChatScreen(),
      resizeToAvoidBottomInset: true,
    );
  }
}
