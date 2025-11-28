/// Exceções customizadas para a aplicação
/// 
/// Fornece hierarquia de exceções específicas para diferentes tipos de erros,
/// facilitando tratamento e logging adequado.

/// Exceção base para erros da aplicação
abstract class AppException implements Exception {
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;

  const AppException(
    this.message, [
    this.originalError,
    this.stackTrace,
  ]);

  @override
  String toString() => message;
}

/// Erro de autenticação
class AuthenticationException extends AppException {
  const AuthenticationException(
    super.message, [
    super.originalError,
    super.stackTrace,
  ]);
}

/// Erro de autorização (permissões)
class AuthorizationException extends AppException {
  const AuthorizationException(
    super.message, [
    super.originalError,
    super.stackTrace,
  ]);
}

/// Erro de rede/conexão
class NetworkException extends AppException {
  const NetworkException(
    super.message, [
    super.originalError,
    super.stackTrace,
  ]);
}

/// Erro de validação de dados
class ValidationException extends AppException {
  const ValidationException(
    super.message, [
    super.originalError,
    super.stackTrace,
  ]);
}

/// Erro de configuração
class ConfigurationException extends AppException {
  const ConfigurationException(
    super.message, [
    super.originalError,
    super.stackTrace,
  ]);
}

/// Erro de serviço externo (API, banco de dados, etc.)
class ServiceException extends AppException {
  const ServiceException(
    super.message, [
    super.originalError,
    super.stackTrace,
  ]);
}

/// Erro não esperado/desconhecido
class UnknownException extends AppException {
  const UnknownException(
    super.message, [
    super.originalError,
    super.stackTrace,
  ]);
}

