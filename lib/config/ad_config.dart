// lib/config/ad_config.dart
import 'dart:io';

/// Constantes de fallback quando o Supabase não retorna a configuração.
/// Usadas por AdService quando a query falha ou retorna vazio.
class AdConfig {
  static const String bannerAdUnitIdAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String bannerAdUnitIdIos = 'ca-app-pub-3940256099942544/2934735716';
  static const String interstitialAdUnitIdAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String interstitialAdUnitIdIos = 'ca-app-pub-3940256099942544/4411468910';

  static String get bannerAdUnitId => Platform.isAndroid
      ? bannerAdUnitIdAndroid
      : bannerAdUnitIdIos;

  static String get interstitialAdUnitId => Platform.isAndroid
      ? interstitialAdUnitIdAndroid
      : interstitialAdUnitIdIos;
}

