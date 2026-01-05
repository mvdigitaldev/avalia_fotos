// lib/components/share_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '/flutter_flow/flutter_flow_theme.dart';

class ShareBottomSheet extends StatelessWidget {
  final String photoId;
  final String photoLink;

  const ShareBottomSheet({
    super.key,
    required this.photoId,
    required this.photoLink,
  });

  static void show(BuildContext context, String photoId) {
    final photoLink = _generatePhotoLink(photoId);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareBottomSheet(
        photoId: photoId,
        photoLink: photoLink,
      ),
    );
  }

  static String _generatePhotoLink(String photoId) {
    return 'avaliafotos://avaliafotos.com/photo-detail/$photoId';
  }

  Future<void> _shareOnWhatsApp() async {
    final text = 'Veja essa foto que publiquei no aAvaliA!🤖\n\n$photoLink';
    final encodedText = Uri.encodeComponent(text);
    final url = 'https://api.whatsapp.com/send?text=$encodedText';
    
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback para wa.me se api.whatsapp.com não funcionar
        final fallbackUri = Uri.parse('https://wa.me/?text=$encodedText');
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      // Se não conseguir abrir WhatsApp, tenta abrir no navegador web
      try {
        final fallbackUri = Uri.parse('https://wa.me/?text=$encodedText');
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      } catch (e2) {
        // Ignorar erro silenciosamente
      }
    }
  }

  Future<void> _shareOnFacebook() async {
    final encodedUrl = Uri.encodeComponent(photoLink);
    final url = 'https://www.facebook.com/sharer/sharer.php?u=$encodedUrl';
    
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Ignorar erro
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: photoLink));
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Link copiado para a área de transferência!'),
          backgroundColor: FlutterFlowTheme.of(context).success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0, 20, 0, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).alternate,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Compartilhar',
                style: FlutterFlowTheme.of(context).headlineSmall.override(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.0,
                    ),
              ),
              const SizedBox(height: 24),
              
              // Options
              _buildShareOption(
                context,
                icon: FontAwesomeIcons.whatsapp,
                label: 'Compartilhar no WhatsApp',
                color: const Color(0xFF25D366),
                onTap: _shareOnWhatsApp,
              ),
              const SizedBox(height: 12),
              _buildShareOption(
                context,
                icon: FontAwesomeIcons.facebook,
                label: 'Compartilhar no Facebook',
                color: const Color(0xFF1877F2),
                onTap: _shareOnFacebook,
              ),
              const SizedBox(height: 12),
              _buildShareOption(
                context,
                icon: Icons.link,
                label: 'Copiar link',
                color: FlutterFlowTheme.of(context).primary,
                onTap: () => _copyLink(context),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).alternate.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: FlutterFlowTheme.of(context).alternate.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: FlutterFlowTheme.of(context).bodyLarge.override(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.0,
                    ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: FlutterFlowTheme.of(context).secondaryText,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

