import 'package:flutter/foundation.dart';

/// Sistema de logging centralizado para a aplicação
/// 
/// Fornece diferentes níveis de log (debug, info, warning, error)
/// e remove logs em produção para melhorar performance e segurança.
class Logger {
  static const String _tag = '[AvaliaFotos]';

  /// Log de debug - apenas em modo debug
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('$_tag [DEBUG] $message');
      if (error != null) {
        debugPrint('$_tag [DEBUG] Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('$_tag [DEBUG] StackTrace: $stackTrace');
      }
    }
  }

  /// Log de informação
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('$_tag [INFO] $message');
    }
  }

  /// Log de aviso
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('$_tag [WARNING] $message');
      if (error != null) {
        debugPrint('$_tag [WARNING] Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('$_tag [WARNING] StackTrace: $stackTrace');
      }
    }
  }

  /// Log de erro - sempre logado, mesmo em produção (mas apenas em debug mode)
  static void error(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (kDebugMode) {
      debugPrint('$_tag [ERROR] $message');
      if (error != null) {
        debugPrint('$_tag [ERROR] Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('$_tag [ERROR] StackTrace: $stackTrace');
      }
    }
    // Em produção, você pode querer enviar para um serviço de crash reporting
    // como Firebase Crashlytics, Sentry, etc.
  }

  /// Log de erro crítico
  static void critical(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    Logger.error(message, error, stackTrace);
    // Aqui você pode adicionar lógica adicional para erros críticos
    // como notificar administradores, enviar alertas, etc.
  }
}

