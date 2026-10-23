import 'package:flutter/material.dart';

class TrainerScreen extends StatelessWidget {
  const TrainerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Шпаргалка от Феи')),
      body: const Center(
        child: Text('Здесь скоро появится шпаргалка!', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}