// lib/services/report_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/report_model.dart';
import '../utils/logger.dart';

class ReportService {
  final SupabaseService _supabaseService;

  ReportService(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;
  String? get currentUserId => _supabaseService.currentUser?.id;

  /// Cria uma denúncia
  Future<void> createReport({
    required String? photoId,
    required String? commentId,
    required ReportType reportType,
    required String reason,
    String? description,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('Usuário não autenticado');
      }

      // Validar que apenas um dos IDs está preenchido
      if (reportType == ReportType.photo && photoId == null) {
        throw Exception('photoId é obrigatório para denúncias de foto');
      }
      if (reportType == ReportType.comment && commentId == null) {
        throw Exception('commentId é obrigatório para denúncias de comentário');
      }

      await _client.from('reports').insert({
        'user_id': userId,
        'photo_id': photoId,
        'comment_id': commentId,
        'report_type': reportType.value,
        'reason': reason,
        'description': description,
        'status': ReportStatus.pending.value,
      });

      Logger.info('Denúncia criada com sucesso');
    } catch (e) {
      Logger.error('Erro ao criar denúncia', e, StackTrace.current);
      rethrow;
    }
  }

  /// Lista denúncias (apenas para admins)
  Future<List<ReportModel>> getReports({
    ReportStatus? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _client
          .from('reports')
          .select('''
            *,
            reporter:users!reports_user_id_fkey (username),
            photo:photos!reports_photo_id_fkey (image_url),
            comment:comments!reports_comment_id_fkey (content)
          ''');

      if (status != null) {
        query = query.eq('status', status.value);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      var reports = (response as List)
          .map((item) => ReportModel.fromJson(item))
          .toList();

      // Se filtrando por 'pending', excluir denúncias com conteúdo já deletado
      // (onde tanto photo_id quanto comment_id são NULL)
      if (status == ReportStatus.pending) {
        reports = reports.where((report) {
          return report.photoId != null || report.commentId != null;
        }).toList();
      }

      return reports;
    } catch (e) {
      Logger.error('Erro ao listar denúncias', e, StackTrace.current);
      rethrow;
    }
  }

  /// Aprova uma denúncia (deleta o conteúdo)
  Future<void> approveReport(String reportId) async {
    try {
      await _client.rpc('approve_report_and_delete_content', params: {
        'p_report_id': reportId,
      });
      Logger.info('Denúncia aprovada e conteúdo deletado: $reportId');
    } catch (e) {
      Logger.error('Erro ao aprovar denúncia', e, StackTrace.current);
      rethrow;
    }
  }

  /// Rejeita uma denúncia (descartar)
  Future<void> rejectReport(String reportId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('Usuário não autenticado');
      }

      await _client
          .from('reports')
          .update({
            'status': ReportStatus.rejected.value,
            'reviewed_by': userId,
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reportId);

      Logger.info('Denúncia rejeitada: $reportId');
    } catch (e) {
      Logger.error('Erro ao rejeitar denúncia', e, StackTrace.current);
      rethrow;
    }
  }

  /// Conta denúncias pendentes (apenas para admins)
  Future<int> getPendingReportsCount() async {
    try {
      final response = await _client.rpc('get_pending_reports_count');
      return (response as num).toInt();
    } catch (e) {
      Logger.error('Erro ao contar denúncias pendentes', e, StackTrace.current);
      rethrow;
    }
  }

  /// Verifica se o usuário atual é admin
  Future<bool> isCurrentUserAdmin() async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;

      final response = await _client
          .from('users')
          .select('is_admin')
          .eq('id', userId)
          .single();

      return (response['is_admin'] as bool?) ?? false;
    } catch (e) {
      Logger.error('Erro ao verificar se usuário é admin', e, StackTrace.current);
      return false;
    }
  }
}

