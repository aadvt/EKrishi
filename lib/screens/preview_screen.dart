import 'dart:io';
import 'package:flutter/material.dart';

class PreviewScreen extends StatelessWidget {
  final File imageFile;

  const PreviewScreen({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: Center(
        child: Column(
          children: [
            Expanded(child: Image.file(imageFile)),
            const SizedBox(height: 16),
            const Text('Placeholder for Analysis Logic'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
