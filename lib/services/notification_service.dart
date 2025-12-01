import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Added import
import '../firebase_options.dart';
import 'supabase_service.dart';
import '../utils/logger.dart';

/// Handler para mensagens recebidas em background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  Logger.info('Mensagem recebida em background: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;
  String? _currentToken;

  /// Inicializa o serviço de notificações
  Future<void> initialize() async {
    if (_initialized) {
      Logger.debug('NotificationService já inicializado');
      return;
    }

    try {
      Logger.info('Iniciando NotificationService...');
      
      // Inicializar Firebase se ainda não estiver inicializado
      if (Firebase.apps.isEmpty) {
        Logger.warning('Firebase não estava inicializado no NotificationService. Inicializando...');
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          Logger.info('Firebase inicializado com sucesso (fallback)');
        } catch (firebaseError, firebaseStack) {
          Logger.error('Erro ao inicializar Firebase (fallback)', firebaseError, firebaseStack);
          rethrow;
        }
      } else {
        Logger.debug('Firebase já inicializado (OK)');
      }

      // Configurar notificações locais
      try {
        await _initializeLocalNotifications();
        Logger.info('Notificações locais configuradas');
      } catch (e, stackTrace) {
        Logger.error('Erro ao configurar notificações locais', e, stackTrace);
        // Continuar mesmo se falhar
      }

      // Solicitar permissões
      try {
        await _requestPermissions();
        Logger.info('Permissões solicitadas');
        
        // No iOS, aguardar um pouco após solicitar permissões para o sistema processar
        if (Platform.isIOS) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      } catch (e, stackTrace) {
        Logger.error('Erro ao solicitar permissões', e, stackTrace);
        // Continuar mesmo se falhar
      }

      // Configurar handlers
      try {
        await _setupMessageHandlers();
        Logger.info('Handlers de mensagens configurados');
      } catch (e, stackTrace) {
        Logger.error('Erro ao configurar handlers', e, stackTrace);
        // Continuar mesmo se falhar
      }

      // Obter e salvar token (tentar mesmo se outras coisas falharem)
      // Nota: Se o usuário não estiver autenticado, o token será salvo após login
      try {
        await _getAndSaveToken();
        Logger.info('Token inicial obtido com sucesso');
      } catch (e) {
        Logger.warning('Não foi possível obter token inicial (usuário pode não estar autenticado)');
        Logger.debug('Erro: ${e.toString()}');
        // Não é erro crítico - o token será obtido quando o usuário fizer login
        // Mas vamos tentar obter o token mesmo sem usuário autenticado (pode funcionar)
        try {
          final token = await _firebaseMessaging.getToken();
          if (token != null && token.isNotEmpty) {
            _currentToken = token;
            Logger.info('Token FCM obtido (sem usuário autenticado): ${token.substring(0, 20)}...');
            // Não salvar no Supabase ainda - será salvo quando o usuário fizer login
          }
        } catch (e2) {
          Logger.debug('Não foi possível obter token sem autenticação: ${e2.toString()}');
        }
      }

      // Escutar mudanças no token
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        Logger.info('Token FCM atualizado');
        _saveTokenToSupabase(newToken);
      });

      _initialized = true;
      Logger.info('NotificationService inicializado com sucesso');
    } catch (e, stackTrace) {
      Logger.error('Erro crítico ao inicializar NotificationService', e, stackTrace);
      // Não fazer rethrow - deixar o app continuar mesmo se notificações falharem
      _initialized = true; // Marcar como inicializado para não tentar novamente
    }
  }

  /// Inicializa notificações locais
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Criar canal de notificação para Android
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'avalia_fotos_channel',
        'Avalia Fotos Notificações',
        description: 'Notificações do app Avalia Fotos',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
  }

  /// Solicita permissões para notificações
  Future<void> _requestPermissions() async {
    try {
      if (Platform.isIOS) {
        Logger.info('Solicitando permissões iOS...');
        final settings = await _firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

        Logger.info('Permissões iOS: ${settings.authorizationStatus}');
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          Logger.info('Permissões iOS concedidas!');
        } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
          Logger.info('Permissões iOS provisórias concedidas');
        } else {
          Logger.warning('Permissões iOS negadas pelo usuário');
        }
      } else if (Platform.isAndroid) {
        Logger.info('Solicitando permissões Android...');
        // Android 13+ requer permissão explícita via flutter_local_notifications
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidPlugin != null) {
          final granted = await androidPlugin.requestNotificationsPermission();
          Logger.info('Permissão Android solicitada: $granted');
        }
        
        // Também solicitar via Firebase Messaging
        final settings = await _firebaseMessaging.requestPermission();
        Logger.info('Permissões Android FCM: ${settings.authorizationStatus}');
      }
    } catch (e, stackTrace) {
      Logger.error('Erro ao solicitar permissões', e, stackTrace);
      rethrow;
    }
  }

  /// Configura handlers para mensagens
  Future<void> _setupMessageHandlers() async {
    // Handler para mensagens em foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handler para mensagens em background (quando app está em background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // Handler para mensagens quando app é aberto a partir de notificação
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessage(initialMessage);
    }

    // Configurar handler global para background
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Obtém e salva o token FCM
  Future<void> _getAndSaveToken() async {
    try {
      Logger.info('Solicitando token FCM...');
      
      // Verificar se Firebase está inicializado
      if (Firebase.apps.isEmpty) {
        Logger.error('Firebase não está inicializado, não é possível obter token');
        throw Exception('Firebase não está inicializado');
      }

      // No iOS, aguardar o token APNS antes de obter o token FCM
      if (Platform.isIOS) {
        await _waitForAPNSToken();
      }

      Logger.debug('Firebase está inicializado, obtendo token...');
      final token = await _firebaseMessaging.getToken();
      
      if (token != null && token.isNotEmpty) {
        _currentToken = token;
        Logger.info('Token FCM obtido com sucesso: ${token.substring(0, 20)}...');
        Logger.debug('Token completo: $token');
        
        // Tentar salvar no Supabase (pode falhar se usuário não estiver autenticado)
        await _saveTokenToSupabase(token);
      } else {
        Logger.error('Token FCM é null ou vazio');
        throw Exception('Token FCM não foi obtido');
      }
    } catch (e, stackTrace) {
      Logger.error('Erro ao obter token FCM', e, stackTrace);
      Logger.error('Detalhes: ${e.toString()}');
      // Não fazer rethrow - pode ser que o usuário não esteja autenticado ainda
      // O token será obtido novamente quando o usuário fizer login
    }
  }

  /// Salva o token no Supabase
  Future<void> _saveTokenToSupabase(String token) async {
    try {
      Logger.info('=== INICIANDO SALVAMENTO DE TOKEN ===');
      Logger.info('Token a ser salvo: ${token.substring(0, 30)}...');
      
      final supabaseService = await SupabaseService.getInstance();
      Logger.debug('SupabaseService obtido');
      final client = supabaseService.client;
      
      // Aguardar um pouco para garantir que a sessão está sincronizada
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Tentar obter userId de múltiplas fontes
      String? userId = supabaseService.currentUser?.id;
      if (userId == null) {
        Logger.warning('Usuário não encontrado em currentUser. Tentando obter do client...');
        userId = client.auth.currentUser?.id;
      }
      
      Logger.info('User ID obtido: ${userId ?? "NULL"}');

      if (userId == null) {
        Logger.warning('Usuário não autenticado. Abortando salvamento do token.');
        Logger.info('O token será salvo quando o usuário fizer login.');
        return;
      }

      final platform = Platform.isIOS ? 'ios' : 'android';
      
      Logger.info('Chamando RPC save_device_token...');
      Logger.info('Parâmetros: p_token=${token.substring(0, 20)}..., p_platform=$platform');
      
      final result = await client.rpc('save_device_token', params: {
        'p_token': token,
        'p_platform': platform,
      });
      
      Logger.info('Resultado do RPC: $result');
      Logger.info('=== TOKEN SALVO COM SUCESSO VIA RPC ===');

    } catch (e, stackTrace) {
      Logger.error('=== ERRO AO SALVAR TOKEN ===');
      Logger.error('Erro: ${e.toString()}');
      Logger.error('Stack trace: $stackTrace');
      
      // Tentar novamente após um delay maior
      Logger.info('Tentando novamente após 3 segundos...');
      await Future.delayed(const Duration(seconds: 3));
      try {
         final supabaseService = await SupabaseService.getInstance();
         final client = supabaseService.client;
         
         // Verificar novamente se o usuário está autenticado
         final userId = supabaseService.currentUser?.id ?? client.auth.currentUser?.id;
         if (userId == null) {
           Logger.warning('Usuário ainda não autenticado na segunda tentativa. Abortando.');
           return;
         }
         
         final platform = Platform.isIOS ? 'ios' : 'android';
         final result = await client.rpc('save_device_token', params: {
          'p_token': token,
          'p_platform': platform,
        });
        Logger.info('Token salvo com sucesso na segunda tentativa: $result');
      } catch (e2, stackTrace2) {
        Logger.error('Falha na segunda tentativa: ${e2.toString()}');
        Logger.error('Stack trace: $stackTrace2');
      }
    }
  }

  /// Remove o token do Supabase (quando usuário faz logout)
  Future<void> removeToken() async {
    try {
      if (_currentToken == null) return;

      final supabaseService = await SupabaseService.getInstance();
      final client = supabaseService.client;

      await client
          .from('device_tokens')
          .delete()
          .eq('token', _currentToken!);

      _currentToken = null;
      Logger.info('Token removido do Supabase');
    } catch (e, stackTrace) {
      Logger.error('Erro ao remover token do Supabase', e, stackTrace);
    }
  }

  /// Handle mensagens em foreground
  void _handleForegroundMessage(RemoteMessage message) {
    Logger.info('Mensagem recebida em foreground: ${message.messageId}');
    
    // Mostrar notificação local quando app está em foreground
    _showLocalNotification(message);
  }

  /// Handle mensagens em background
  void _handleBackgroundMessage(RemoteMessage message) {
    Logger.info('Mensagem recebida em background: ${message.messageId}');
    Logger.info('Dados: ${message.data}');
    
    // Aqui você pode navegar para uma tela específica baseado nos dados
    // Por exemplo, se for uma curtida, navegar para a foto
  }

  /// Mostra notificação local
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'avalia_fotos_channel',
      'Avalia Fotos Notificações',
      channelDescription: 'Notificações do app Avalia Fotos',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data.toString(),
    );
  }

  /// Callback quando notificação é tocada
  void _onNotificationTapped(NotificationResponse response) {
    Logger.info('Notificação tocada: ${response.payload}');
    // Aqui você pode navegar para uma tela específica
  }

  /// Obtém o token atual
  String? get currentToken => _currentToken;

  /// Verifica se está inicializado
  bool get isInitialized => _initialized;

  /// Aguarda o token APNS (apenas iOS)
  Future<void> _waitForAPNSToken() async {
    if (!Platform.isIOS) return;
    
    Logger.info('Aguardando token APNS...');
    
    // Tentar obter o token APNS explicitamente
    // O método getAPNSToken() pode retornar null inicialmente, então tentamos várias vezes
    String? apnsToken;
    const maxAttempts = 60; // 30 segundos no total (aumentado)
    const delayMs = 500;
    
    for (var i = 0; i < maxAttempts; i++) {
      try {
        apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken != null && apnsToken.isNotEmpty) {
          Logger.info('Token APNS obtido após ${i * delayMs}ms: ${apnsToken.substring(0, 20)}...');
          // Aguardar um pouco mais para garantir que o token está totalmente processado
          await Future.delayed(const Duration(milliseconds: 500));
          return;
        }
      } catch (e) {
        Logger.debug('Tentativa ${i + 1} de obter token APNS falhou: ${e.toString()}');
      }
      
      // Aumentar o delay progressivamente para não sobrecarregar o sistema
      final currentDelay = i < 10 ? delayMs : delayMs * 2;
      if (i < maxAttempts - 1) {
        await Future.delayed(Duration(milliseconds: currentDelay));
      }
    }
    
    Logger.warning('Timeout aguardando token APNS após ${maxAttempts * delayMs}ms.');
    Logger.warning('Isso pode acontecer em simuladores ou se as notificações não estiverem configuradas corretamente.');
    Logger.warning('Tentando obter token FCM mesmo assim...');
    // Não lançar exceção - vamos tentar obter o token FCM mesmo sem APNS
    // em alguns casos pode funcionar
  }

  /// Método público para obter e salvar token (usado após login)
  Future<void> refreshToken() async {
    Logger.info('=== REFRESH TOKEN CHAMADO ===');
    Logger.info('Token atual: ${_currentToken != null ? "${_currentToken!.substring(0, 20)}..." : "NULL"}');
    
    try {
      // Verificar se Firebase está inicializado
      if (Firebase.apps.isEmpty) {
        Logger.warning('Firebase não está inicializado, inicializando agora...');
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        Logger.info('Firebase inicializado durante refreshToken');
      }

      // Aguardar APNS no iOS (mas não bloquear se não conseguir)
      if (Platform.isIOS) {
        await _waitForAPNSToken();
      }

      // Sempre tentar obter um novo token para garantir que está atualizado
      Logger.info('Obtendo token FCM...');
      String? token;
      
      try {
        token = await _firebaseMessaging.getToken();
      } catch (e) {
        // Se falhar por causa do APNS token, tentar uma estratégia alternativa
        if (e.toString().contains('apns-token-not-set')) {
          Logger.warning('Token APNS não disponível. Tentando estratégia alternativa...');
          
          // Aguardar mais um pouco e tentar novamente
          await Future.delayed(const Duration(seconds: 2));
          
          // Tentar obter o token APNS novamente
          final apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken != null) {
            Logger.info('Token APNS obtido na segunda tentativa');
            await Future.delayed(const Duration(milliseconds: 500));
            token = await _firebaseMessaging.getToken();
          } else {
            Logger.error('Token APNS ainda não disponível após múltiplas tentativas');
            Logger.error('Isso pode acontecer em simuladores iOS ou se as notificações não estiverem configuradas');
            throw e;
          }
        } else {
          rethrow;
        }
      }
      
      if (token != null && token.isNotEmpty) {
        Logger.info('Token FCM obtido: ${token.substring(0, 30)}...');
        _currentToken = token;
        
        // Aguardar um pouco para garantir que a sessão está sincronizada
        Logger.info('Aguardando sincronização da sessão...');
        await Future.delayed(const Duration(milliseconds: 1000));
        
        // Salvar no Supabase
        Logger.info('Salvando token no Supabase...');
        await _saveTokenToSupabase(token);
        Logger.info('=== REFRESH TOKEN CONCLUÍDO COM SUCESSO ===');
      } else {
        Logger.error('Token FCM é null ou vazio');
        throw Exception('Token FCM não foi obtido');
      }
    } catch (e, stackTrace) {
      Logger.error('=== ERRO NO REFRESH TOKEN ===');
      Logger.error('Erro: ${e.toString()}');
      Logger.error('Stack trace: $stackTrace');
      
      // Tentar novamente após um delay maior
      Logger.info('Tentando novamente após 5 segundos...');
      await Future.delayed(const Duration(seconds: 5));
      try {
        if (Platform.isIOS) {
          await _waitForAPNSToken(); // Aguardar novamente
        }
        final token = await _firebaseMessaging.getToken();
        if (token != null && token.isNotEmpty) {
          _currentToken = token;
          await Future.delayed(const Duration(milliseconds: 1000));
          await _saveTokenToSupabase(token);
          Logger.info('Token salvo com sucesso na segunda tentativa');
        }
      } catch (e2, stackTrace2) {
        Logger.error('Falha na segunda tentativa de refreshToken: ${e2.toString()}');
        Logger.error('Stack trace: $stackTrace2');
        Logger.warning('O token não pôde ser obtido. Isso pode acontecer em simuladores iOS.');
        Logger.warning('Teste em um dispositivo físico para garantir que as notificações funcionem corretamente.');
      }
    }
  }

  /// Obtém as notificações do usuário
  Future<List<Map<String, dynamic>>> getNotifications({int limit = 20, int offset = 0}) async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      final client = supabaseService.client;
      final userId = supabaseService.currentUser?.id;

      if (userId == null) {
        Logger.warning('getNotifications: Usuário não autenticado');
        return [];
      }

      Logger.info('Buscando notificações para o usuário: $userId');

      final response = await client
          .from('notifications')
          .select('''
            *,
            actor:users!notifications_actor_id_fkey (username, avatar_url),
            photo:photos!notifications_resource_id_fkey (image_url, thumbnail_url),
            comment_details:comments!notifications_comment_id_fkey (content)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      Logger.info('Notificações encontradas: ${response.length}');
      if (response.isNotEmpty) {
        Logger.debug('Primeira notificação (raw): ${response.first}');
      }

      return List<Map<String, dynamic>>.from(response);
    } catch (e, stackTrace) {
      Logger.error('Erro ao buscar notificações', e, stackTrace);
      return [];
    }
  }

  /// Marca uma notificação como lida
  Future<void> markAsRead(String notificationId) async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      final client = supabaseService.client;

      await client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e, stackTrace) {
      Logger.error('Erro ao marcar notificação como lida', e, stackTrace);
    }
  }

  /// Marca todas as notificações como lidas
  Future<void> markAllAsRead() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      final client = supabaseService.client;
      final userId = supabaseService.currentUser?.id;

      if (userId == null) return;

      await client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e, stackTrace) {
      Logger.error('Erro ao marcar todas notificações como lidas', e, stackTrace);
    }
  }

  /// Limpa todas as notificações do usuário
  Future<void> clearNotifications() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      final client = supabaseService.client;
      final userId = supabaseService.currentUser?.id;

      if (userId == null) return;

      await client
          .from('notifications')
          .delete()
          .eq('user_id', userId);
    } catch (e, stackTrace) {
      Logger.error('Erro ao limpar notificações', e, stackTrace);
    }
  }

  /// Obtém a contagem de notificações não lidas
  Future<int> getUnreadCount() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      final client = supabaseService.client;
      final userId = supabaseService.currentUser?.id;

      if (userId == null) return 0;

      final count = await client
          .from('notifications')
          .count(CountOption.exact)
          .eq('user_id', userId)
          .eq('is_read', false);

      return count;
    } catch (e, stackTrace) {
      Logger.error('Erro ao buscar contagem de notificações', e, stackTrace);
      return 0;
    }
  }
}

