import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/logger.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseClient? _client;

  SupabaseService._();

  static Future<SupabaseService> getInstance() async {
    if (_instance == null) {
      _instance = SupabaseService._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  Future<void> _initialize() async {
    try {
      // Importar configuração
      final config = await _loadConfig();

      Logger.debug('Inicializando Supabase com URL: ${config['url']}');

      await Supabase.initialize(
        url: config['url']!,
        anonKey: config['anonKey']!,
      );

      _client = Supabase.instance.client;
      Logger.info('Supabase inicializado com sucesso');
    } catch (e, stackTrace) {
      Logger.error('Erro ao inicializar Supabase', e, stackTrace);
      _client = null; // Garantir que _client seja null em caso de erro
      rethrow;
    }
  }

  Future<Map<String, String>> _loadConfig() async {
    // Prioridade 1: Variáveis de ambiente do sistema (--dart-define)
    const envUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const envKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

    if (envUrl.isNotEmpty && envKey.isNotEmpty) {
      Logger.info('Usando variáveis de ambiente do sistema (--dart-define)');
      return {'url': envUrl, 'anonKey': envKey};
    }

    // Prioridade 2: Arquivo .env (flutter_dotenv) - apenas em mobile
    try {
      final dotenvUrl = dotenv.env['SUPABASE_URL'];
      final dotenvKey = dotenv.env['SUPABASE_ANON_KEY'];

      if (dotenvUrl != null && dotenvUrl.isNotEmpty &&
          dotenvKey != null && dotenvKey.isNotEmpty) {
        Logger.info('Usando variáveis de ambiente do arquivo .env');
        return {'url': dotenvUrl, 'anonKey': dotenvKey};
      }
    } catch (e) {
      Logger.debug('Erro ao acessar dotenv (pode ser normal na web)', e);
    }

    // Fallback temporário para desenvolvimento (REMOVER EM PRODUÇÃO)
    // TODO: Remover este fallback e garantir que .env seja criado ou use --dart-define
    Logger.warning(
      'Credenciais não encontradas em variáveis de ambiente ou .env. '
      'Usando valores de fallback para desenvolvimento. '
      'Para produção, configure SUPABASE_URL e SUPABASE_ANON_KEY usando --dart-define ou arquivo .env.',
    );
    
    return {
      'url': 'https://yulxxamlfxujclnzzcjb.supabase.co',
      'anonKey':
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl1bHh4YW1sZnh1amNsbnp6Y2piIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQxNTYwMjgsImV4cCI6MjA3OTczMjAyOH0.UcUbYxhnaXwvGYokwthKJRwk5MlHt-GMtZsslohbwdM',
    };
  }

  SupabaseClient get client {
    if (_client == null) {
      throw Exception(
        'Supabase não foi inicializado. Chame getInstance() primeiro.',
      );
    }
    return _client!;
  }

  User? get currentUser {
    try {
      return client.auth.currentUser;
    } catch (e) {
      Logger.debug('Erro ao acessar currentUser - Supabase pode não estar inicializado', e);
      return null;
    }
  }

  Stream<AuthState> get authStateChanges {
    try {
      return client.auth.onAuthStateChange;
    } catch (e) {
      Logger.error('Erro ao acessar authStateChanges - Supabase não inicializado', e);
      // Retornar stream vazio se não estiver inicializado
      return const Stream<AuthState>.empty();
    }
  }

  // Método estático para verificar autenticação
  static bool get isAuthenticated {
    try {
      return _client?.auth.currentUser != null;
    } catch (e) {
      Logger.debug('Erro ao verificar autenticação - Supabase pode não estar inicializado', e);
      return false;
    }
  }
}

