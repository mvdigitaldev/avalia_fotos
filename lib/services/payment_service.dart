// lib/services/payment_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/payment_history_model.dart';

class PaymentService {
  final SupabaseService _supabaseService;

  PaymentService(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;
  String? get currentUserId => _supabaseService.currentUser?.id;

  /// Busca o histórico de pagamentos do usuário logado
  Future<List<PaymentHistoryModel>> getPaymentHistory() async {
    try {
      if (currentUserId == null) {
        throw Exception('Usuário não autenticado');
      }

      final response = await _client
          .from('payment_history')
          .select('''
            *,
            plans:plan_id (
              name
            )
          ''')
          .eq('user_id', currentUserId!)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => PaymentHistoryModel.fromJson(item))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic error) {
    if (error is PostgrestException) {
      return Exception(error.message);
    } else if (error is Exception) {
      return error;
    } else {
      return Exception('Erro desconhecido: $error');
    }
  }
}

