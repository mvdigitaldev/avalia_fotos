// lib/services/ad_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/ad_config.dart';
import 'supabase_service.dart';
import 'plan_service.dart';
import '../utils/logger.dart';

/// Flag estático para rastrear se o Mobile Ads SDK foi inicializado
class _MobileAdsInitialization {
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;
  static void markAsInitialized() {
    _isInitialized = true;
  }
}

class AdService {
  final SupabaseService _supabaseService;
  PlanService? _planService;

  Map<String, String?>? _adConfigCache;
  DateTime? _adConfigCacheExpiry;
  static const _cacheTtlMinutes = 5;

  AdService(this._supabaseService);

  bool get _isAdConfigCacheValid {
    if (_adConfigCache == null || _adConfigCacheExpiry == null) return false;
    return DateTime.now().isBefore(_adConfigCacheExpiry!);
  }

  Future<Map<String, String?>> _fetchAdConfig() async {
    try {
      final response = await _supabaseService.client
          .from('ad_configuration')
          .select('banner_ad_unit_id_android,banner_ad_unit_id_ios,interstitial_ad_unit_id_android,interstitial_ad_unit_id_ios')
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return {
          'banner_android': response['banner_ad_unit_id_android'] as String?,
          'banner_ios': response['banner_ad_unit_id_ios'] as String?,
          'interstitial_android': response['interstitial_ad_unit_id_android'] as String?,
          'interstitial_ios': response['interstitial_ad_unit_id_ios'] as String?,
        };
      }
    } catch (e, stackTrace) {
      Logger.warning('Erro ao buscar ad_configuration do Supabase', e, stackTrace);
    }
    return {};
  }

  Future<String> getBannerAdUnitId() async {
    if (kIsWeb) return '';

    if (_isAdConfigCacheValid && _adConfigCache != null) {
      final key = Platform.isAndroid ? 'banner_android' : 'banner_ios';
      final cached = _adConfigCache![key];
      if (cached != null && cached.isNotEmpty) return cached;
      return AdConfig.bannerAdUnitId;
    }

    _adConfigCache = await _fetchAdConfig();
    _adConfigCacheExpiry = DateTime.now().add(const Duration(minutes: _cacheTtlMinutes));

    final key = Platform.isAndroid ? 'banner_android' : 'banner_ios';
    final value = _adConfigCache![key];
    if (value != null && value.isNotEmpty) return value;
    return AdConfig.bannerAdUnitId;
  }

  Future<String> getInterstitialAdUnitId() async {
    if (kIsWeb) return '';

    if (_isAdConfigCacheValid && _adConfigCache != null) {
      final key = Platform.isAndroid ? 'interstitial_android' : 'interstitial_ios';
      final cached = _adConfigCache![key];
      if (cached != null && cached.isNotEmpty) return cached;
      return AdConfig.interstitialAdUnitId;
    }

    _adConfigCache = await _fetchAdConfig();
    _adConfigCacheExpiry = DateTime.now().add(const Duration(minutes: _cacheTtlMinutes));

    final key = Platform.isAndroid ? 'interstitial_android' : 'interstitial_ios';
    final value = _adConfigCache![key];
    if (value != null && value.isNotEmpty) return value;
    return AdConfig.interstitialAdUnitId;
  }

  /// Verifica se o Google Mobile Ads SDK está pronto para uso
  /// O SDK já é inicializado no main.dart, então apenas verificamos o flag
  Future<bool> isMobileAdsReady() async {
    if (kIsWeb) return false;
    return _MobileAdsInitialization.isInitialized;
  }

  /// Marca o SDK como inicializado (chamado do main.dart após inicialização)
  static void markInitialized() {
    _MobileAdsInitialization.markAsInitialized();
  }

  /// Verifica se o usuário está no plano free e se o SDK está pronto
  Future<bool> shouldShowAds() async {
    if (kIsWeb) return false;
    
    // Verificar se SDK está inicializado primeiro
    if (!await isMobileAdsReady()) {
      Logger.debug('Mobile Ads SDK não está pronto, não mostrando anúncios');
      return false;
    }

    try {
      _planService ??= PlanService(_supabaseService);

      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return false;

      final userPlan = await _planService!.getUserPlan(userId);
      // Mostrar anúncios apenas se o usuário estiver no plano free ou não tiver plano
      return userPlan == null || userPlan.plan.isFree;
    } catch (e, stackTrace) {
      Logger.error('Erro ao verificar se deve mostrar anúncios', e, stackTrace);
      return false;
    }
  }
}

