// lib/components/interstitial_ad_manager.dart
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/ad_config.dart';
import '../services/ad_service.dart';
import '../utils/logger.dart';

class InterstitialAdManager {
  final AdService adService;
  InterstitialAd? _interstitialAd;
  bool _isLoading = false;
  bool _isAdReady = false;

  InterstitialAdManager(this.adService);

  /// Carrega um anúncio intersticial
  Future<void> loadAd() async {
    if (kIsWeb) return;
    if (_isLoading || _isAdReady) return;

    // Verificar se SDK está pronto antes de criar anúncio
    if (!await adService.isMobileAdsReady()) {
      Logger.warning('Mobile Ads SDK não está pronto, não carregando intersticial');
      return;
    }

    final shouldShow = await adService.shouldShowAds();
    if (!shouldShow) {
      Logger.debug('Usuário não está no plano free, não carregando intersticial');
      return;
    }

    _isLoading = true;

    try {
      await InterstitialAd.load(
        adUnitId: AdConfig.interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            Logger.debug('Interstitial ad loaded');
            _interstitialAd = ad;
            _isAdReady = true;
            _isLoading = false;

            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                Logger.debug('Interstitial ad showed');
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                Logger.warning('Interstitial ad failed to show: ${error.message}');
                ad.dispose();
                _interstitialAd = null;
                _isAdReady = false;
                _isLoading = false;
                // Tentar carregar novo anúncio
                loadAd();
              },
              onAdDismissedFullScreenContent: (ad) {
                Logger.debug('Interstitial ad dismissed');
                ad.dispose();
                _interstitialAd = null;
                _isAdReady = false;
                _isLoading = false;
                // Carregar novo anúncio para próxima vez
                loadAd();
              },
              onAdImpression: (ad) {
                Logger.debug('Interstitial ad impression');
              },
              onAdClicked: (ad) {
                Logger.debug('Interstitial ad clicked');
              },
            );
          },
          onAdFailedToLoad: (error) {
            Logger.warning('Interstitial ad failed to load: ${error.message}');
            _isLoading = false;
            _isAdReady = false;
          },
        ),
      );
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar intersticial', e, stackTrace);
      _isLoading = false;
      _isAdReady = false;
    }
  }

  /// Mostra o anúncio intersticial se estiver pronto
  Future<bool> showAd() async {
    if (kIsWeb) return false;

    // Verificar se SDK está pronto
    if (!await adService.isMobileAdsReady()) {
      Logger.warning('Mobile Ads SDK não está pronto, não mostrando intersticial');
      return false;
    }

    final shouldShow = await adService.shouldShowAds();
    if (!shouldShow) {
      Logger.debug('Usuário não está no plano free, não mostrando intersticial');
      return false;
    }

    if (_isAdReady && _interstitialAd != null) {
      try {
        await _interstitialAd!.show();
        return true;
      } catch (e) {
        Logger.error('Erro ao mostrar intersticial', e, StackTrace.current);
        return false;
      }
    } else {
      Logger.debug('Intersticial não está pronto, tentando carregar...');
      await loadAd();
      return false;
    }
  }

  /// Pré-carrega um anúncio intersticial
  /// Aguarda um pouco antes de tentar carregar para garantir que o SDK está pronto
  void preloadAd() {
    if (!_isLoading && !_isAdReady) {
      // Aguardar um pouco antes de tentar carregar para evitar race conditions
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!_isLoading && !_isAdReady) {
          loadAd();
        }
      });
    }
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isAdReady = false;
    _isLoading = false;
  }
}

