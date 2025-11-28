import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import '../utils/exceptions.dart';
import '../flutter_flow/flutter_flow_theme.dart';

/// Handler centralizado para tratamento de erros
/// 
/// Fornece métodos para tratar diferentes tipos de erros e exibir
/// mensagens apropriadas para o usuário.
class ErrorHandler {
  /// Converte um erro genérico em uma exceção customizada
  static AppException handleError(dynamic error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      return error;
    }

    if (error is AuthException) {
      Logger.error('Erro de autenticação', error, stackTrace);
      return AuthenticationException(
        _getAuthErrorMessage(error),
        error,
        stackTrace,
      );
    }

    if (error is PostgrestException) {
      Logger.error('Erro do Postgrest', error, stackTrace);
      return ServiceException(
        _getPostgrestErrorMessage(error),
        error,
        stackTrace,
      );
    }

    if (error is StorageException) {
      Logger.error('Erro do Storage', error, stackTrace);
      return ServiceException(
        _getStorageErrorMessage(error),
        error,
        stackTrace,
      );
    }

    if (error is Exception) {
      final message = error.toString().replaceFirst('Exception: ', '');
      Logger.error('Exceção capturada', error, stackTrace);
      return UnknownException(message, error, stackTrace);
    }

    Logger.error('Erro desconhecido', error, stackTrace);
    return UnknownException(
      'Ocorreu um erro inesperado. Por favor, tente novamente.',
      error,
      stackTrace,
    );
  }

  /// Exibe uma mensagem de erro para o usuário usando SnackBar
  static void showError(
    BuildContext context,
    AppException error, {
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: FlutterFlowTheme.of(context).error,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Exibe uma mensagem de erro genérica para o usuário
  static void showGenericError(
    BuildContext context,
    dynamic error, [
    StackTrace? stackTrace,
  ]) {
    final appException = handleError(error, stackTrace);
    showError(context, appException);
  }

  /// Obtém mensagem de erro amigável para erros de autenticação
  static String _getAuthErrorMessage(AuthException error) {
    final message = error.message.toLowerCase();

    if (message.contains('invalid login credentials') ||
        message.contains('invalid credentials')) {
      return 'Email ou senha incorretos. Verifique suas credenciais e tente novamente.';
    }

    if (message.contains('email not confirmed')) {
      return 'Por favor, confirme seu email antes de fazer login.';
    }

    if (message.contains('user already registered')) {
      return 'Este email já está cadastrado. Faça login ou recupere sua senha.';
    }

    if (message.contains('password')) {
      return 'Erro relacionado à senha. Verifique os requisitos e tente novamente.';
    }

    if (message.contains('network') || message.contains('connection')) {
      return 'Erro de conexão. Verifique sua internet e tente novamente.';
    }

    return 'Erro ao autenticar. Por favor, tente novamente.';
  }

  /// Obtém mensagem de erro amigável para erros do Postgrest
  static String _getPostgrestErrorMessage(PostgrestException error) {
    final message = error.message.toLowerCase();
    final code = error.code;

    if (code == 'PGRST116' || message.contains('not found')) {
      return 'Registro não encontrado.';
    }

    if (code == '23505' || message.contains('duplicate') ||
        message.contains('unique')) {
      return 'Este registro já existe.';
    }

    if (code == '23503' || message.contains('foreign key')) {
      return 'Erro de referência. Verifique os dados e tente novamente.';
    }

    if (message.contains('permission') || message.contains('denied')) {
      return 'Você não tem permissão para realizar esta ação.';
    }

    if (message.contains('network') || message.contains('connection')) {
      return 'Erro de conexão com o servidor. Verifique sua internet.';
    }

    return 'Erro ao processar solicitação. Por favor, tente novamente.';
  }

  /// Obtém mensagem de erro amigável para erros do Storage
  static String _getStorageErrorMessage(StorageException error) {
    final message = error.message.toLowerCase();

    if (message.contains('not found') || message.contains('does not exist')) {
      return 'Arquivo não encontrado.';
    }

    if (message.contains('permission') || message.contains('denied')) {
      return 'Você não tem permissão para acessar este arquivo.';
    }

    if (message.contains('size') || message.contains('too large')) {
      return 'Arquivo muito grande. Tente um arquivo menor.';
    }

    if (message.contains('format') || message.contains('type')) {
      return 'Formato de arquivo não suportado.';
    }

    if (message.contains('network') || message.contains('connection')) {
      return 'Erro de conexão ao fazer upload. Verifique sua internet.';
    }

    return 'Erro ao processar arquivo. Por favor, tente novamente.';
  }
}

