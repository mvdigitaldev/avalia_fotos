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

  AsaasService(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;
  String? get currentUserId => _supabaseService.currentUser?.id;

  /// Obtém a API Key do Asaas do .env
  String? get _apiKey {
    try {
      return dotenv.env['ASSAS_KEY'];
    } catch (e) {
      Logger.warning('Erro ao carregar ASSAS_KEY do .env', e);
      return null;
    }
  }

  /// Headers para requisições à API Asaas
  Map<String, String> get _headers {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('ASSAS_KEY não configurada no .env');
    }
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
}

