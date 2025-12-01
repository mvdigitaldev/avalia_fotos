import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Serviço para rastrear a rota atual do usuário
/// Útil para determinar se o usuário está em uma tela específica
class RouteTrackerService {
  static final RouteTrackerService _instance = RouteTrackerService._internal();
  factory RouteTrackerService() => _instance;
  RouteTrackerService._internal();

  String? _currentRoute;
  final List<VoidCallback> _listeners = [];

  /// Obtém a rota atual
  String? get currentRoute => _currentRoute;

  /// Verifica se o usuário está na tela de avaliação
  bool get isOnEvaluationScreen => _currentRoute == '/avalia';

  /// Atualiza a rota atual
  void updateRoute(String? route) {
    if (_currentRoute != route) {
      _currentRoute = route;
      _notifyListeners();
    }
  }

  /// Adiciona um listener para mudanças de rota
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove um listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Inicializa o rastreamento usando GoRouter
  void initializeWithRouter(GoRouter router) {
    router.routerDelegate.addListener(() {
      final route = router.routerDelegate.currentConfiguration.uri.toString();
      updateRoute(route);
    });
  }
}

