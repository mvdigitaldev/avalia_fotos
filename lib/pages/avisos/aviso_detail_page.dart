import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../flutter_flow/flutter_flow_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/announcement_service.dart';
import '../../services/report_service.dart';
import '../../models/announcement_model.dart';
import '../../utils/logger.dart';
import 'avisos_page.dart';

class AvisoDetailPage extends StatefulWidget {
  const AvisoDetailPage({super.key});

  static const routeName = 'avisoDetail';
  static const routePath = '/avisos/:id';

  @override
  State<AvisoDetailPage> createState() => _AvisoDetailPageState();
}

class _AvisoDetailPageState extends State<AvisoDetailPage> {
  AnnouncementService? _announcementService;
  ReportService? _reportService;
  AnnouncementModel? _announcement;
  bool _isLoading = true;
  String? _error;
  bool _loadStarted = false;
  bool _isAdmin = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    final id = GoRouterState.of(context).pathParameters['id'];
    if (id != null && id.isNotEmpty) {
      _loadStarted = true;
      _load(id);
    } else {
      setState(() {
        _error = 'Aviso não encontrado';
        _isLoading = false;
      });
    }
  }

  Future<void> _load(String id) async {
    try {
      final supabase = await SupabaseService.getInstance();
      _announcementService = AnnouncementService(supabase);
      _reportService = ReportService(supabase);
      final a = await _announcementService!.getAnnouncementById(id);
      final isAdmin = await _reportService!.isCurrentUserAdmin();
      if (mounted) {
        setState(() {
          _announcement = a;
          _isAdmin = isAdmin;
          _isLoading = false;
          if (a == null) _error = 'Aviso não encontrado';
        });
      }
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar aviso', e, stackTrace);
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar';
          _isLoading = false;
        });
      }
    }
  }

  void _openEditSheet() {
    if (_announcement == null || _announcementService == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateAnnouncementSheet(
        announcementService: _announcementService!,
        initialAnnouncement: _announcement,
        onCreated: () => Navigator.pop(context),
        onUpdated: (updated) {
          setState(() => _announcement = updated);
        },
      ),
    );
  }

  Future<void> _confirmDelete() async {
    if (_announcement == null || _announcementService == null) return;
    final theme = FlutterFlowTheme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir aviso'),
        content: Text(
          'Tem certeza que deseja excluir "${_announcement!.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Excluir', style: TextStyle(color: theme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _announcementService!.deleteAnnouncement(_announcement!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aviso excluído.')),
        );
        _safePop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: $e'),
            backgroundColor: theme.error,
          ),
        );
      }
    }
  }

  void _safePop() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.primaryBackground,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: theme.primaryText,
            size: 30.0,
          ),
          onPressed: _safePop,
        ),
        title: Text(
          'Aviso',
          style: theme.headlineMedium.override(
                font: GoogleFonts.poppins(),
                color: theme.primaryText,
                fontSize: 22.0,
              ),
        ),
        actions: [
          if (_isAdmin && _announcement != null) ...[
            IconButton(
              icon: Icon(Icons.edit_outlined, color: theme.primaryText),
              onPressed: _openEditSheet,
              tooltip: 'Editar',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.primaryText),
              onPressed: _confirmDelete,
              tooltip: 'Excluir',
            ),
          ],
        ],
        centerTitle: false,
        elevation: 0.0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: theme.primary),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: theme.error),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: theme.bodyLarge.override(
                          font: GoogleFonts.poppins(),
                          color: theme.secondaryText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _safePop,
                        child: const Text('Voltar'),
                      ),
                    ],
                  ),
                )
              : _announcement == null
                  ? const SizedBox.shrink()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_announcement!.isPinned)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Icon(Icons.push_pin, size: 18, color: theme.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Publicação fixada',
                                    style: theme.bodySmall.override(
                                      font: GoogleFonts.poppins(),
                                      color: theme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 16, color: theme.secondaryText),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat("d 'de' MMM 'de' yyyy", 'pt_BR').format(_announcement!.createdAt),
                                style: theme.bodyMedium.override(
                                  font: GoogleFonts.poppins(),
                                  color: theme.secondaryText,
                                ),
                              ),
                              if (_announcement!.authorUsername != null &&
                                  _announcement!.authorUsername!.isNotEmpty) ...[
                                const SizedBox(width: 16),
                                Icon(Icons.person_outline, size: 16, color: theme.secondaryText),
                                const SizedBox(width: 6),
                                Text(
                                  _announcement!.authorUsername!,
                                  style: theme.bodyMedium.override(
                                    font: GoogleFonts.poppins(),
                                    color: theme.secondaryText,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _announcement!.title,
                            style: theme.headlineSmall.override(
                              font: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_announcement!.imageUrl != null &&
                              _announcement!.imageUrl!.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: _announcement!.imageUrl!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Text(
                            _announcement!.description,
                            style: theme.bodyLarge.override(
                              font: GoogleFonts.poppins(),
                            ),
                          ),
                          if (_announcement!.link != null &&
                              _announcement!.link!.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: () => _openLink(_announcement!.link!),
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Abrir link'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }
}
