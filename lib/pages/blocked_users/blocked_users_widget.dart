import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:go_router/go_router.dart';
import '../../flutter_flow/flutter_flow_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/block_service.dart';
import '../../utils/logger.dart';
import '../../flutter_flow/flutter_flow_widgets.dart';

class BlockedUsersWidget extends StatefulWidget {
  const BlockedUsersWidget({super.key});

  static const routeName = 'blocked-users';
  static const routePath = '/blocked-users';

  @override
  State<BlockedUsersWidget> createState() => _BlockedUsersWidgetState();
}

class _BlockedUsersWidgetState extends State<BlockedUsersWidget> {
  BlockService? _blockService;
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeService();
    // Configurar locale pt_BR para timeago
    timeago.setLocaleMessages('pt_BR', timeago.PtBrMessages());
    timeago.setDefaultLocale('pt_BR');
  }

  Future<void> _initializeService() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _blockService = BlockService(supabaseService);
      await _loadBlockedUsers();
    } catch (e, stackTrace) {
      Logger.error('Erro ao inicializar BlockService', e, stackTrace);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao carregar usuários bloqueados';
        });
      }
    }
  }

  Future<void> _loadBlockedUsers() async {
    if (_blockService == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final blockedUsers = await _blockService!.getBlockedUsers();
      if (mounted) {
        setState(() {
          _blockedUsers = blockedUsers;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar usuários bloqueados', e, stackTrace);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao carregar usuários bloqueados: $e';
        });
      }
    }
  }

  Future<void> _unblockUser(Map<String, dynamic> user) async {
    if (_blockService == null) return;

    final username = user['username'] as String? ?? 'este usuário';
    final blockedId = user['blocked_id'] as String;

    // Mostrar diálogo de confirmação
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Desbloquear usuário'),
        content: Text(
          'Tem certeza que deseja desbloquear $username? Você voltará a ver o conteúdo deste usuário.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: FlutterFlowTheme.of(context).primary,
            ),
            child: Text('Desbloquear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _blockService!.unblockUser(blockedId);

      // Remover da lista imediatamente (otimistic update)
      setState(() {
        _blockedUsers.removeWhere((u) => u['blocked_id'] == blockedId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuário desbloqueado com sucesso'),
            backgroundColor: FlutterFlowTheme.of(context).success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao desbloquear usuário: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  String _formatTimeAgo(String? createdAt) {
    if (createdAt == null) return 'Data desconhecida';
    
    try {
      final date = DateTime.parse(createdAt);
      return timeago.format(date, locale: 'pt_BR');
    } catch (e) {
      return 'Data desconhecida';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          // Preto no tema claro, branco no tema escuro
          color: FlutterFlowTheme.of(context).primaryText,
        ),
        title: Text(
          'Usuários Bloqueados',
          style: FlutterFlowTheme.of(context).headlineSmall.override(
                font: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
                letterSpacing: 0.0,
              ),
        ),
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: FlutterFlowTheme.of(context).primary,
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: FlutterFlowTheme.of(context).error,
                      ),
                      SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.poppins(),
                              letterSpacing: 0.0,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      FFButtonWidget(
                        onPressed: _loadBlockedUsers,
                        text: 'Tentar novamente',
                        options: FFButtonOptions(
                          height: 40,
                          padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                        ),
                      ),
                    ],
                  ),
                )
              : _blockedUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.block_outlined,
                            size: 64,
                            color: FlutterFlowTheme.of(context).secondary,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Você não bloqueou nenhum usuário',
                            style: FlutterFlowTheme.of(context).titleMedium.override(
                                  font: GoogleFonts.poppins(),
                                  letterSpacing: 0.0,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Usuários que você bloquear aparecerão aqui',
                            style: FlutterFlowTheme.of(context).bodySmall.override(
                                  font: GoogleFonts.poppins(),
                                  color: FlutterFlowTheme.of(context).secondary,
                                  letterSpacing: 0.0,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBlockedUsers,
                      child: ListView.builder(
                        padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 20),
                        itemCount: _blockedUsers.length,
                        itemBuilder: (context, index) {
                          final user = _blockedUsers[index];
                          final username = user['username'] as String? ?? 'Usuário';
                          final avatarUrl = user['avatar_url'] as String?;
                          final createdAt = user['created_at'] as String?;
                          final blockedId = user['blocked_id'] as String;

                          return Container(
                            margin: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 12),
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context).secondaryBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: FlutterFlowTheme.of(context).alternate,
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
                              leading: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? CircleAvatar(
                                      backgroundImage: CachedNetworkImageProvider(avatarUrl),
                                      radius: 24,
                                    )
                                  : CircleAvatar(
                                      backgroundColor: FlutterFlowTheme.of(context).alternate,
                                      radius: 24,
                                      child: Icon(
                                        Icons.person,
                                        color: FlutterFlowTheme.of(context).secondaryText,
                                      ),
                                    ),
                              title: Text(
                                username,
                                style: FlutterFlowTheme.of(context).titleSmall.override(
                                      font: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      letterSpacing: 0.0,
                                    ),
                              ),
                              subtitle: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
                                child: Text(
                                  'Bloqueado ${_formatTimeAgo(createdAt)}',
                                  style: FlutterFlowTheme.of(context).bodySmall.override(
                                        font: GoogleFonts.poppins(),
                                        color: FlutterFlowTheme.of(context).secondary,
                                        letterSpacing: 0.0,
                                      ),
                                ),
                              ),
                              trailing: FFButtonWidget(
                                onPressed: () => _unblockUser(user),
                                text: 'Desbloquear',
                                options: FFButtonOptions(
                                  height: 36,
                                  padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
                                  color: FlutterFlowTheme.of(context).primaryBackground,
                                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                        font: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        color: FlutterFlowTheme.of(context).primary,
                                        letterSpacing: 0.0,
                                      ),
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: FlutterFlowTheme.of(context).primary,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

