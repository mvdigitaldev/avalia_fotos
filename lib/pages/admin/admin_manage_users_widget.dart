// lib/pages/admin/admin_manage_users_widget.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../services/admin_user_service.dart';
import '../../services/report_service.dart';
import '../../services/plan_service.dart';
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
  PlanService? _planService;
  ReportService? _reportService;
  bool _servicesInitialized = false;
  bool _isAdmin = false;

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _phoneController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _searchController = TextEditingController();
  String? _selectedPlanId;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdminManageUsersModel());
    _initializeServices();
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
      _planService = PlanService(supabaseService);

      final plans = await _planService!.getAvailablePlans();
      safeSetState(() {
        _isAdmin = true;
        _servicesInitialized = true;
        _model.plans = plans.map((p) => {'id': p.id, 'name': p.name}).toList();
        if (_model.plans.isNotEmpty) _selectedPlanId = _model.plans.first['id'] as String?;
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
    if (_adminUserService == null || _searchController.text.trim().isEmpty) return;

    safeSetState(() {
      _model.isLoading = true;
      _model.searchResults = [];
      _model.selectedUser = null;
    });

    try {
      final results = await _adminUserService!.searchUserByEmail(_searchController.text.trim());
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

  void _selectUser(Map<String, dynamic> user) async {
    final userId = user['id'] as String?;
    if (userId == null) return;

    _usernameController.text = user['username'] as String? ?? '';
    _emailController.text = user['email'] as String? ?? '';
    _cityController.text = user['city'] as String? ?? '';
    _stateController.text = user['state'] as String? ?? '';
    _phoneController.text = user['phone'] as String? ?? '';
    _newPasswordController.clear();

    String? currentPlanId;
    if (_planService != null) {
      final userPlan = await _planService!.getUserPlan(userId);
      currentPlanId = userPlan?.plan.id;
    }

    safeSetState(() {
      _model.selectedUser = user;
      _selectedPlanId = currentPlanId ?? (_model.plans.isNotEmpty ? _model.plans.first['id'] as String? : null);
    });
  }

  Future<void> _save() async {
    final user = _model.selectedUser;
    if (user == null || _adminUserService == null || _planService == null) return;

    final userId = user['id'] as String?;
    if (userId == null) return;

    safeSetState(() => _model.isSaving = true);

    try {
      await _adminUserService!.updateUserData(
        userId,
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (_selectedPlanId != null) {
        await _adminUserService!.updateUserPlan(userId, _selectedPlanId!);
      }

      final newPassword = _newPasswordController.text.trim();
      if (newPassword.isNotEmpty) {
        if (newPassword.length < 6) {
          throw Exception('Senha deve ter pelo menos 6 caracteres');
        }
        await _adminUserService!.updateUserPassword(userId, newPassword);
        _newPasswordController.clear();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Dados salvos com sucesso!'),
            backgroundColor: FlutterFlowTheme.of(context).success,
          ),
        );
      }

      _selectUser({...user, 'username': _usernameController.text, 'email': _emailController.text, 'city': _cityController.text, 'state': _stateController.text, 'phone': _phoneController.text});
    } catch (e) {
      Logger.error('Erro ao salvar', e, StackTrace.current);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: FlutterFlowTheme.of(context).error),
        );
      }
    } finally {
      safeSetState(() => _model.isSaving = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _phoneController.dispose();
    _newPasswordController.dispose();
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                labelText: 'Buscar por email',
                                hintText: 'Digite o email...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onSubmitted: (_) => _search(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FFButtonWidget(
                            onPressed: _model.isLoading ? null : _search,
                            text: 'Buscar',
                            options: FFButtonOptions(
                              height: 50,
                              color: FlutterFlowTheme.of(context).primary,
                              textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                    font: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                    color: Colors.white,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      if (_model.isLoading)
                        const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator())),
                      if (!_model.isLoading && _model.searchResults.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Resultados', style: FlutterFlowTheme.of(context).titleSmall),
                        const SizedBox(height: 8),
                        ..._model.searchResults.map((u) => ListTile(
                              title: Text(u['email'] as String? ?? ''),
                              subtitle: Text(u['username'] as String? ?? ''),
                              onTap: () => _selectUser(u),
                            )),
                      ],
                      if (!_model.isLoading && _searchController.text.isNotEmpty && _model.searchResults.isEmpty && _model.selectedUser == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Text('Nenhum usuário encontrado', style: FlutterFlowTheme.of(context).bodyMedium),
                        ),
                      if (_model.selectedUser != null) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text('Editar usuário', style: FlutterFlowTheme.of(context).titleSmall),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _usernameController,
                          decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _cityController,
                          decoration: const InputDecoration(labelText: 'Cidade', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _stateController,
                          decoration: const InputDecoration(labelText: 'Estado (UF)', border: OutlineInputBorder(), counterText: ''),
                          maxLength: 2,
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneController,
                          decoration: const InputDecoration(labelText: 'Modelo de celular', border: OutlineInputBorder()),
                          keyboardType: TextInputType.text,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _newPasswordController,
                          decoration: const InputDecoration(labelText: 'Nova senha (deixe vazio para não alterar)', border: OutlineInputBorder()),
                          obscureText: true,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedPlanId,
                          decoration: const InputDecoration(labelText: 'Plano', border: OutlineInputBorder()),
                          items: _model.plans.map((p) {
                            final id = p['id'] as String;
                            final name = p['name'] as String;
                            return DropdownMenuItem(value: id, child: Text(name));
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedPlanId = v),
                        ),
                        const SizedBox(height: 24),
                        FFButtonWidget(
                          onPressed: _model.isSaving ? null : _save,
                          text: _model.isSaving ? 'Salvando...' : 'Salvar',
                          options: FFButtonOptions(
                            height: 50,
                            color: FlutterFlowTheme.of(context).primary,
                            textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                  font: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                  color: Colors.white,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
