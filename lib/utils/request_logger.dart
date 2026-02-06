import 'package:flutter/foundation.dart';

/// Instrumentação PR4: contador de requests por ação (Feed load, Feed scroll, Like, Comment add).
/// Ativo apenas em debug; use para medir antes/depois das otimizações.
class RequestLogger {
  static const String _tag = '[Perf]';

  static final Map<String, int> _counts = {};

  /// Registra uma ação e opcionalmente quantas requisições ela gerou.
  /// Em debug, incrementa o contador e loga uma linha.
  static void logAction(String action, {int requestCount = 1}) {
    if (!kDebugMode) return;
    _counts[action] = (_counts[action] ?? 0) + requestCount;
    debugPrint('$_tag $action requests=$requestCount (total ${action}: ${_counts[action]})');
  }

  /// Retorna o total acumulado de uma ação (para testes ou UI em debug).
  static int getCount(String action) => _counts[action] ?? 0;

  /// Zera os contadores (útil para medir um fluxo isolado).
  static void reset() {
    if (kDebugMode) {
      _counts.clear();
      debugPrint('$_tag counters reset');
    }
  }

  /// Rótulos padronizados para as ações do plano de performance.
  static const String feedLoad = 'feed_load';
  static const String feedScroll = 'feed_scroll';
  static const String like = 'like';
  static const String commentAdd = 'comment_add';
}
