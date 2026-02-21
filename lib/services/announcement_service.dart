import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'storage_service.dart';
import '../models/announcement_model.dart';
import '../utils/logger.dart';

class AnnouncementService {
  final SupabaseService _supabaseService;

  AnnouncementService(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;
  String? get _userId => _supabaseService.currentUser?.id;

  static const int _pageSize = 20;

  /// List announcements ordered by pinned first, then by created_at desc. Single query.
  Future<List<AnnouncementModel>> getAnnouncements({
    int limit = _pageSize,
    int offset = 0,
  }) async {
    try {
      final response = await _client
          .from('announcements')
          .select('*, author:users!announcements_author_id_fkey(username)')
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      Logger.error('Erro ao listar avisos', e, stackTrace);
      rethrow;
    }
  }

  /// Get a single announcement by id.
  Future<AnnouncementModel?> getAnnouncementById(String id) async {
    try {
      final response = await _client
          .from('announcements')
          .select('*, author:users!announcements_author_id_fkey(username)')
          .eq('id', id)
          .maybeSingle();
      if (response == null) return null;
      return AnnouncementModel.fromJson(response as Map<String, dynamic>);
    } catch (e, stackTrace) {
      Logger.error('Erro ao buscar aviso', e, stackTrace);
      rethrow;
    }
  }

  /// Count announcements created after user's last_seen_at (unread). Uses 2 queries.
  Future<int> getUnreadCount() async {
    try {
      final userId = _userId;
      if (userId == null) return 0;

      final seen = await _client
          .from('user_announcement_last_seen')
          .select('last_seen_at')
          .eq('user_id', userId)
          .maybeSingle();

      final DateTime? lastSeen = seen != null
          ? DateTime.parse((seen['last_seen_at'] as String))
          : null;

      if (lastSeen == null) {
        return await _client.from('announcements').count(CountOption.exact);
      }
      return await _client
          .from('announcements')
          .count(CountOption.exact)
          .gt('created_at', lastSeen.toIso8601String());
    } catch (e, stackTrace) {
      Logger.error('Erro ao contar avisos não lidos', e, stackTrace);
      return 0;
    }
  }

  /// Mark all announcements as seen for current user (upsert last_seen_at = now).
  Future<void> markAsSeen() async {
    try {
      final userId = _userId;
      if (userId == null) return;

      await _client.from('user_announcement_last_seen').upsert(
            {'user_id': userId, 'last_seen_at': DateTime.now().toUtc().toIso8601String()},
            onConflict: 'user_id',
          );
    } catch (e, stackTrace) {
      Logger.error('Erro ao marcar avisos como vistos', e, stackTrace);
      rethrow;
    }
  }

  /// Create announcement (admin only; caller must check isAdmin). Returns created model with id.
  Future<AnnouncementModel> createAnnouncement({
    required String title,
    required String description,
    String? imageUrl,
    String? link,
    bool isPinned = false,
  }) async {
    try {
      final userId = _userId;
      if (userId == null) throw Exception('Usuário não autenticado');

      final insert = {
        'title': title.trim(),
        'description': description.trim(),
        'image_url': imageUrl,
        'link': link?.trim().isEmpty ?? true ? null : link?.trim(),
        'is_pinned': isPinned,
        'author_id': userId,
      };

      final response = await _client
          .from('announcements')
          .insert(insert)
          .select()
          .single();

      return AnnouncementModel.fromJson(response as Map<String, dynamic>);
    } catch (e, stackTrace) {
      Logger.error('Erro ao criar aviso', e, stackTrace);
      rethrow;
    }
  }

  /// Update announcement (admin only). Returns updated model.
  Future<AnnouncementModel> updateAnnouncement({
    required String id,
    required String title,
    required String description,
    String? imageUrl,
    String? link,
    bool? isPinned,
  }) async {
    try {
      final updates = <String, dynamic>{
        'title': title.trim(),
        'description': description.trim(),
        'image_url': imageUrl,
        'link': link?.trim().isEmpty ?? true ? null : link?.trim(),
      };
      if (isPinned != null) updates['is_pinned'] = isPinned;

      final response = await _client
          .from('announcements')
          .update(updates)
          .eq('id', id)
          .select('*, author:users!announcements_author_id_fkey(username)')
          .single();

      return AnnouncementModel.fromJson(response as Map<String, dynamic>);
    } catch (e, stackTrace) {
      Logger.error('Erro ao atualizar aviso', e, stackTrace);
      rethrow;
    }
  }

  /// Delete announcement (admin only).
  Future<void> deleteAnnouncement(String id) async {
    try {
      await _client.from('announcements').delete().eq('id', id);
    } catch (e, stackTrace) {
      Logger.error('Erro ao excluir aviso', e, stackTrace);
      rethrow;
    }
  }

  /// Upload announcement image; returns public URL. Use before createAnnouncement when image is present.
  Future<String> uploadAnnouncementImage(File imageFile) async {
    final userId = _userId;
    if (userId == null) throw Exception('Usuário não autenticado');
    final storage = StorageService(_supabaseService);
    return storage.uploadAnnouncementImage(imageFile: imageFile, userId: userId);
  }
}
