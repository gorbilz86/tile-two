import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdPressureConfig {
  final Duration interstitialCooldown;
  final Duration interstitialWindow;
  final int maxInterstitialPerWindow;
  final int minTriggersBetweenInterstitial;

  const AdPressureConfig({
    required this.interstitialCooldown,
    required this.interstitialWindow,
    required this.maxInterstitialPerWindow,
    required this.minTriggersBetweenInterstitial,
  });

  Map<String, dynamic> toMap() {
    return {
      'interstitialCooldownSeconds': interstitialCooldown.inSeconds,
      'interstitialWindowMinutes': interstitialWindow.inMinutes,
      'maxInterstitialPerWindow': maxInterstitialPerWindow,
      'minTriggersBetweenInterstitial': minTriggersBetweenInterstitial,
    };
  }

  factory AdPressureConfig.fromMap({
    required Map<String, dynamic> map,
    required AdPressureConfig fallback,
  }) {
    final cooldown = _readInt(map, 'interstitialCooldownSeconds') ??
        _readInt(map, 'cooldownSeconds') ??
        fallback.interstitialCooldown.inSeconds;
    final window = _readInt(map, 'interstitialWindowMinutes') ??
        _readInt(map, 'windowMinutes') ??
        fallback.interstitialWindow.inMinutes;
    final maxPerWindow = _readInt(map, 'maxInterstitialPerWindow') ??
        _readInt(map, 'maxPerWindow') ??
        fallback.maxInterstitialPerWindow;
    final minTriggers = _readInt(map, 'minTriggersBetweenInterstitial') ??
        _readInt(map, 'minTriggersBetweenAds') ??
        fallback.minTriggersBetweenInterstitial;
    return AdPressureConfig(
      interstitialCooldown:
          Duration(seconds: cooldown.clamp(15, 600).toInt()),
      interstitialWindow: Duration(minutes: window.clamp(1, 60).toInt()),
      maxInterstitialPerWindow: maxPerWindow.clamp(1, 10).toInt(),
      minTriggersBetweenInterstitial: minTriggers.clamp(1, 10).toInt(),
    );
  }

  static int? _readInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}

class AdPressureRemoteConfigService {
  AdPressureRemoteConfigService._();

  static final AdPressureRemoteConfigService instance =
      AdPressureRemoteConfigService._();
  static const String _remoteUrl =
      String.fromEnvironment('AD_PRESSURE_CONFIG_URL');
  static const String _prefsPayloadKey = 'ad_pressure_remote_payload_v1';

  Future<AdPressureConfig?> loadCached({
    required AdPressureConfig fallback,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsPayloadKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final map = _extractInterstitialMap(decoded);
      return AdPressureConfig.fromMap(map: map, fallback: fallback);
    } catch (_) {
      return null;
    }
  }

  Future<AdPressureConfig?> fetchAndCache({
    required AdPressureConfig fallback,
  }) async {
    if (_remoteUrl.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(_remoteUrl);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      return null;
    }
    try {
      final response = await http.get(uri).timeout(
            const Duration(milliseconds: 1800),
          );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final map = _extractInterstitialMap(decoded);
      final config = AdPressureConfig.fromMap(map: map, fallback: fallback);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsPayloadKey, jsonEncode(decoded));
      return config;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _extractInterstitialMap(Map<String, dynamic> source) {
    final interstitial = source['interstitial'];
    if (interstitial is Map) {
      return interstitial.cast<String, dynamic>();
    }
    final adPressure = source['adPressure'];
    if (adPressure is Map) {
      final nestedInterstitial = adPressure['interstitial'];
      if (nestedInterstitial is Map) {
        return nestedInterstitial.cast<String, dynamic>();
      }
      return adPressure.cast<String, dynamic>();
    }
    return source;
  }
}
