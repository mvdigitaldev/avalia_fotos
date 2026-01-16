// lib/config/ad_config.dart
import 'dart:io';

class AdConfig {
  // Test ad unit IDs (substituir por IDs reais do AdMob antes de produção)
  static String get bannerAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111' // Android test
      : 'ca-app-pub-3940256099942544/2934735716'; // iOS test
      
  static String get interstitialAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712' // Android test
      : 'ca-app-pub-3940256099942544/4411468910'; // iOS test
}

