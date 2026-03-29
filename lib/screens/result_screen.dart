import 'package:flutter/material.dart';
import '../models/produce_result.dart';
import '../services/location_service.dart';

class ResultScreen extends StatelessWidget {
  final ProduceResult produceResult;
  final LocationResult locationResult;

  const ResultScreen({super.key, required this.produceResult, required this.locationResult});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis Results')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('Produce: ${produceResult.nameEnglish} / ${produceResult.nameKannada}'),
            Text('Confidence: ${(produceResult.confidence * 100).toStringAsFixed(1)}%'),
            Text('District: ${locationResult.district}'),
            const Divider(),
            Text('Fair Price: ₹${produceResult.priceFairPerKg}/kg'),
            Text('Range: ₹${produceResult.priceMinPerKg} - ₹${produceResult.priceMaxPerKg}'),
            Text('Reasoning: ${produceResult.priceReasoning}'),
          ],
        ),
      ),
    );
  }
}
