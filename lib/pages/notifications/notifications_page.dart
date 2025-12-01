import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:go_router/go_router.dart';
import '../../flutter_flow/flutter_flow_theme.dart';
import '../../services/notification_service.dart';
import '../../models/notification_model.dart';
import '../../utils/logger.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  static const routeName = 'notifications';
  static const routePath = '/notifications';

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _scrollController.addListener(_onScroll);
    
    // Marcar todas como lidas ao abrir a tela
    _markAllAsRead();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (_hasMore && !_isLoading) {
        _loadNotifications();
      }
    }
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _notifications = [];
        _hasMore = true;
      });
    }

    try {
      final data = await _notificationService.getNotifications(
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );

      final newNotifications = data
          .map((json) => NotificationModel.fromJson(json))
          .toList();

      if (mounted) {
        setState(() {
          if (refresh) {
            _notifications = newNotifications;
          } else {
            _notifications.addAll(newNotifications);
          }
          _hasMore = newNotifications.length == _pageSize;
          _currentPage++;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar notificações', e, stackTrace);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    await _notificationService.markAllAsRead();
  }

  Future<void> _clearNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar notificações'),
        content: const Text('Tem certeza que deseja apagar todas as notificações?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _notificationService.clearNotifications();
      if (mounted) {
        setState(() {
          _notifications = [];
        });
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
          'Notificações',
          style: FlutterFlowTheme.of(context).headlineMedium.override(
                font: GoogleFonts.poppins(),
                color: FlutterFlowTheme.of(context).primaryText,
                fontSize: 22.0,
              ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: FlutterFlowTheme.of(context).primaryText,
            ),
            onPressed: _notifications.isEmpty ? null : _clearNotifications,
            tooltip: 'Limpar tudo',
          ),
        ],
        centerTitle: false,
        elevation: 0.0,
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadNotifications(refresh: true),
        child: _isLoading && _notifications.isEmpty
            ? Center(
                child: CircularProgressIndicator(
                  color: FlutterFlowTheme.of(context).primary,
                ),
              )
            : _notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64.0,
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                        const SizedBox(height: 16.0),
                        Text(
                          'Nenhuma notificação',
                          style: FlutterFlowTheme.of(context).bodyLarge.override(
                                font: GoogleFonts.poppins(),
                                color: FlutterFlowTheme.of(context).secondaryText,
                              ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    itemCount: _notifications.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (context, index) => Divider(
                      height: 1.0,
                      color: FlutterFlowTheme.of(context).alternate,
                    ),
                    itemBuilder: (context, index) {
                      if (index == _notifications.length) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(
                              color: FlutterFlowTheme.of(context).primary,
                            ),
                          ),
                        );
                      }

                      final notification = _notifications[index];
                      return _buildNotificationItem(notification);
                    },
                  ),
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    final isLike = notification.type == 'like';
    final text = isLike
        ? 'curtiu sua foto.'
        : 'comentou: "${notification.commentText ?? ''}"';

    return InkWell(
      onTap: () {
        // Navegar para a foto
        context.push('/photo-detail/${notification.resourceId}');
      },
      child: Container(
        color: notification.isRead
            ? Colors.transparent
            : FlutterFlowTheme.of(context).primary.withOpacity(0.05),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar do usuário que interagiu
            Container(
              width: 44.0,
              height: 44.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: FlutterFlowTheme.of(context).alternate,
                  width: 1.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22.0),
                child: notification.actorAvatarUrl != null
                    ? CachedNetworkImage(
                        imageUrl: notification.actorAvatarUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: FlutterFlowTheme.of(context).alternate,
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.person,
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
              ),
            ),
            const SizedBox(width: 12.0),
            // Texto da notificação
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.poppins(),
                            color: FlutterFlowTheme.of(context).primaryText,
                          ),
                      children: [
                        TextSpan(
                          text: notification.actorUsername ?? 'Alguém',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(text: text),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    timeago.format(notification.createdAt, locale: 'pt_BR'),
                    style: FlutterFlowTheme.of(context).labelSmall.override(
                          font: GoogleFonts.poppins(),
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12.0),
            // Miniatura da foto
            if (notification.photoThumbnailUrl != null)
              Container(
                width: 44.0,
                height: 44.0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.0),
                  border: Border.all(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 1.0,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4.0),
                  child: CachedNetworkImage(
                    imageUrl: notification.photoThumbnailUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: FlutterFlowTheme.of(context).alternate,
                    ),
                    errorWidget: (context, url, error) => Icon(
                      Icons.image_not_supported,
                      size: 20.0,
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
