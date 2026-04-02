import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/tflite_result.dart';

class TfliteService {
  static final TfliteService _instance = TfliteService._internal();
  factory TfliteService() => _instance;
  TfliteService._internal();

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<void> loadModel() async {
    try {
      _interpreter ??= await Interpreter.fromAsset(
        'assets/ml/crop_model.tflite',
      );

      final labelsData = await rootBundle.loadString(
        'assets/ml/crop_labels.txt',
      );
      _labels = labelsData
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      _isLoaded = true;
      debugPrint('TFLite model loaded: ${_labels.length} classes');
    } catch (e) {
      _isLoaded = false;
      debugPrint('Error loading TFLite model: $e');
    }
  }

  Future<TfliteResult?> classifyImage(File imageFile) async {
    if (!_isLoaded || _interpreter == null) {
      return null;
    }

    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        return null;
      }

      image = img.copyResize(image, width: 224, height: 224);

      // Get the actual input shape the model expects.
      final inputShape = _interpreter!.getInputTensor(0).shape;
      // inputShape is something like [1, 3, 224, 224] (NCHW)
      // or [1, 224, 224, 3] (NHWC)
      final bool isNCHW = inputShape.length == 4 && inputShape[1] == 3;
      // ignore: avoid_print
      print('TFLite input shape: $inputShape (${isNCHW ? "NCHW" : "NHWC"})');

      Float32List inputBuffer;

      if (isNCHW) {
        // Model expects [1, 3, 224, 224]
        // Build as: [batch][channel][height][width]
        inputBuffer = Float32List(1 * 3 * 224 * 224);

        for (int c = 0; c < 3; c++) {
          // Mean and std per channel (RGB order)
          // R=0: mean 0.485, std 0.229
          // G=1: mean 0.456, std 0.224
          // B=2: mean 0.406, std 0.225
          const means = [0.485, 0.456, 0.406];
          const stds = [0.229, 0.224, 0.225];

          for (int y = 0; y < 224; y++) {
            for (int x = 0; x < 224; x++) {
              final pixel = image.getPixel(x, y);
              double value;
              if (c == 0) {
                value = (pixel.r / 255.0 - means[0]) / stds[0];
              } else if (c == 1) {
                value = (pixel.g / 255.0 - means[1]) / stds[1];
              } else {
                value = (pixel.b / 255.0 - means[2]) / stds[2];
              }
              // Index: c * 224 * 224 + y * 224 + x
              inputBuffer[c * 224 * 224 + y * 224 + x] = value;
            }
          }
        }
      } else {
        // Model expects [1, 224, 224, 3] - standard NHWC
        inputBuffer = Float32List(1 * 224 * 224 * 3);
        int idx = 0;
        const means = [0.485, 0.456, 0.406];
        const stds = [0.229, 0.224, 0.225];

        for (int y = 0; y < 224; y++) {
          for (int x = 0; x < 224; x++) {
            final pixel = image.getPixel(x, y);
            inputBuffer[idx++] = (pixel.r / 255.0 - means[0]) / stds[0];
            inputBuffer[idx++] = (pixel.g / 255.0 - means[1]) / stds[1];
            inputBuffer[idx++] = (pixel.b / 255.0 - means[2]) / stds[2];
          }
        }
      }

      // Reshape correctly based on format
      final input = isNCHW
          ? inputBuffer.reshape([1, 3, 224, 224])
          : inputBuffer.reshape([1, 224, 224, 3]);
      final outputShape = _interpreter!.getOutputTensor(0).shape;
        // ignore: avoid_print
      print('TFLite output shape: $outputShape');
      final output = List.filled(
        outputShape[1],
        0.0,
      ).reshape([1, outputShape[1]]);

      _interpreter!.run(input, output);

      final scores = List<double>.from(output[0]);
      final maxScore = scores.reduce((a, b) => a > b ? a : b);
      final expScores = scores.map((s) => math.exp(s - maxScore)).toList();
      final sumExp = expScores.reduce((a, b) => a + b);
      final probabilities = expScores.map((e) => e / sumExp).toList();

      int topIdx = 0;
      double topScore = 0.0;
      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > topScore) {
          topScore = probabilities[i];
          topIdx = i;
        }
      }

      final label = topIdx < _labels.length ? _labels[topIdx] : 'unknown';
      return TfliteResult(label: label, confidence: topScore);
    } catch (e) {
      debugPrint('Error classifying image: $e');
      return null;
    }
  }

  Future<List<TfliteResult>> getTopResults(
    File imageFile, {
    int topK = 3,
  }) async {
    if (!_isLoaded || _interpreter == null || topK <= 0) {
      return [];
    }

    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        return [];
      }

      image = img.copyResize(image, width: 224, height: 224);

      final inputBuffer = Float32List(1 * 224 * 224 * 3);
      int idx = 0;

      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = image.getPixel(x, y);
          inputBuffer[idx++] = (pixel.r / 255.0 - 0.485) / 0.229;
          inputBuffer[idx++] = (pixel.g / 255.0 - 0.456) / 0.224;
          inputBuffer[idx++] = (pixel.b / 255.0 - 0.406) / 0.225;
        }
      }

      final input = inputBuffer.reshape([1, 224, 224, 3]);
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final output = List.filled(
        outputShape[1],
        0.0,
      ).reshape([1, outputShape[1]]);

      _interpreter!.run(input, output);

      final scores = List<double>.from(output[0]);
      final maxScore = scores.reduce((a, b) => a > b ? a : b);
      final expScores = scores.map((s) => math.exp(s - maxScore)).toList();
      final sumExp = expScores.reduce((a, b) => a + b);
      final probabilities = expScores.map((e) => e / sumExp).toList();

      final indexed = List.generate(
        probabilities.length,
        (i) => MapEntry(i, probabilities[i]),
      )..sort((a, b) => b.value.compareTo(a.value));

      final count = math.min(topK, indexed.length);
      final results = <TfliteResult>[];

      for (int i = 0; i < count; i++) {
        final entry = indexed[i];
        final label = entry.key < _labels.length
            ? _labels[entry.key]
            : 'unknown';
        results.add(TfliteResult(label: label, confidence: entry.value));
      }

      return results;
    } catch (e) {
      debugPrint('Error getting top results: $e');
      return [];
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
