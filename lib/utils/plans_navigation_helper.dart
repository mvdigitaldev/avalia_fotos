// lib/utils/plans_navigation_helper.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';
import 'logger.dart';

/// Helper para navegar para a página de planos conforme habilitar_planos.
/// habilitar_planos = true  → /plans (Apple/In-App Purchase)
/// habilitar_planos = false → /plans_assas (Asaas)
class PlansNavigationHelper {
  static Future<void> navigateToPlans(BuildContext context) async {
    if (!context.mounted) return;

    try {
      final supabaseService = await SupabaseService.getInstance();
      final response = await supabaseService.client
          .from('system_configuration')
          .select('habilitar_planos')
          .limit(1)
          .maybeSingle();

      if (!context.mounted) return;

      final habilitarPlanos = response?['habilitar_planos'] as bool? ?? false;
      if (habilitarPlanos) {
        context.push('/plans');
      } else {
        context.push('/plans_assas');
      }
    } catch (e, stackTrace) {
      Logger.warning('Erro ao buscar habilitar_planos, usando /plans_assas', e, stackTrace);
      if (context.mounted) {
        context.push('/plans_assas');
      }
    }
  }
}
