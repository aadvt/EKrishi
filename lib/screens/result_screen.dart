import 'package:flutter/material.dart';
import '../services/produce_service.dart';
import '../services/location_service.dart';

class ResultScreen extends StatelessWidget {
  final ProduceResult produceResult;
  final LocationResult locationResult;

  const ResultScreen({super.key, required this.produceResult, required this.locationResult});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis Results')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Identify: ${produceResult.name} (${produceResult.confidence}%)'),
            Text('Location: ${locationResult.address}'),
          ],
        ),
      ),
    );
  }
}
