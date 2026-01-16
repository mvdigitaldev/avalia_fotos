// lib/services/ad_service.dart
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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

  AdService(this._supabaseService);

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
      if (_planService == null) {
        _planService = PlanService(_supabaseService);
      }

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

