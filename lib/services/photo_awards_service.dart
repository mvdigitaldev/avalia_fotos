// lib/services/photo_awards_service.dart
import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/photo_model.dart';
import '../models/photo_of_week_month_models.dart';
import '../utils/logger.dart';
import 'supabase_service.dart';

/// Foto da semana / foto do mês (RPCs alinhados a photo_of_the_day).
class PhotoAwardsService {
  PhotoAwardsService(this._supabaseService);

  final SupabaseService _supabaseService;

  SupabaseClient get _client => _supabaseService.client;

  static DateTime dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  /// Segunda-feira ISO da semana que contém [d].
  static DateTime weekStartMonday(DateTime d) {
    final x = dateOnly(d);
    return x.subtract(Duration(days: x.weekday - DateTime.monday));
  }

  /// Ano ISO da semana e número da semana (1–53), fuso local.
  static ({int weekYear, int week}) isoWeekMeta(DateTime d) {
    final mon = weekStartMonday(d);
    final thu = mon.add(const Duration(days: 3));
    final weekYear = thu.year;
    final week1Mon = weekStartMonday(DateTime(weekYear, 1, 4));
    final week = 1 + mon.difference(week1Mon).inDays ~/ 7;
    return (weekYear: weekYear, week: week);
  }

  /// Segunda-feira da semana ISO [week] no ano ISO [weekYear].
  static DateTime mondayOfIsoWeek(int weekYear, int week) {
    final week1Mon = weekStartMonday(DateTime(weekYear, 1, 4));
    return week1Mon.add(Duration(days: (week - 1) * 7));
  }

  /// Quantas semanas ISO tem o ano ISO [isoYear] (52 ou 53).
  static int isoWeeksInIsoYear(int isoYear) {
    var meta = isoWeekMeta(DateTime(isoYear, 12, 28));
    if (meta.weekYear == isoYear) return meta.week;
    meta = isoWeekMeta(DateTime(isoYear, 12, 21));
    return meta.week;
  }

  /// Maior semana selecionável em [weekYear] (sem semanas futuras).
  static int maxSelectableIsoWeekForYear(int weekYear, DateTime now) {
    final n = dateOnly(now);
    final current = isoWeekMeta(n);
    if (weekYear < current.weekYear) return isoWeeksInIsoYear(weekYear);
    if (weekYear > current.weekYear) return 1;
    return current.week;
  }

  /// Rótulo para lista/dropdown: "Semana 4 · 19/01 – 25/01/2026".
  static String weekOptionLabel(int weekYear, int week) {
    final mon = mondayOfIsoWeek(weekYear, week);
    final end = mon.add(const Duration(days: 6));
    final a = DateFormat('dd/MM', 'pt_BR').format(mon);
    final b = DateFormat('dd/MM/yyyy', 'pt_BR').format(end);
    return 'Semana $week · $a – $b';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _parseJsonRow(dynamic item) {
    if (item is Map<String, dynamic>) return item;
    if (item is String) {
      return jsonDecode(item) as Map<String, dynamic>;
    }
    return Map<String, dynamic>.from(item as Map);
  }

  Future<List<PhotoModel>> getCandidatePhotosForWeek(DateTime weekAnyDay) async {
    try {
      final ws = weekStartMonday(weekAnyDay);
      final response = await _client.rpc(
        'get_candidate_photos_for_week',
        params: {'p_week_start': _formatDate(ws)},
      );
      if (response == null || response is! List) return [];
      final photos = <PhotoModel>[];
      for (final item in response) {
        try {
          photos.add(PhotoModel.fromJson(_parseJsonRow(item)));
        } catch (e, st) {
          Logger.warning('Erro ao parsear candidata da semana', e, st);
        }
      }
      return photos;
    } catch (e, st) {
      Logger.error('Erro ao buscar candidatas da semana', e, st);
      return [];
    }
  }

  Future<PhotoOfTheWeekModel?> getPhotoOfTheWeek(DateTime weekAnyDay) async {
    try {
      final ws = weekStartMonday(weekAnyDay);
      final response = await _client.rpc(
        'get_photo_of_the_week',
        params: {'p_week_start': _formatDate(ws)},
      );
      if (response == null || (response as List).isEmpty) return null;
      final data = (response as List).first as Map<String, dynamic>;
      return PhotoOfTheWeekModel.fromJson(data);
    } catch (e, st) {
      Logger.error('Erro ao buscar foto da semana', e, st);
      return null;
    }
  }

  Future<String> selectPhotoOfTheWeek(String photoId, DateTime weekAnyDay) async {
    final ws = weekStartMonday(weekAnyDay);
    final response = await _client.rpc(
      'select_photo_of_the_week',
      params: {
        'p_photo_id': photoId,
        'p_week_start': _formatDate(ws),
      },
    );
    try {
      await _sendWeekPush(photoId, ws);
    } catch (e, st) {
      Logger.warning('Erro ao enviar push foto da semana', e, st);
    }
    return response.toString();
  }

  Future<void> removePhotoOfTheWeek(DateTime weekAnyDay) async {
    final ws = weekStartMonday(weekAnyDay);
    await _client
        .from('photo_of_the_week')
        .delete()
        .eq('week_start', _formatDate(ws));
  }

  Future<List<PhotoModel>> getCandidatePhotosForMonth(int year, int month) async {
    try {
      final response = await _client.rpc(
        'get_candidate_photos_for_month',
        params: {'p_year': year, 'p_month': month},
      );
      if (response == null || response is! List) return [];
      final photos = <PhotoModel>[];
      for (final item in response) {
        try {
          photos.add(PhotoModel.fromJson(_parseJsonRow(item)));
        } catch (e, st) {
          Logger.warning('Erro ao parsear candidata do mês', e, st);
        }
      }
      return photos;
    } catch (e, st) {
      Logger.error('Erro ao buscar candidatas do mês', e, st);
      return [];
    }
  }

  Future<PhotoOfTheMonthModel?> getPhotoOfTheMonth(DateTime monthStart) async {
    try {
      final ms = DateTime(monthStart.year, monthStart.month, 1);
      final response = await _client.rpc(
        'get_photo_of_the_month',
        params: {'p_month_start': _formatDate(ms)},
      );
      if (response == null || (response as List).isEmpty) return null;
      final data = (response as List).first as Map<String, dynamic>;
      return PhotoOfTheMonthModel.fromJson(data);
    } catch (e, st) {
      Logger.error('Erro ao buscar foto do mês', e, st);
      return null;
    }
  }

  Future<String> selectPhotoOfTheMonth(String photoId, DateTime monthStart) async {
    final ms = DateTime(monthStart.year, monthStart.month, 1);
    final response = await _client.rpc(
      'select_photo_of_the_month',
      params: {
        'p_photo_id': photoId,
        'p_month_start': _formatDate(ms),
      },
    );
    try {
      await _sendMonthPush(photoId, ms);
    } catch (e, st) {
      Logger.warning('Erro ao enviar push foto do mês', e, st);
    }
    return response.toString();
  }

  Future<void> removePhotoOfTheMonth(DateTime monthStart) async {
    final ms = DateTime(monthStart.year, monthStart.month, 1);
    await _client
        .from('photo_of_the_month')
        .delete()
        .eq('month_start', _formatDate(ms));
  }

  Future<PhotoAwardFlags> getAwardFlagsByPhotoId(String photoId) async {
    try {
      final results = await Future.wait<dynamic>([
        _client.rpc(
          'is_photo_of_the_day_by_photo_id',
          params: {'p_photo_id': photoId},
        ),
        _client.rpc(
          'is_photo_of_the_week_by_photo_id',
          params: {'p_photo_id': photoId},
        ),
        _client.rpc(
          'is_photo_of_the_month_by_photo_id',
          params: {'p_photo_id': photoId},
        ),
      ]);
      return PhotoAwardFlags(
        day: results[0] == true,
        week: results[1] == true,
        month: results[2] == true,
      );
    } catch (e, st) {
      Logger.error('Erro ao buscar selos de premiação', e, st);
      return const PhotoAwardFlags(day: false, week: false, month: false);
    }
  }

  Future<void> _sendWeekPush(String photoId, DateTime weekStart) async {
    final end = weekStart.add(const Duration(days: 6));
    final label =
        '${DateFormat('dd/MM', 'pt_BR').format(weekStart)}–${DateFormat('dd/MM/yyyy', 'pt_BR').format(end)}';
    final ws = _formatDate(weekStart);
    await _client.functions.invoke(
      'send-push-notification',
      body: {
        'type': 'photo_of_the_week',
        'title': 'Nova Foto da Semana!',
        'body': 'A foto da semana ($label) foi selecionada! Veja a premiada.',
        'data': {
          'type': 'photo_of_the_week',
          'photo_id': photoId,
          'week_start': ws,
          'deep_link': '/premiacoes?tab=week&week=$ws',
        },
        'broadcast': true,
      },
    );
  }

  Future<void> _sendMonthPush(String photoId, DateTime monthStart) async {
    final ms = DateTime(monthStart.year, monthStart.month, 1);
    final label = DateFormat('MMMM yyyy', 'pt_BR').format(ms);
    final msStr = _formatDate(ms);
    await _client.functions.invoke(
      'send-push-notification',
      body: {
        'type': 'photo_of_the_month',
        'title': 'Nova Foto do Mês!',
        'body': 'A foto do mês de $label foi selecionada! Veja a premiada.',
        'data': {
          'type': 'photo_of_the_month',
          'photo_id': photoId,
          'month_start': msStr,
          'deep_link': '/premiacoes?tab=month&month=$msStr',
        },
        'broadcast': true,
      },
    );
  }
}

class PhotoAwardFlags {
  final bool day;
  final bool week;
  final bool month;

  const PhotoAwardFlags({
    required this.day,
    required this.week,
    required this.month,
  });

  bool get any => day || week || month;
}
