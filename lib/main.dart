import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/nav/nav.dart';
import '/services/supabase_service.dart';
import '/services/notification_service.dart';
import '/services/route_tracker_service.dart';
import '/services/ad_service.dart';
import '/utils/logger.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart';
import 'index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  // Carregar variáveis de ambiente
  // Na web, o arquivo .env precisa estar nos assets ou usar --dart-define
  // Em mobile, pode carregar do sistema de arquivos
  Logger.info('=== Carregando variáveis de ambiente ===');
  
  // Verificar --dart-define primeiro (não requer arquivo)
  const assasKeyFromDefine = String.fromEnvironment('ASSAS_KEY', defaultValue: '');
  if (assasKeyFromDefine.isNotEmpty) {
    Logger.info('✓ ASSAS_KEY encontrada via --dart-define (${assasKeyFromDefine.length} caracteres)');
  } else {
    Logger.info('✗ ASSAS_KEY não encontrada via --dart-define');
  }
  
  if (!kIsWeb) {
    try {
      // Tentar carregar .env da raiz do projeto
      Logger.info('Tentando carregar arquivo .env...');
      await dotenv.load(fileName: '.env');
      Logger.info('✓ Arquivo .env carregado com sucesso');
      
      // Listar todas as chaves carregadas
      final allKeys = dotenv.env.keys.toList();
      Logger.info('Chaves carregadas do .env: ${allKeys.isEmpty ? "NENHUMA" : allKeys.join(", ")}');
      
      // Verificar se ASSAS_KEY foi carregada (para debug)
      final assasKey = dotenv.env['ASSAS_KEY'];
      if (assasKey != null && assasKey.isNotEmpty) {
        final trimmedKey = assasKey.trim();
        if (trimmedKey.isNotEmpty) {
          Logger.info('✓ ASSAS_KEY encontrada no arquivo .env (${trimmedKey.length} caracteres)');
        } else {
          Logger.error(
            '✗ ASSAS_KEY no arquivo .env está vazia ou contém apenas espaços!\n'
            'Verifique o arquivo .env e certifique-se de que a linha está assim:\n'
            'ASSAS_KEY=sua_chave_aqui\n'
            '(sem espaços antes ou depois do =)'
          );
        }
      } else {
        Logger.error(
          '✗ ASSAS_KEY não encontrada no arquivo .env!\n'
          'Chaves disponíveis: ${allKeys.isEmpty ? "NENHUMA" : allKeys.join(", ")}\n'
          'Adicione a linha: ASSAS_KEY=sua_chave_api_do_asaas\n'
          'Local do arquivo: ${Directory.current.path}/.env'
        );
      }
    } catch (e, stackTrace) {
      // Arquivo .env não encontrado - isso é normal se estiver usando --dart-define
      final errorMsg = e.toString();
      Logger.warning('Erro ao carregar arquivo .env: $e');
      
      if (errorMsg.contains('FileSystemException') || errorMsg.contains('not found')) {
        Logger.warning('Arquivo .env não encontrado. Local esperado: ${Directory.current.path}/.env');
      }
      
      // Se --dart-define também não tiver a chave, mostrar erro
      if (assasKeyFromDefine.isEmpty) {
        Logger.error(
          '✗ ASSAS_KEY não encontrada em nenhuma fonte!\n'
          'Configure usando uma das opções:\n'
          '  1. Criar arquivo .env na raiz do projeto com: ASSAS_KEY=sua_chave_aqui\n'
          '  2. Executar com: flutter clean && flutter run --dart-define=ASSAS_KEY=sua_chave_aqui\n'
          '     (IMPORTANTE: --dart-define requer rebuild completo do app)'
        );
      }
    }
  } else {
    // Na web, tentar carregar do assets (se configurado) ou usar --dart-define
    Logger.debug('Plataforma web detectada - usando --dart-define ou fallback para variáveis de ambiente');
    
    if (assasKeyFromDefine.isEmpty) {
      Logger.warning('ASSAS_KEY não encontrada via --dart-define na web');
    }
  }
  
  Logger.info('=== Fim do carregamento de variáveis de ambiente ===');

  await FlutterFlowTheme.initialize();

  // Inicializar Firebase antes de tudo
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      Logger.info('Firebase inicializado com sucesso no main()');
    } catch (e, stackTrace) {
      Logger.error('Erro crítico ao inicializar Firebase no main()', e, stackTrace);
    }
  }
  
  // Inicializar Supabase ANTES de criar o app
  // Isso é crítico porque o router e AppStateNotifier dependem do Supabase
  try {
    await SupabaseService.getInstance();
    Logger.info('Supabase inicializado com sucesso no main()');
  } catch (e, stackTrace) {
    Logger.error('Erro crítico ao inicializar Supabase no main()', e, stackTrace);
    // Tentar inicializar novamente com fallback
    try {
      // Forçar inicialização mesmo com erro
      await SupabaseService.getInstance();
    } catch (e2, stackTrace2) {
      Logger.critical('Falha crítica na inicialização do Supabase', e2, stackTrace2);
      // Continuar mesmo assim - o fallback deve funcionar
    }
  }

  // Inicializar Google Mobile Ads
  if (!kIsWeb) {
    try {
      final status = await MobileAds.instance.initialize();
      Logger.info('Google Mobile Ads inicializado com sucesso');
      status.adapterStatuses.forEach((adapter, adapterStatus) {
        Logger.debug('Adapter: $adapter, State: ${adapterStatus.state}');
      });
      // Aguardar um pouco para garantir que o SDK está completamente pronto
      // O SDK pode precisar de tempo adicional após initialize() retornar
      await Future.delayed(const Duration(milliseconds: 500));
      // Marcar como inicializado para que os componentes possam usar
      AdService.markInitialized();
      Logger.info('Google Mobile Ads marcado como pronto para uso');
    } catch (e, stackTrace) {
      Logger.error('Erro ao inicializar Google Mobile Ads', e, stackTrace);
    }
  }

  // Inicializar NotificationService foi movido para MyApp.initState
  // para garantir que o contexto esteja pronto (embora não seja estritamente necessário para Firebase,
  // ajuda com permissões e notificações locais em alguns casos)

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = FlutterFlowTheme.themeMode;

  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;
  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();
  @override
  void initState() {
    super.initState();

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
    
    // Inicializar RouteTrackerService com o router
    RouteTrackerService().initializeWithRouter(_router);

    // Inicializar NotificationService
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initNotifications();
      });
    }
  }

  Future<void> _initNotifications() async {
    try {
      Logger.info('Inicializando NotificationService no MyApp...');
      await NotificationService().initialize();
      Logger.info('NotificationService inicializado');
    } catch (e, stackTrace) {
      Logger.error('Erro ao inicializar NotificationService', e, stackTrace);
    }
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
        FlutterFlowTheme.saveThemeMode(mode);
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'AvaliaFotos',
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
        fontFamily: 'Poppins',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: false,
        fontFamily: 'Poppins',
      ),
      themeMode: _themeMode,
      routerConfig: _router,
    );
  }
}

class NavBarPage extends StatefulWidget {
  NavBarPage({
    Key? key,
    this.initialPage,
    this.page,
    this.disableResizeToAvoidBottomInset = false,
  }) : super(key: key);

  final String? initialPage;
  final Widget? page;
  final bool disableResizeToAvoidBottomInset;

  @override
  _NavBarPageState createState() => _NavBarPageState();
}

/// This is the private State class that goes with NavBarPage.
class _NavBarPageState extends State<NavBarPage> {
  String _currentPageName = 'feed';
  late Widget? _currentPage;
  final ValueNotifier<int> _feedScrollToTopTrigger = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _currentPageName = widget.initialPage ?? _currentPageName;
    _currentPage = widget.page;
  }

  @override
  void dispose() {
    _feedScrollToTopTrigger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = {
      'feed': FeedWidget(scrollToTopTrigger: _feedScrollToTopTrigger),
      'painel': PainelWidget(),
      'avalia': AvaliaWidget(),
      'historico': HistoricoWidget(),
      'ranking': RankingWidget(),
    };
    final currentIndex = tabs.keys.toList().indexOf(_currentPageName);

    void onNavTap(int i) {
      if (i == 0 && currentIndex == 0) {
        _feedScrollToTopTrigger.value++;
      }
      safeSetState(() {
        _currentPage = null;
        _currentPageName = tabs.keys.toList()[i];
      });
    }

    Widget buildNavItem(int index, IconData iconData) {
      final theme = FlutterFlowTheme.of(context);
      final isSelected = currentIndex == index;
      return Expanded(
        child: InkWell(
          onTap: () => onNavTap(index),
          child: SizedBox(
            height: 60,
            child: Center(
              child: Icon(
                iconData,
                size: 24.0,
                color: isSelected ? theme.primary : theme.secondaryText,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: !widget.disableResizeToAvoidBottomInset,
      body: _currentPage ?? tabs[_currentPageName],
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF303030)
                : const Color(0xFFFAFAFA),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Row(
                children: [
                  buildNavItem(0, Icons.home_outlined),
                  buildNavItem(1, Icons.dashboard_outlined),
                  const Expanded(child: SizedBox()),
                  buildNavItem(3, Icons.history),
                  buildNavItem(4, Icons.workspace_premium),
                ],
              ),
              Positioned(
                top: -16,
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => onNavTap(2),
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: FlutterFlowTheme.of(context).primary,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x26000000),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.image_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
