import 'package:supabase_flutter/supabase_flutter.dart';

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
    // Importar configuração
    final config = await _loadConfig();

    await Supabase.initialize(
      url: config['url']!,
      anonKey: config['anonKey']!,
    );

    _client = Supabase.instance.client;
  }

  Future<Map<String, String>> _loadConfig() async {
    // Tentar carregar de variáveis de ambiente primeiro
    const envUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const envKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

    if (envUrl.isNotEmpty && envKey.isNotEmpty) {
      return {'url': envUrl, 'anonKey': envKey};
    }

    // Fallback para valores hardcoded (apenas para desenvolvimento)
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

  User? get currentUser => client.auth.currentUser;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // Método estático para verificar autenticação
  static bool get isAuthenticated => _client?.auth.currentUser != null;
}

