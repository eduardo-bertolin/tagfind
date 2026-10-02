import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';

/// Converte RSSI (dBm) em distância estimada (m) e suaviza o sinal ao longo do tempo.
///
/// Modelo de path-loss log-distance (efeito inverso do quadrado, com
/// atenuação por meio):
///
///   d = 10 ^ ((A - RSSI) / (10 * n))
///
///   A : RSSI de referência medido a 1 m (por padrão, calibrado para o
///       TX power +9 dBm do firmware; pode ser recalibrado pelo usuário).
///   n : expoente de path-loss (2.0 livre, ~2.5–3.0 em ambiente interno).
///
/// **Limitações (importantes):** uma única antena + RSSI **não** fornece
/// posição exata — só a distância radial em torno do receptor. A precisão
/// típica em ambiente interno é de ±1–3 m. Para localização "exata" (meteria
/// menor que 1 m com direção) seria necessário múltiplos receptores
/// (trilateração) ou UWB. Este serviço entrega o melhor esforço com 1 receptor,
/// suavizando o ruído do RSSI e oferecendo calibração por usuário.
class DistanceEstimator {
  DistanceEstimator._();
  static final DistanceEstimator instance = DistanceEstimator._();

  SharedPreferences? _prefs;

  // Histórico de leituras por tag para suavização e detecção de tendência.
  static const int _windowSize = 12; // últimas N amostras de RSSI
  final Map<String, List<int>> _rssiHistory = {};

  // Médias suavizadas (EWMA) por tag.
  final Map<String, double> _smoothedRssi = {};

  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// RSSI de referência a 1 m: calibrado pelo usuário (por tag) ou o default.
  Future<double> _refRssiAt1m(String tagId) async {
    await _ensurePrefs();
    final key = 'ref_rssi_1m_$tagId';
    final calibrated = _prefs?.getDouble(key);
    if (calibrated != null) return calibrated;
    return AppConstants.bleRefRssiAt1m;
  }

  /// Converte um RSSI instantâneo em distância (m), com clamps.
  static double rssiToDistance(double rssi, {double? refRssiAt1m}) {
    final ref = refRssiAt1m ?? AppConstants.bleRefRssiAt1m;
    const n = AppConstants.blePathLossExponent;
    // Evita log de valores extremos; clampa a distância a [0.1, max].
    final exponent = (ref - rssi) / (10 * n);
    var d = math.pow(10, exponent).toDouble();
    if (d < 0.1) d = 0.1;
    if (d > AppConstants.maxDisplayDistance) d = AppConstants.maxDisplayDistance;
    return d;
  }

  /// Processa um novo pacote RSSI e devolve a distância **suavizada** em metros.
  ///
  /// Usamos uma média móvel exponencial (EWMA) das últimas [_windowSize]
  /// amostras para reduzir o jitter do RSSI (que varia ±5 dB entre pacotes).
  Future<double> feed(String tagId, int rssi) async {
    final ref = await _refRssiAt1m(tagId);

    var history = _rssiHistory[tagId] ?? <int>[];
    history = [...history, rssi];
    if (history.length > _windowSize) {
      history = history.sublist(history.length - _windowSize);
    }
    _rssiHistory[tagId] = history;

    // Suavização EWMA: peso maior na amostra mais recente.
    const alpha = 0.3;
    final prev = _smoothedRssi[tagId] ?? rssi.toDouble();
    final smoothed = alpha * rssi + (1 - alpha) * prev;
    _smoothedRssi[tagId] = smoothed;

    // Também calcula a média da janela inteira (mais estável) e usa a média
    // das duas para um resultado equilibrado entre reatividade e estabilidade.
    final windowAvg = history.reduce((a, b) => a + b) / history.length;
    final blended = (smoothed + windowAvg) / 2;

    return rssiToDistance(blended, refRssiAt1m: ref);
  }

  /// Distância estimada a partir do último RSSI suavizado de uma tag.
  Future<double?> lastDistance(String tagId) async {
    final smoothed = _smoothedRssi[tagId];
    if (smoothed == null) return null;
    final ref = await _refRssiAt1m(tagId);
    return rssiToDistance(smoothed, refRssiAt1m: ref);
  }

  /// Tendência: está se aproximando, afastando ou estável?
  /// Retorna: 1 = aproximando, -1 = afastando, 0 = estável/indeterminado.
  int trend(String tagId) {
    final history = _rssiHistory[tagId];
    if (history == null || history.length < 4) return 0;

    final mid = history.length ~/ 2;
    final firstHalf = history.sublist(0, mid);
    final secondHalf = history.sublist(mid);
    final avg1 = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final avg2 = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

    final delta = avg2 - avg1; // RSSI subindo (menos negativo) = mais perto
    const threshold = 4.0; // dB, para ignorar ruído
    if (delta > threshold) return 1;
    if (delta < -threshold) return -1;
    return 0;
  }

  /// **Calibração:** usuário informa a distância real em que está da tag e o
  /// RSSI atual. Ajustamos o RSSI de referência a 1 m e persistimos por tag.
  ///
  ///   ref @ 1m = rssi - 10 * n * log10(distanciaReal)
  ///
  /// Passe [rssi] como a leitura mais recente e [realDistanceMeters] como a
  /// distância que o usuário sabe ter (ex.: 1.0 m segurando a tag).
  Future<void> calibrate(
    String tagId, {
    required int rssi,
    required double realDistanceMeters,
  }) async {
    await _ensurePrefs();
    const n = AppConstants.blePathLossExponent;
    final ref = rssi - 10 * n * math.log(realDistanceMeters) / math.ln10;
    final key = 'ref_rssi_1m_$tagId';
    await _prefs!.setDouble(key, ref);
    debugPrint('[Distance] Calibração $tagId: ref@1m = $ref dBm '
        '(rssi=$rssi, dist=${realDistanceMeters}m)');
  }

  /// Limpa a calibração de uma tag, voltando ao default.
  Future<void> clearCalibration(String tagId) async {
    await _ensurePrefs();
    await _prefs!.remove('ref_rssi_1m_$tagId');
  }

  /// Reinicia o histórico de uma tag (ex.: ao parar o scan).
  void reset(String tagId) {
    _rssiHistory.remove(tagId);
    _smoothedRssi.remove(tagId);
  }

  void resetAll() {
    _rssiHistory.clear();
    _smoothedRssi.clear();
  }
}
