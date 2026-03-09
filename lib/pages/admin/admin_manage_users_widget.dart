// lib/pages/admin/admin_manage_users_widget.dart
import 'dart:async';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../services/admin_user_service.dart';
import '../../services/report_service.dart';
import '../../utils/logger.dart';
import 'admin_manage_users_model.dart';
export 'admin_manage_users_model.dart';

class AdminManageUsersWidget extends StatefulWidget {
  const AdminManageUsersWidget({super.key});

  static String routeName = 'admin_manage_users';
  static String routePath = '/admin/manage-users';

  @override
  State<AdminManageUsersWidget> createState() => _AdminManageUsersWidgetState();
}

class _AdminManageUsersWidgetState extends State<AdminManageUsersWidget> {
  late AdminManageUsersModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  AdminUserService? _adminUserService;
  ReportService? _reportService;
  bool _servicesInitialized = false;
  bool _isAdmin = false;

  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdminManageUsersModel());
    _searchController.addListener(_onSearchChanged);
    _initializeServices();
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (_searchController.text.trim().length >= 4) {
        _search();
      } else {
        safeSetState(() {
          _model.searchResults = [];
        });
      }
    });
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _reportService = ReportService(supabaseService);

      final isAdmin = await _reportService!.isCurrentUserAdmin();
      if (!isAdmin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Acesso negado. Apenas administradores podem acessar esta página.'),
              backgroundColor: FlutterFlowTheme.of(context).error,
            ),
          );
          context.safePop();
        }
        return;
      }

      _adminUserService = AdminUserService(supabaseService);

      safeSetState(() {
        _isAdmin = true;
        _servicesInitialized = true;
      });
    } catch (e, stackTrace) {
      Logger.error('Erro ao inicializar serviços', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _search() async {
    if (_adminUserService == null) return;

    final query = _searchController.text.trim();
    if (query.length < 4) return;

    safeSetState(() {
      _model.isLoading = true;
      _model.searchResults = [];
    });

    try {
      final results = await _adminUserService!.searchUsers(query);
      safeSetState(() {
        _model.searchResults = results;
        _model.isLoading = false;
      });
    } catch (e) {
      Logger.error('Erro ao buscar usuários', e, StackTrace.current);
      safeSetState(() => _model.isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: FlutterFlowTheme.of(context).error),
        );
      }
    }
  }

  void _navigateToEditUser(String userId) {
    context.push('/admin/manage-users/$userId');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: FlutterFlowTheme.of(context).primaryText),
            onPressed: () => context.safePop(),
          ),
          title: Text(
            'Gerenciar Usuários',
            style: FlutterFlowTheme.of(context).titleLarge.override(
                  font: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  letterSpacing: 0.0,
                ),
          ),
        ),
        body: !_servicesInitialized
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Buscar por nome ou email',
                          hintText: 'Digite pelo menos 4 caracteres...',
                          prefixIcon: Icon(
                            Icons.search,
                            color: FlutterFlowTheme.of(context).secondaryText,
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onSubmitted: (_) {
                          if (_searchController.text.trim().length >= 4) _search();
                        },
                      ),
                    ),
                    if (_searchController.text.trim().length > 0 && _searchController.text.trim().length < 4)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Digite pelo menos 4 caracteres para buscar',
                          style: FlutterFlowTheme.of(context).bodySmall.override(
                                font: GoogleFonts.poppins(),
                                color: FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                              ),
                        ),
                      ),
                    if (_model.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (!_model.isLoading && _model.searchResults.isNotEmpty)
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _model.searchResults.length,
                          itemBuilder: (context, index) {
                            final u = _model.searchResults[index];
                            final userId = u['id'] as String?;
                            if (userId == null) return const SizedBox.shrink();
                            return ListTile(
                              title: Text(
                                u['username'] as String? ?? u['email'] as String? ?? 'Sem nome',
                                style: FlutterFlowTheme.of(context).titleSmall.override(
                                      font: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                                      letterSpacing: 0.0,
                                    ),
                              ),
                              subtitle: Text(
                                u['email'] as String? ?? '',
                                style: FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.poppins(),
                                      color: FlutterFlowTheme.of(context).secondaryText,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: FlutterFlowTheme.of(context).secondaryText,
                              ),
                              onTap: () => _navigateToEditUser(userId),
                            );
                          },
                        ),
                      ),
                    if (!_model.isLoading &&
                        _searchController.text.trim().length >= 4 &&
                        _model.searchResults.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'Nenhum usuário encontrado',
                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                                  font: GoogleFonts.poppins(),
                                  color: FlutterFlowTheme.of(context).secondaryText,
                                  letterSpacing: 0.0,
                                ),
                          ),
                        ),
                      ),
                    if (!_model.isLoading && _searchController.text.trim().length < 4 && _model.searchResults.isEmpty)
                      const Expanded(
                        child: SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
