import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/main.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/lat_lng.dart';
import '/flutter_flow/place.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'serialization_util.dart';
import '/services/supabase_service.dart';
import '/services/notification_service.dart';
import '/utils/logger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '/index.dart';

// Import PlansWidget explicitly
import '/pages/plans/plans_widget.dart';
// Import PerfilWidget explicitly
import '/pages/perfil/perfil_widget.dart';
// Import TutorialSuporteWidget explicitly
import '/pages/tutorial_suporte/tutorial_suporte_widget.dart';
// Import SignupWidget explicitly
import '/signup/signup_widget.dart';
// Import ConquistasWidget explicitly
import '/pages/conquistas/conquistas_widget.dart';
// Import InspirarWidget explicitly
import '/pages/inspirar/inspirar_widget.dart';

export 'package:go_router/go_router.dart';
export 'serialization_util.dart';

const kTransitionInfoKey = '__transition_info__';

GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppStateNotifier extends ChangeNotifier {
  AppStateNotifier._() {
    // Escutar mudanças de autenticação de forma assíncrona
    // Não inicializar aqui porque pode ser chamado antes do Supabase estar pronto
    _initializeAuthListener();
  }

  static AppStateNotifier? _instance;
  static AppStateNotifier get instance => _instance ??= AppStateNotifier._();

  bool showSplashImage = true;
  StreamSubscription<AuthState>? _authSubscription;
  bool _listenerInitialized = false;

  void _initializeAuthListener() {
    // Evitar múltiplas inicializações
    if (_listenerInitialized) return;
    
    // Inicializar listener de autenticação de forma assíncrona
    SupabaseService.getInstance().then((service) {
      if (_listenerInitialized) return; // Verificar novamente após await
      _listenerInitialized = true;
      _authSubscription = service.authStateChanges.listen((authState) async {
        // Notificar listeners quando o estado de autenticação mudar
        notifyListeners();
        
        // Gerenciar token de notificação quando usuário faz login/logout
        if (!kIsWeb) {
          try {
            final notificationService = NotificationService();
            if (authState.session != null) {
              // Usuário fez login - garantir que token está salvo
              Logger.info('=== USUÁRIO FEZ LOGIN ===');
              Logger.info('User ID: ${authState.session?.user.id}');
              
              // Aguardar um pouco para garantir que tudo está sincronizado
              await Future.delayed(const Duration(milliseconds: 1500));
              
              try {
                Logger.info('Verificando se NotificationService está inicializado...');
                if (!notificationService.isInitialized) {
                  // Se não estiver inicializado, inicializar agora
                  Logger.info('NotificationService não estava inicializado, inicializando agora...');
                  await notificationService.initialize();
                  Logger.info('NotificationService inicializado após login');
                  
                  // Aguardar mais um pouco após inicialização
                  await Future.delayed(const Duration(milliseconds: 1000));
                }
                
                Logger.info('Chamando refreshToken para salvar token FCM...');
                await notificationService.refreshToken();
                Logger.info('=== TOKEN FCM SALVO APÓS LOGIN ===');
              } catch (e, stackTrace) {
                Logger.error('=== ERRO AO SALVAR TOKEN APÓS LOGIN ===');
                Logger.error('Erro: ${e.toString()}');
                Logger.error('Stack trace: $stackTrace');
                
                // Tentar novamente após um delay maior
                Logger.info('Tentando novamente após 5 segundos...');
                await Future.delayed(const Duration(seconds: 5));
                try {
                  if (!notificationService.isInitialized) {
                    await notificationService.initialize();
                  }
                  await notificationService.refreshToken();
                } catch (e2) {
                  Logger.error('Falha na segunda tentativa: ${e2.toString()}');
                }
              }
            } else {
              // Usuário fez logout - remover token
              if (notificationService.isInitialized) {
                await notificationService.removeToken();
              }
            }
          } catch (e) {
            Logger.debug('Erro ao gerenciar token de notificação', e);
            // Não bloquear o fluxo se houver erro
          }
        }
      });
      Logger.debug('Listener de autenticação inicializado com sucesso');
    }).catchError((e, stackTrace) {
      Logger.error('Erro ao inicializar listener de autenticação', e, stackTrace);
      // Tentar novamente após um delay
      Future.delayed(const Duration(seconds: 1), () {
        if (!_listenerInitialized) {
          _initializeAuthListener();
        }
      });
    });
  }

  void stopShowingSplashImage() {
    showSplashImage = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

GoRouter createRouter(AppStateNotifier appStateNotifier) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: appStateNotifier,
    navigatorKey: appNavigatorKey,
      redirect: (context, state) {
        try {
          // Verificar se o usuário está autenticado
          // Usar try-catch porque Supabase pode não estar inicializado ainda
          final isAuthenticated = SupabaseService.isAuthenticated;
          final isLoginPage = state.uri.path == LoginWidget.routePath;
          final isSignupPage = state.uri.path == SignupWidget.routePath;
          final isAuthPage = isLoginPage || isSignupPage;
          
          // Se não está autenticado e não está em página de autenticação, redirecionar para login
          if (!isAuthenticated && !isAuthPage) {
            return LoginWidget.routePath;
          }
          
          // Se está autenticado e está em página de autenticação, redirecionar para home
          if (isAuthenticated && isAuthPage) {
            return '/';
          }
          
          // Permitir acesso
          return null;
        } catch (e) {
          // Se Supabase não está inicializado, permitir acesso à página de login
          final isLoginPage = state.uri.path == LoginWidget.routePath;
          final isSignupPage = state.uri.path == SignupWidget.routePath;
          if (isLoginPage || isSignupPage) {
            return null; // Permitir acesso às páginas de auth
          }
          return LoginWidget.routePath; // Redirecionar para login se não estiver em página de auth
        }
      },
    errorBuilder: (context, state) => NavBarPage(),
    routes: [
      FFRoute(
        name: '_initialize',
        path: '/',
        requireAuth: true,
        builder: (context, _) => NavBarPage(),
      ),
      FFRoute(
        name: FeedWidget.routeName,
        path: FeedWidget.routePath,
        requireAuth: true,
        builder: (context, params) =>
            params.isEmpty ? NavBarPage(initialPage: 'feed') : FeedWidget(),
      ),
      FFRoute(
        name: PainelWidget.routeName,
        path: PainelWidget.routePath,
        requireAuth: true,
        builder: (context, params) => params.isEmpty
            ? NavBarPage(initialPage: 'painel')
            : PainelWidget(),
      ),
      FFRoute(
        name: AvaliaWidget.routeName,
        path: AvaliaWidget.routePath,
        requireAuth: true,
        builder: (context, params) => params.isEmpty
            ? NavBarPage(initialPage: 'avalia')
            : AvaliaWidget(),
      ),
      FFRoute(
        name: HistoricoWidget.routeName,
        path: HistoricoWidget.routePath,
        requireAuth: true,
        builder: (context, params) => params.isEmpty
            ? NavBarPage(initialPage: 'historico')
            : HistoricoWidget(),
      ),
      FFRoute(
        name: RankingWidget.routeName,
        path: RankingWidget.routePath,
        requireAuth: true,
        builder: (context, params) => params.isEmpty
            ? NavBarPage(initialPage: 'ranking')
            : RankingWidget(),
      ),
        FFRoute(
          name: LoginWidget.routeName,
          path: LoginWidget.routePath,
          requireAuth: false,
          builder: (context, params) => LoginWidget(),
        ),
        FFRoute(
          name: SignupWidget.routeName,
          path: SignupWidget.routePath,
          requireAuth: false,
          builder: (context, params) => SignupWidget(),
        ),
      FFRoute(
        name: PhotoDetailWidget.routeName,
        path: PhotoDetailWidget.routePath,
        requireAuth: true,
        builder: (context, params) => PhotoDetailWidget(),
      ),
      FFRoute(
        name: PlansWidget.routeName,
        path: PlansWidget.routePath,
        requireAuth: true,
        builder: (context, params) => PlansWidget(),
      ),
      FFRoute(
        name: PerfilWidget.routeName,
        path: PerfilWidget.routePath,
        requireAuth: true,
        builder: (context, params) => PerfilWidget(),
      ),
      FFRoute(
        name: TutorialSuporteWidget.routeName,
        path: TutorialSuporteWidget.routePath,
        requireAuth: true,
        builder: (context, params) => TutorialSuporteWidget(),
      ),
      FFRoute(
        name: ConquistasWidget.routeName,
        path: ConquistasWidget.routePath,
        requireAuth: true,
        builder: (context, params) => ConquistasWidget(),
      ),
      FFRoute(
        name: InspirarWidget.routeName,
        path: InspirarWidget.routePath,
        requireAuth: true,
        builder: (context, params) => InspirarWidget(),
      )
    ].map((r) => r.toRoute(appStateNotifier)).toList(),
  );
}

extension NavParamExtensions on Map<String, String?> {
  Map<String, String> get withoutNulls => Map.fromEntries(
        entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value!)),
      );
}

extension NavigationExtensions on BuildContext {
  void safePop() {
    // If there is only one route on the stack, navigate to the initial
    // page instead of popping.
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }
}

extension _GoRouterStateExtensions on GoRouterState {
  Map<String, dynamic> get extraMap =>
      extra != null ? extra as Map<String, dynamic> : {};
  Map<String, dynamic> get allParams => <String, dynamic>{}
    ..addAll(pathParameters)
    ..addAll(uri.queryParameters)
    ..addAll(extraMap);
  TransitionInfo get transitionInfo => extraMap.containsKey(kTransitionInfoKey)
      ? extraMap[kTransitionInfoKey] as TransitionInfo
      : TransitionInfo.appDefault();
}

class FFParameters {
  FFParameters(this.state, [this.asyncParams = const {}]);

  final GoRouterState state;
  final Map<String, Future<dynamic> Function(String)> asyncParams;

  Map<String, dynamic> futureParamValues = {};

  // Parameters are empty if the params map is empty or if the only parameter
  // present is the special extra parameter reserved for the transition info.
  bool get isEmpty =>
      state.allParams.isEmpty ||
      (state.allParams.length == 1 &&
          state.extraMap.containsKey(kTransitionInfoKey));
  bool isAsyncParam(MapEntry<String, dynamic> param) =>
      asyncParams.containsKey(param.key) && param.value is String;
  bool get hasFutures => state.allParams.entries.any(isAsyncParam);
  Future<bool> completeFutures() => Future.wait(
        state.allParams.entries.where(isAsyncParam).map(
          (param) async {
            final doc = await asyncParams[param.key]!(param.value)
                .onError((_, __) => null);
            if (doc != null) {
              futureParamValues[param.key] = doc;
              return true;
            }
            return false;
          },
        ),
      ).onError((_, __) => [false]).then((v) => v.every((e) => e));

  dynamic getParam<T>(
    String paramName,
    ParamType type, {
    bool isList = false,
  }) {
    if (futureParamValues.containsKey(paramName)) {
      return futureParamValues[paramName];
    }
    if (!state.allParams.containsKey(paramName)) {
      return null;
    }
    final param = state.allParams[paramName];
    // Got parameter from `extras`, so just directly return it.
    if (param is! String) {
      return param;
    }
    // Return serialized value.
    return deserializeParam<T>(
      param,
      type,
      isList,
    );
  }
}

class FFRoute {
  const FFRoute({
    required this.name,
    required this.path,
    required this.builder,
    this.requireAuth = false,
    this.asyncParams = const {},
    this.routes = const [],
  });

  final String name;
  final String path;
  final bool requireAuth;
  final Map<String, Future<dynamic> Function(String)> asyncParams;
  final Widget Function(BuildContext, FFParameters) builder;
  final List<GoRoute> routes;

  GoRoute toRoute(AppStateNotifier appStateNotifier) => GoRoute(
        name: name,
        path: path,
        redirect: requireAuth ? (context, state) {
          // Verificar autenticação para rotas protegidas
          final isAuthenticated = SupabaseService.isAuthenticated;
          if (!isAuthenticated) {
            return LoginWidget.routePath;
          }
          return null;
        } : null,
        pageBuilder: (context, state) {
          fixStatusBarOniOS16AndBelow(context);
          final ffParams = FFParameters(state, asyncParams);
          final page = ffParams.hasFutures
              ? FutureBuilder(
                  future: ffParams.completeFutures(),
                  builder: (context, _) => builder(context, ffParams),
                )
              : builder(context, ffParams);
          final child = page;

          final transitionInfo = state.transitionInfo;
          return transitionInfo.hasTransition
              ? CustomTransitionPage(
                  key: state.pageKey,
                  child: child,
                  transitionDuration: transitionInfo.duration,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          PageTransition(
                    type: transitionInfo.transitionType,
                    duration: transitionInfo.duration,
                    reverseDuration: transitionInfo.duration,
                    alignment: transitionInfo.alignment,
                    child: child,
                  ).buildTransitions(
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ),
                )
              : MaterialPage(key: state.pageKey, child: child);
        },
        routes: routes,
      );
}

class TransitionInfo {
  const TransitionInfo({
    required this.hasTransition,
    this.transitionType = PageTransitionType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.alignment,
  });

  final bool hasTransition;
  final PageTransitionType transitionType;
  final Duration duration;
  final Alignment? alignment;

  static TransitionInfo appDefault() => TransitionInfo(hasTransition: false);
}

class RootPageContext {
  const RootPageContext(this.isRootPage, [this.errorRoute]);
  final bool isRootPage;
  final String? errorRoute;

  static bool isInactiveRootPage(BuildContext context) {
    final rootPageContext = context.read<RootPageContext?>();
    final isRootPage = rootPageContext?.isRootPage ?? false;
    final location = GoRouterState.of(context).uri.toString();
    return isRootPage &&
        location != '/' &&
        location != rootPageContext?.errorRoute;
  }

  static Widget wrap(Widget child, {String? errorRoute}) => Provider.value(
        value: RootPageContext(true, errorRoute),
        child: child,
      );
}

extension GoRouterLocationExtension on GoRouter {
  String getCurrentLocation() {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }
}
