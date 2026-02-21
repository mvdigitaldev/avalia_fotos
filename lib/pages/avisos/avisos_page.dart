import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../flutter_flow/flutter_flow_theme.dart';
import '../../flutter_flow/flutter_flow_util.dart';
import '../../services/supabase_service.dart';
import '../../services/announcement_service.dart';
import '../../services/report_service.dart';
import '../../services/storage_service.dart';
import '../../models/announcement_model.dart';
import '../../utils/logger.dart';

class AvisosPage extends StatefulWidget {
  const AvisosPage({super.key});

  static const routeName = 'avisos';
  static const routePath = '/avisos';

  @override
  State<AvisosPage> createState() => _AvisosPageState();
}

class _AvisosPageState extends State<AvisosPage> {
  AnnouncementService? _announcementService;
  ReportService? _reportService;
  bool _isAdmin = false;
  bool _servicesInitialized = false;
  List<AnnouncementModel> _list = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeServices();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (_hasMore && !_isLoading) _loadMore();
    }
  }

  Future<void> _initializeServices() async {
    try {
      final supabase = await SupabaseService.getInstance();
      _announcementService = AnnouncementService(supabase);
      _reportService = ReportService(supabase);
      final isAdmin = await _reportService!.isCurrentUserAdmin();
      _announcementService!.markAsSeen().catchError((_) {});
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
          _servicesInitialized = true;
          _isLoading = false;
        });
        _loadAnnouncements(refresh: true);
      }
    } catch (e, stackTrace) {
      Logger.error('Erro ao inicializar avisos', e, stackTrace);
      if (mounted) {
        setState(() {
          _servicesInitialized = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAnnouncements({bool refresh = false}) async {
    if (_announcementService == null || _isLoading) return;
    if (refresh) {
      _offset = 0;
      _list = [];
      _hasMore = true;
    }
    setState(() => _isLoading = true);
    try {
      final items = await _announcementService!.getAnnouncements(
        limit: _pageSize,
        offset: _offset,
      );
      if (mounted) {
        setState(() {
          if (refresh) {
            _list = items;
          } else {
            _list.addAll(items);
          }
          _offset += items.length;
          _hasMore = items.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar avisos', e, stackTrace);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadMore() => _loadAnnouncements(refresh: false);

  void _openCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateAnnouncementSheet(
        announcementService: _announcementService!,
        onCreated: () {
          Navigator.pop(context);
          _loadAnnouncements(refresh: true);
        },
      ),
    );
  }

  void _openEditSheet(AnnouncementModel announcement) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateAnnouncementSheet(
        announcementService: _announcementService!,
        initialAnnouncement: announcement,
        onCreated: () {
          Navigator.pop(context);
          _loadAnnouncements(refresh: true);
        },
      ),
    );
  }

  Future<void> _confirmDelete(AnnouncementModel announcement) async {
    final theme = FlutterFlowTheme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir aviso'),
        content: Text(
          'Tem certeza que deseja excluir "${announcement.title}"?',
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
      await _announcementService!.deleteAnnouncement(announcement.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aviso excluído.')),
        );
        _loadAnnouncements(refresh: true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: FlutterFlowTheme.of(context).primaryText,
            size: 30.0,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Avisos',
          style: FlutterFlowTheme.of(context).headlineMedium.override(
                font: GoogleFonts.poppins(),
                color: FlutterFlowTheme.of(context).primaryText,
                fontSize: 22.0,
              ),
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: Icon(
                Icons.add_circle_outline,
                color: FlutterFlowTheme.of(context).primary,
                size: 28.0,
              ),
              onPressed: _openCreateSheet,
              tooltip: 'Nova publicação',
            ),
        ],
        centerTitle: false,
        elevation: 0.0,
      ),
      body: !_servicesInitialized
          ? Center(
              child: CircularProgressIndicator(
                color: FlutterFlowTheme.of(context).primary,
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _loadAnnouncements(refresh: true),
              child: _isLoading && _list.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(
                        color: FlutterFlowTheme.of(context).primary,
                      ),
                    )
                  : _list.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.campaign_outlined,
                                size: 64.0,
                                color: FlutterFlowTheme.of(context).secondaryText,
                              ),
                              const SizedBox(height: 16.0),
                              Text(
                                'Nenhum aviso ainda',
                                style: FlutterFlowTheme.of(context).bodyLarge.override(
                                      font: GoogleFonts.poppins(),
                                      color: FlutterFlowTheme.of(context).secondaryText,
                                    ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          itemCount: _list.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _list.length) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(
                                    color: FlutterFlowTheme.of(context).primary,
                                  ),
                                ),
                              );
                            }
                            final item = _list[index];
                            if (item.isPinned && index == 0) {
                              return _PinnedCard(
                                announcement: item,
                                isAdmin: _isAdmin,
                                onEdit: _openEditSheet,
                                onDelete: _confirmDelete,
                              );
                            }
                            return _AnnouncementTile(
                              announcement: item,
                              isAdmin: _isAdmin,
                              onEdit: _openEditSheet,
                              onDelete: _confirmDelete,
                            );
                          },
                        ),
              ),
    );
  }
}

class _PinnedCard extends StatelessWidget {
  const _PinnedCard({
    required this.announcement,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  final AnnouncementModel announcement;
  final bool isAdmin;
  final void Function(AnnouncementModel) onEdit;
  final void Function(AnnouncementModel) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: theme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12.0),
        child: InkWell(
          onTap: () => context.push('/avisos/${announcement.id}'),
          borderRadius: BorderRadius.circular(12.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.push_pin, size: 16, color: theme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Fixado',
                            style: theme.bodySmall.override(
                              font: GoogleFonts.poppins(),
                              color: theme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        announcement.title,
                        style: theme.titleMedium.override(
                          font: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        announcement.descriptionExcerpt,
                        style: theme.bodySmall.override(
                          font: GoogleFonts.poppins(),
                          color: theme.secondaryText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 12, color: theme.secondaryText),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM/yyyy', 'pt_BR').format(announcement.createdAt),
                            style: theme.bodySmall.override(
                              font: GoogleFonts.poppins(),
                              color: theme.secondaryText,
                              fontSize: 11,
                            ),
                          ),
                          if (announcement.authorUsername != null &&
                              announcement.authorUsername!.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.person_outline, size: 12, color: theme.secondaryText),
                            const SizedBox(width: 4),
                            Text(
                              announcement.authorUsername!,
                              style: theme.bodySmall.override(
                                font: GoogleFonts.poppins(),
                                color: theme.secondaryText,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (announcement.imageUrl != null && announcement.imageUrl!.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: announcement.imageUrl!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                if (isAdmin)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: theme.primaryText),
                    onSelected: (value) {
                      if (value == 'edit') onEdit(announcement);
                      if (value == 'delete') onDelete(announcement);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({
    required this.announcement,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  final AnnouncementModel announcement;
  final bool isAdmin;
  final void Function(AnnouncementModel) onEdit;
  final void Function(AnnouncementModel) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
        child: InkWell(
          onTap: () => context.push('/avisos/${announcement.id}'),
          borderRadius: BorderRadius.circular(12.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        announcement.title,
                        style: theme.titleMedium.override(
                          font: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        announcement.descriptionExcerpt,
                        style: theme.bodySmall.override(
                          font: GoogleFonts.poppins(),
                          color: theme.secondaryText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 12, color: theme.secondaryText),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM/yyyy', 'pt_BR').format(announcement.createdAt),
                            style: theme.bodySmall.override(
                              font: GoogleFonts.poppins(),
                              color: theme.secondaryText,
                              fontSize: 11,
                            ),
                          ),
                          if (announcement.authorUsername != null &&
                              announcement.authorUsername!.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.person_outline, size: 12, color: theme.secondaryText),
                            const SizedBox(width: 4),
                            Text(
                              announcement.authorUsername!,
                              style: theme.bodySmall.override(
                                font: GoogleFonts.poppins(),
                                color: theme.secondaryText,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (announcement.imageUrl != null && announcement.imageUrl!.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: announcement.imageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                if (isAdmin)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: theme.primaryText),
                    onSelected: (value) {
                      if (value == 'edit') onEdit(announcement);
                      if (value == 'delete') onDelete(announcement);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreateAnnouncementSheet extends StatefulWidget {
  const CreateAnnouncementSheet({
    required this.announcementService,
    this.initialAnnouncement,
    required this.onCreated,
    this.onUpdated,
  });

  final AnnouncementService announcementService;
  final AnnouncementModel? initialAnnouncement;
  final VoidCallback onCreated;
  final void Function(AnnouncementModel)? onUpdated;

  @override
  State<CreateAnnouncementSheet> createState() => _CreateAnnouncementSheetState();
}

class _CreateAnnouncementSheetState extends State<CreateAnnouncementSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();
  bool _isPinned = false;
  File? _imageFile;
  bool _isSubmitting = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final a = widget.initialAnnouncement;
    if (a != null) {
      _titleController.text = a.title;
      _descriptionController.text = a.description;
      _linkController.text = a.link ?? '';
      _isPinned = a.isPinned;
    }
    _initialized = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final supabase = await SupabaseService.getInstance();
    final storage = StorageService(supabase);
    final xFile = await storage.pickImage(source: ImageSource.gallery);
    if (xFile != null && mounted) {
      setState(() => _imageFile = File(xFile.path));
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Título é obrigatório')),
      );
      return;
    }
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Descrição é obrigatória')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final link = _linkController.text.trim();
      final existing = widget.initialAnnouncement;
      if (existing != null) {
        String? imageUrl = existing.imageUrl;
        if (_imageFile != null) {
          imageUrl = await widget.announcementService.uploadAnnouncementImage(_imageFile!);
        }
        final updated = await widget.announcementService.updateAnnouncement(
          id: existing.id,
          title: title,
          description: description,
          imageUrl: imageUrl,
          link: link.isEmpty ? null : link,
          isPinned: _isPinned,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aviso atualizado.')),
          );
          widget.onUpdated?.call(updated);
          widget.onCreated();
        }
      } else {
        String? imageUrl;
        if (_imageFile != null) {
          imageUrl = await widget.announcementService.uploadAnnouncementImage(_imageFile!);
        }
        final announcement = await widget.announcementService.createAnnouncement(
          title: title,
          description: description,
          imageUrl: imageUrl,
          link: link.isEmpty ? null : link,
          isPinned: _isPinned,
        );
        final supabase = await SupabaseService.getInstance();
        final body = description.length > 200
            ? '${description.substring(0, 200)}...'
            : description;
        await supabase.client.functions.invoke(
          'send-push-notification',
          body: {
            'title': title,
            'body': body,
            'broadcast': true,
            'data': {
              'type': 'announcement',
              'announcement_id': announcement.id,
            },
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Publicação criada e notificação enviada.'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onCreated();
        }
      }
    } catch (e, stackTrace) {
      Logger.error('Erro ao salvar aviso', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initialAnnouncement == null ? 'Nova publicação' : 'Editar publicação',
              style: theme.headlineSmall.override(
                font: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título *',
                border: OutlineInputBorder(),
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição *',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _linkController,
              decoration: const InputDecoration(
                labelText: 'Link externo (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 1,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(_imageFile != null ? 'Imagem selecionada' : 'Adicionar imagem (opcional)'),
            ),
            if (_imageFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: theme.success, size: 20),
                    const SizedBox(width: 8),
                    Text('Imagem anexada', style: theme.bodySmall),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Fixar publicação'),
              subtitle: const Text('Aparece em destaque no topo'),
              value: _isPinned,
              onChanged: (v) => setState(() => _isPinned = v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.initialAnnouncement == null ? 'Publicar' : 'Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
