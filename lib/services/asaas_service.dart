// lib/services/asaas_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/plan_model.dart';
import '../utils/logger.dart';

class AsaasService {
  final SupabaseService _supabaseService;
  static const String _baseUrl = 'https://api.asaas.com/v3';

  AsaasService(this._supabaseService) {
    // Verificar se a chave está disponível ao inicializar o serviço
    _verifyApiKeyOnInit();
  }

  SupabaseClient get _client => _supabaseService.client;
  String? get currentUserId => _supabaseService.currentUser?.id;

  /// Verifica se a API Key está disponível ao inicializar o serviço
  void _verifyApiKeyOnInit() {
    Logger.info('=== AsaasService inicializado - Verificando ASSAS_KEY ===');
    final apiKey = _loadApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      Logger.error('⚠️ ATENÇÃO: ASSAS_KEY não está disponível! O serviço não funcionará até que seja configurada.');
    } else {
      Logger.info('✓ ASSAS_KEY verificada e disponível (${apiKey.length} caracteres)');
    }
  }

  /// Obtém a API Key do Asaas seguindo a mesma prioridade do SupabaseService
  /// Prioridade 1: --dart-define
  /// Prioridade 2: Arquivo .env
  String? _loadApiKey() {
    Logger.info('=== Iniciando busca por ASSAS_KEY ===');
    
    // Prioridade 1: Variáveis de ambiente do sistema (--dart-define)
    const envKey = String.fromEnvironment('ASSAS_KEY', defaultValue: '');
    Logger.info('Verificando --dart-define: ${envKey.isNotEmpty ? "ENCONTRADA (${envKey.length} chars)" : "NÃO ENCONTRADA"}');
    
    if (envKey.isNotEmpty) {
      final trimmed = envKey.trim();
      if (trimmed.isNotEmpty) {
        Logger.info('✓ Usando ASSAS_KEY do sistema (--dart-define)');
        return trimmed;
      } else {
        Logger.warning('ASSAS_KEY do --dart-define está vazia (apenas espaços)');
      }
    }

    // Prioridade 2: Arquivo .env (flutter_dotenv)
    Logger.info('Verificando arquivo .env...');
    try {
      // Verificar se dotenv está inicializado
      final dotenvKeys = dotenv.env.keys.toList();
      Logger.info('dotenv inicializado: SIM, ${dotenvKeys.length} chaves encontradas: ${dotenvKeys.join(", ")}');
      
      // Tentar acessar dotenv - se não estiver carregado, vai lançar NotInitializedError
      final dotenvKey = dotenv.env['ASSAS_KEY'];
      Logger.info('ASSAS_KEY no dotenv: ${dotenvKey != null ? "EXISTE" : "NÃO EXISTE"}');
      
      if (dotenvKey != null) {
        Logger.info('Valor bruto: "${dotenvKey}" (${dotenvKey.length} caracteres)');
        
        // Remover espaços em branco no início e fim
        final trimmedKey = dotenvKey.trim();
        Logger.info('Valor após trim: "${trimmedKey}" (${trimmedKey.length} caracteres)');
        
        if (trimmedKey.isNotEmpty) {
          Logger.info('✓ Usando ASSAS_KEY do arquivo .env');
          return trimmedKey;
        } else {
          Logger.error('✗ ASSAS_KEY no .env está vazia (apenas espaços). Verifique o arquivo .env');
        }
      } else {
        Logger.error('✗ ASSAS_KEY não encontrada no arquivo .env');
        Logger.error('Chaves disponíveis no .env: ${dotenvKeys.isEmpty ? "NENHUMA" : dotenvKeys.join(", ")}');
        Logger.error('Adicione a linha: ASSAS_KEY=sua_chave_aqui');
      }
    } catch (e) {
      // Se for NotInitializedError, significa que dotenv não foi carregado
      final errorStr = e.toString().toLowerCase();
      Logger.error('Erro ao acessar dotenv: $e');
      
      if (errorStr.contains('notinitializederror') || errorStr.contains('not initialized')) {
        Logger.error(
          '✗ dotenv não foi inicializado!\n'
          'Certifique-se de que dotenv.load() foi chamado no main() antes de usar AsaasService.\n'
          'Erro: $e'
        );
      } else {
        Logger.debug('Erro ao acessar dotenv (pode ser normal na web)', e);
      }
    }

    // Nenhuma chave encontrada
    Logger.error('=== ASSAS_KEY NÃO ENCONTRADA ===');
    Logger.error('Configure usando uma das opções:');
    Logger.error('  1. --dart-define=ASSAS_KEY=sua_chave_aqui (recomendado para produção)');
    Logger.error('     IMPORTANTE: Requer rebuild do app: flutter clean && flutter run --dart-define=ASSAS_KEY=sua_chave');
    Logger.error('  2. Arquivo .env na raiz do projeto com: ASSAS_KEY=sua_chave_aqui');
    Logger.error('     Local: raiz do projeto Flutter (mesmo nível do pubspec.yaml)');
    Logger.error('     Formato: ASSAS_KEY=sua_chave (sem espaços, sem aspas)');
    
    return null;
  }

  /// Headers para requisições à API Asaas
  Map<String, String> get _headers {
    Logger.info('=== Gerando headers para requisição Asaas ===');
    final apiKey = _loadApiKey();
    
    if (apiKey == null || apiKey.isEmpty) {
      Logger.error('ASSAS_KEY é null ou vazia após _loadApiKey()');
      throw Exception(
        'ASSAS_KEY não configurada.\n\n'
        'SOLUÇÕES:\n'
        '1. Usando --dart-define (requer rebuild):\n'
        '   flutter clean\n'
        '   flutter run --dart-define=ASSAS_KEY=sua_chave_aqui\n\n'
        '2. Usando arquivo .env:\n'
        '   - Crie arquivo .env na raiz do projeto\n'
        '   - Adicione: ASSAS_KEY=sua_chave_aqui\n'
        '   - Sem espaços, sem aspas\n'
        '   - Reinicie o app\n\n'
        'Verifique os logs acima para mais detalhes.'
      );
    }
    
    Logger.info('✓ ASSAS_KEY carregada com sucesso (${apiKey.length} caracteres)');
    return {
      'access_token': apiKey,
      'Content-Type': 'application/json',
    };
  }

  /// Verifica ou cria cliente no Asaas e salva id_cliente_assas na tabela users
  Future<String> getOrCreateCustomer(String userId, String name, String email, String cpf) async {
    try {
      // Remover caracteres não numéricos do CPF
      final cleanCpf = cpf.replaceAll(RegExp(r'[^0-9]'), '');

      // Verificar se já existe id_cliente_assas na tabela users
      final userResponse = await _client
          .from('users')
          .select('id_cliente_assas')
          .eq('id', userId)
          .maybeSingle();

      if (userResponse != null && userResponse['id_cliente_assas'] != null) {
        final customerId = userResponse['id_cliente_assas'] as String;
        Logger.info('Cliente Asaas já existe: $customerId');
        return customerId;
      }

      // Criar cliente no Asaas
      Logger.info('Criando cliente no Asaas: $name ($email)');
      
      final customerData = {
        'name': name,
        'email': email,
        'cpfCnpj': cleanCpf,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/customers'),
        headers: _headers,
        body: jsonEncode(customerData),
      );

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        Logger.error('Erro ao criar cliente no Asaas', Exception(errorBody.toString()));
        throw Exception('Erro ao criar cliente no Asaas: ${errorBody['errors'] ?? response.body}');
      }

      final customerResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final customerId = customerResponse['id'] as String;

      // Salvar id_cliente_assas na tabela users
      await _client
          .from('users')
          .update({'id_cliente_assas': customerId})
          .eq('id', userId);

      Logger.info('Cliente criado no Asaas e salvo no banco: $customerId');
      return customerId;
    } catch (e, stackTrace) {
      Logger.error('Erro em getOrCreateCustomer', e, stackTrace);
      rethrow;
    }
  }

  /// Cria cobrança no Asaas
  Future<Map<String, dynamic>> createPayment(String customerId, String planId, PlanModel plan) async {
    try {
      if (plan.price == null || plan.price! <= 0) {
        throw Exception('Plano não possui preço válido');
      }

      // Calcular data de vencimento (3 dias para PIX)
      final dueDate = DateTime.now().add(const Duration(days: 3));
      final dueDateStr = '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';

      Logger.info('Criando cobrança no Asaas para plano: ${plan.name}');

      final paymentData = {
        'customer': customerId,
        'billingType': 'PIX', // Pode ser alterado para CREDIT_CARD, BOLETO, etc.
        'value': plan.price,
        'dueDate': dueDateStr,
        'description': 'Plano ${plan.name}',
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/payments'),
        headers: _headers,
        body: jsonEncode(paymentData),
      );

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        Logger.error('Erro ao criar cobrança no Asaas', Exception(errorBody.toString()));
        throw Exception('Erro ao criar cobrança no Asaas: ${errorBody['errors'] ?? response.body}');
      }

      final paymentResponse = jsonDecode(response.body) as Map<String, dynamic>;
      
      Logger.info('Cobrança criada no Asaas: ${paymentResponse['id']}');
      
      return {
        'id': paymentResponse['id'] as String,
        'invoiceUrl': paymentResponse['invoiceUrl'] as String?,
        'status': paymentResponse['status'] as String?,
        'value': paymentResponse['value'] as num?,
      };
    } catch (e, stackTrace) {
      Logger.error('Erro em createPayment', e, stackTrace);
      rethrow;
    }
  }

  /// Cria assinatura recorrente no Asaas
  Future<Map<String, dynamic>> createSubscription(
    String customerId, 
    String planId, 
    PlanModel plan
  ) async {
    try {
      if (plan.price == null || plan.price! <= 0) {
        throw Exception('Plano não possui preço válido');
      }

      if (plan.durationMonths == null) {
        throw Exception('Plano não possui duração definida para assinatura');
      }

      // Mapear durationMonths para ciclo do Asaas
      String cycle;
      if (plan.durationMonths == 3) {
        cycle = 'QUARTERLY';
      } else if (plan.durationMonths == 6) {
        cycle = 'SEMIANNUALLY';
      } else {
        throw Exception('Duração do plano não suportada para assinatura: ${plan.durationMonths} meses');
      }

      // Calcular data da primeira cobrança (3 dias a partir de hoje)
      final nextDueDate = DateTime.now().add(const Duration(days: 3));
      final nextDueDateStr = '${nextDueDate.year}-${nextDueDate.month.toString().padLeft(2, '0')}-${nextDueDate.day.toString().padLeft(2, '0')}';

      Logger.info('Criando assinatura no Asaas para plano: ${plan.name} (ciclo: $cycle)');

      final subscriptionData = {
        'customer': customerId,
        'billingType': 'PIX', // Pode ser alterado para CREDIT_CARD, BOLETO, etc.
        'value': plan.price,
        'cycle': cycle,
        'nextDueDate': nextDueDateStr,
        'description': 'Assinatura ${plan.name}',
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/subscriptions'),
        headers: _headers,
        body: jsonEncode(subscriptionData),
      );

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        Logger.error('Erro ao criar assinatura no Asaas', Exception(errorBody.toString()));
        throw Exception('Erro ao criar assinatura no Asaas: ${errorBody['errors'] ?? response.body}');
      }

      final subscriptionResponse = jsonDecode(response.body) as Map<String, dynamic>;
      
      Logger.info('Assinatura criada no Asaas: ${subscriptionResponse['id']}');
      
      return {
        'id': subscriptionResponse['id'] as String,
        'subscriptionId': subscriptionResponse['id'] as String, // Para compatibilidade
        'status': subscriptionResponse['status'] as String?,
        'value': subscriptionResponse['value'] as num?,
        'cycle': subscriptionResponse['cycle'] as String?,
        'nextDueDate': subscriptionResponse['nextDueDate'] as String?,
      };
    } catch (e, stackTrace) {
      Logger.error('Erro em createSubscription', e, stackTrace);
      rethrow;
    }
  }
}

