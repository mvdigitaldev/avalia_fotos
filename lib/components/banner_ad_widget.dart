// lib/components/banner_ad_widget.dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/ad_service.dart';
import '../utils/logger.dart';

class BannerAdWidget extends StatefulWidget {
  final AdService adService;
  final AdSize? adSize;

  const BannerAdWidget({
    super.key,
    required this.adService,
    this.adSize,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _shouldShowAd = false;

  @override
  void initState() {
    super.initState();
    _checkAndLoadAd();
  }

  Future<void> _checkAndLoadAd() async {
    if (kIsWeb) return;

    // Aguardar um pouco para garantir que o SDK está pronto
    await Future.delayed(const Duration(milliseconds: 500));

    final shouldShow = await widget.adService.shouldShowAds();
    if (!shouldShow) {
      setState(() {
        _shouldShowAd = false;
      });
      return;
    }

    setState(() {
      _shouldShowAd = true;
    });

    await _loadAd();
  }

  Future<void> _loadAd() async {
    if (kIsWeb) return;
    
    // Verificar se SDK está pronto antes de criar anúncio
    if (!await widget.adService.isMobileAdsReady()) {
      Logger.warning('Mobile Ads SDK não está pronto, não carregando banner');
      return;
    }

    final adUnitId = await widget.adService.getBannerAdUnitId();
    if (adUnitId.isEmpty) return;

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: widget.adSize ?? AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          Logger.debug('Banner ad loaded');
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          Logger.warning('Banner ad failed to load: ${error.message}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isLoaded = false;
            });
          }
        },
        onAdOpened: (ad) => Logger.debug('Banner ad opened'),
        onAdClosed: (ad) => Logger.debug('Banner ad closed'),
        onAdImpression: (ad) => Logger.debug('Banner ad impression'),
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !_shouldShowAd || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}

