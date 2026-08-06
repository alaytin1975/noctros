import 'dart:math' as math;
import 'dart:typed_data';

/// Extracts a compact speaker feature vector from PCM16 mono audio.
///
/// Features: RMS energy stats, zero-crossing rate, estimated pitch, spectral
/// centroid proxy, and duration. Used for on-device Voice ID (no cloud upload).
class VoiceFeatureExtractor {
  const VoiceFeatureExtractor();

  static const featureSize = 16;

  List<double> extractFromPcm16(Uint8List bytes, {int sampleRate = 16000}) {
    if (bytes.length < 4) {
      return List<double>.filled(featureSize, 0);
    }

    final sampleCount = bytes.length ~/ 2;
    final samples = Float64List(sampleCount);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < sampleCount; i++) {
      samples[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }

    final rms = _rms(samples);
    final peak = samples.fold<double>(0, (max, s) => math.max(max, s.abs()));
    final zcr = _zeroCrossingRate(samples);
    final pitch = _estimatePitch(samples, sampleRate);
    final centroid = _spectralCentroidProxy(samples);
    final duration = sampleCount / sampleRate;
    final energyVariance = _energyVariance(samples);

    final raw = <double>[
      rms,
      peak,
      zcr,
      pitch / 500.0,
      centroid,
      duration / 5.0,
      energyVariance,
      _percentileAbs(samples, 0.25),
      _percentileAbs(samples, 0.5),
      _percentileAbs(samples, 0.75),
      _percentileAbs(samples, 0.9),
      _frameEnergyMean(samples, 256),
      _frameEnergyMean(samples, 512),
      _frameEnergyMean(samples, 1024),
      math.log(1 + sampleCount.toDouble()) / 12.0,
      (pitch > 0 && pitch < 280) ? 1.0 : 0.0,
    ];

    return _normalize(raw);
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) {
      return 0;
    }
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) {
      return 0;
    }
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  List<double> averageVectors(List<List<double>> vectors) {
    if (vectors.isEmpty) {
      return List<double>.filled(featureSize, 0);
    }
    final size = vectors.first.length;
    final sum = List<double>.filled(size, 0);
    for (final vector in vectors) {
      for (var i = 0; i < size; i++) {
        sum[i] += vector[i];
      }
    }
    return sum.map((value) => value / vectors.length).toList();
  }

  double _rms(Float64List samples) {
    if (samples.isEmpty) {
      return 0;
    }
    var sum = 0.0;
    for (final sample in samples) {
      sum += sample * sample;
    }
    return math.sqrt(sum / samples.length);
  }

  double _zeroCrossingRate(Float64List samples) {
    if (samples.length < 2) {
      return 0;
    }
    var crossings = 0;
    for (var i = 1; i < samples.length; i++) {
      if ((samples[i - 1] >= 0 && samples[i] < 0) ||
          (samples[i - 1] < 0 && samples[i] >= 0)) {
        crossings++;
      }
    }
    return crossings / (samples.length - 1);
  }

  double _estimatePitch(Float64List samples, int sampleRate) {
    if (samples.length < sampleRate ~/ 40) {
      return 0;
    }
    final minLag = sampleRate ~/ 400; // 400 Hz
    final maxLag = sampleRate ~/ 80; // 80 Hz
    if (maxLag >= samples.length) {
      return 0;
    }

    var bestLag = 0;
    var bestCorr = 0.0;
    for (var lag = minLag; lag <= maxLag; lag++) {
      var corr = 0.0;
      final limit = samples.length - lag;
      for (var i = 0; i < limit; i += 4) {
        corr += samples[i] * samples[i + lag];
      }
      if (corr > bestCorr) {
        bestCorr = corr;
        bestLag = lag;
      }
    }
    if (bestLag == 0) {
      return 0;
    }
    return sampleRate / bestLag;
  }

  double _spectralCentroidProxy(Float64List samples) {
    if (samples.isEmpty) {
      return 0;
    }
    var weighted = 0.0;
    var total = 0.0;
    final step = math.max(1, samples.length ~/ 512);
    for (var i = 0; i < samples.length; i += step) {
      final mag = samples[i].abs();
      weighted += i * mag;
      total += mag;
    }
    if (total == 0) {
      return 0;
    }
    return (weighted / total) / samples.length;
  }

  double _energyVariance(Float64List samples) {
    final mean = _rms(samples);
    var sum = 0.0;
    final step = math.max(1, samples.length ~/ 256);
    var count = 0;
    for (var i = 0; i < samples.length; i += step) {
      final d = samples[i].abs() - mean;
      sum += d * d;
      count++;
    }
    return count == 0 ? 0 : sum / count;
  }

  double _percentileAbs(Float64List samples, double percentile) {
    if (samples.isEmpty) {
      return 0;
    }
    final values = samples.map((s) => s.abs()).toList()..sort();
    final index =
        (percentile * (values.length - 1)).clamp(0, values.length - 1).round();
    return values[index];
  }

  double _frameEnergyMean(Float64List samples, int frameSize) {
    if (samples.length < frameSize) {
      return _rms(samples);
    }
    var total = 0.0;
    var frames = 0;
    for (var i = 0; i + frameSize < samples.length; i += frameSize) {
      var sum = 0.0;
      for (var j = 0; j < frameSize; j++) {
        sum += samples[i + j] * samples[i + j];
      }
      total += math.sqrt(sum / frameSize);
      frames++;
    }
    return frames == 0 ? 0 : total / frames;
  }

  List<double> _normalize(List<double> input) {
    final maxAbs = input.fold<double>(0, (m, v) => math.max(m, v.abs()));
    if (maxAbs == 0) {
      return input;
    }
    return input.map((value) => value / maxAbs).toList();
  }
}
