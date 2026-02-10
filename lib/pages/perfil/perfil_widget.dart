// lib/pages/perfil/perfil_widget.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/profile_service.dart';
import '../../utils/logger.dart';
import '../../services/auth_service.dart';
import '../../components/upgrade_modal.dart';
import '../../utils/plans_navigation_helper.dart';
import 'perfil_model.dart';
export 'perfil_model.dart';

class PerfilWidget extends StatefulWidget {
  const PerfilWidget({super.key});

  static String routeName = 'perfil';
  static String routePath = '/perfil';

  @override
  State<PerfilWidget> createState() => _PerfilWidgetState();
}

class _PerfilWidgetState extends State<PerfilWidget> {
  late PerfilModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late ProfileService _profileService;
  late AuthService _authService;
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PerfilModel());
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _profileService = ProfileService(supabaseService);
      _authService = AuthService(supabaseService);
      setState(() {
        _servicesInitialized = true;
      });
      _loadProfileData();
    } catch (e, stackTrace) {
      Logger.error('Erro ao inicializar serviços', e, stackTrace);
      safeSetState(() {
        _model.errorMessage = 'Erro ao inicializar serviços: $e';
        _model.isLoading = false;
      });
    }
  }

  Future<void> _loadProfileData() async {
    if (!_servicesInitialized) return;

    safeSetState(() {
      _model.isLoading = true;
      _model.errorMessage = null;
    });

    try {
      final supabaseService = await SupabaseService.getInstance();
      final client = supabaseService.client;
      
      // Buscar dados do perfil
      final stats = await _profileService.getProfileStats();
      
      // Buscar configuração habilitar_planos
      bool habilitarPlanos = false;
      try {
        final configResponse = await client
            .from('system_configuration')
            .select('habilitar_planos')
            .limit(1)
            .maybeSingle();
        
        if (configResponse != null) {
          habilitarPlanos = configResponse['habilitar_planos'] as bool? ?? false;
        }
      } catch (e, stackTrace) {
        Logger.warning('Erro ao buscar configuração habilitar_planos', e, stackTrace);
      }
      
      safeSetState(() {
        _model.username = stats['username'] as String?;
        _model.email = stats['email'] as String?;
        _model.avatarUrl = stats['avatar_url'] as String?;
        _model.accountCreatedAt = stats['created_at'] as DateTime;
        _model.totalPhotosEvaluated = stats['total_photos_evaluated'] as int;
        _model.planName = stats['plan_name'] as String;
        _model.planExpiresAt = stats['plan_expires_at'] as DateTime?;
        _model.isFreePlan = stats['is_free_plan'] as bool? ?? false;
        _model.habilitarPlanos = habilitarPlanos;
        _model.city = stats['city'] as String?;
        _model.state = stats['state'] as String?;
        _model.phone = stats['phone'] as String?;
        _model.isLoading = false;
      });
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar dados do perfil', e, stackTrace);
      safeSetState(() {
        _model.errorMessage = 'Erro ao carregar dados do perfil: $e';
        _model.isLoading = false;
      });
    }
  }

  Future<void> _editAvatar() async {
    try {
      final imagePicker = ImagePicker();
      final XFile? image = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image == null) return;
      if (!mounted) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar foto',
            cropStyle: CropStyle.circle,
            lockAspectRatio: true,
            initAspectRatio: CropAspectRatioPreset.square,
          ),
          IOSUiSettings(
            title: 'Recortar foto',
            cropStyle: CropStyle.circle,
            aspectRatioLockEnabled: true,
          ),
          if (kIsWeb)
            WebUiSettings(
              context: context,
              initialAspectRatio: 1,
            ),
        ],
      );

      if (croppedFile == null) return;
      if (!mounted) return;

      safeSetState(() {
        _model.isUpdatingAvatar = true;
      });

      final imageFile = File(croppedFile.path);
      final newAvatarUrl = await _profileService.updateAvatar(imageFile);

      safeSetState(() {
        _model.avatarUrl = newAvatarUrl;
        _model.isUpdatingAvatar = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Foto atualizada com sucesso!'),
            backgroundColor: FlutterFlowTheme.of(context).success,
          ),
        );
      }
    } catch (e) {
      safeSetState(() {
        _model.isUpdatingAvatar = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar foto: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _editUsername() async {
    final currentUsername = TextEditingController(text: _model.username ?? '');
    
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 20.0),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20.0),
              topRight: Radius.circular(20.0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Editar Username',
                style: FlutterFlowTheme.of(context).titleLarge.override(
                      font: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                      letterSpacing: 0.0,
                    ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 16.0),
                child: TextField(
                  controller: currentUsername,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    hintText: 'Digite seu username',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancelar'),
                  ),
                  SizedBox(width: 8.0),
                  FFButtonWidget(
                    onPressed: () async {
                      final newUsername = currentUsername.text.trim();
                      if (newUsername.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Username não pode estar vazio'),
                            backgroundColor: FlutterFlowTheme.of(context).error,
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).pop(newUsername);
                    },
                    text: 'Salvar',
                    options: FFButtonOptions(
                      height: 40.0,
                      padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                      color: FlutterFlowTheme.of(context).primary,
                      textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                            font: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                            color: Colors.white,
                            letterSpacing: 0.0,
                          ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null || result.isEmpty) return;

    safeSetState(() {
      _model.isUpdatingUsername = true;
    });

    try {
      await _profileService.updateUsername(result);
      safeSetState(() {
        _model.username = result;
        _model.isUpdatingUsername = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Username atualizado com sucesso!'),
            backgroundColor: FlutterFlowTheme.of(context).success,
          ),
        );
      }
    } catch (e) {
      safeSetState(() {
        _model.isUpdatingUsername = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar username: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _editContactInfo() async {
    final cityController = TextEditingController(text: _model.city ?? '');
    final stateController = TextEditingController(text: _model.state ?? '');
    final phoneController = TextEditingController(text: _model.phone ?? '');

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 20.0),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20.0),
              topRight: Radius.circular(20.0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Editar Informações de Contato',
                style: FlutterFlowTheme.of(context).titleLarge.override(
                      font: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                      letterSpacing: 0.0,
                    ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                child: TextField(
                  controller: cityController,
                  decoration: InputDecoration(
                    labelText: 'Cidade',
                    hintText: 'Digite sua cidade',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.length > 100) {
                      cityController.text = value.substring(0, 100);
                      cityController.selection = TextSelection.fromPosition(
                        TextPosition(offset: cityController.text.length),
                      );
                    }
                  },
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                child: TextField(
                  controller: stateController,
                  decoration: InputDecoration(
                    labelText: 'Estado (UF)',
                    hintText: 'Ex: SP',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  maxLength: 2,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (value) {
                    stateController.text = value.toUpperCase();
                    stateController.selection = TextSelection.fromPosition(
                      TextPosition(offset: stateController.text.length),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 16.0),
                child: TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Modelo de celular',
                    hintText: 'Ex: iPhone 15, Samsung Galaxy',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  keyboardType: TextInputType.text,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancelar'),
                  ),
                  SizedBox(width: 8.0),
                  FFButtonWidget(
                    onPressed: () {
                      Navigator.of(context).pop({
                        'city': cityController.text.trim(),
                        'state': stateController.text.trim(),
                        'phone': phoneController.text.trim(),
                      });
                    },
                    text: 'Salvar',
                    options: FFButtonOptions(
                      height: 40.0,
                      padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                      color: FlutterFlowTheme.of(context).primary,
                      textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                            font: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                            color: Colors.white,
                            letterSpacing: 0.0,
                          ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;

    safeSetState(() {
      _model.isUpdatingContactInfo = true;
    });

    try {
      await _profileService.updateContactInfo(
        city: result['city'],
        state: result['state'],
        phone: result['phone'],
      );
      safeSetState(() {
        _model.city = result['city']!.isEmpty ? null : result['city'];
        _model.state = result['state']!.isEmpty ? null : result['state'];
        _model.phone = result['phone']!.isEmpty ? null : result['phone'];
        _model.isUpdatingContactInfo = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Informações atualizadas com sucesso!'),
            backgroundColor: FlutterFlowTheme.of(context).success,
          ),
        );
      }
    } catch (e) {
      safeSetState(() {
        _model.isUpdatingContactInfo = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar informações: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool currentPasswordVisible = false;
    bool newPasswordVisible = false;
    bool confirmPasswordVisible = false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 20.0),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Alterar Senha',
                  style: FlutterFlowTheme.of(context).titleLarge.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                        letterSpacing: 0.0,
                      ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                  child: TextField(
                    controller: currentPasswordController,
                    obscureText: !currentPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Senha Atual',
                      hintText: 'Digite sua senha atual',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          currentPasswordVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            currentPasswordVisible = !currentPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                  child: TextField(
                    controller: newPasswordController,
                    obscureText: !newPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Nova Senha',
                      hintText: 'Digite sua nova senha',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          newPasswordVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            newPasswordVisible = !newPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 16.0),
                  child: TextField(
                    controller: confirmPasswordController,
                    obscureText: !confirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Confirmar Nova Senha',
                      hintText: 'Digite novamente a nova senha',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          confirmPasswordVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            confirmPasswordVisible = !confirmPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('Cancelar'),
                    ),
                    SizedBox(width: 8.0),
                    FFButtonWidget(
                      onPressed: () async {
                        final currentPassword = currentPasswordController.text.trim();
                        final newPassword = newPasswordController.text.trim();
                        final confirmPassword = confirmPasswordController.text.trim();

                        if (currentPassword.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Por favor, digite sua senha atual'),
                              backgroundColor: FlutterFlowTheme.of(context).error,
                            ),
                          );
                          return;
                        }

                        if (newPassword.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Por favor, digite a nova senha'),
                              backgroundColor: FlutterFlowTheme.of(context).error,
                            ),
                          );
                          return;
                        }

                        if (newPassword.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('A nova senha deve ter pelo menos 6 caracteres'),
                              backgroundColor: FlutterFlowTheme.of(context).error,
                            ),
                          );
                          return;
                        }

                        if (newPassword != confirmPassword) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('As senhas não coincidem'),
                              backgroundColor: FlutterFlowTheme.of(context).error,
                            ),
                          );
                          return;
                        }

                        Navigator.of(context).pop(true);
                      },
                      text: 'Salvar',
                      options: FFButtonOptions(
                        height: 40.0,
                        padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                        color: FlutterFlowTheme.of(context).primary,
                        textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                              font: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                              color: Colors.white,
                              letterSpacing: 0.0,
                            ),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != true) return;

    safeSetState(() {
      _model.isChangingPassword = true;
    });

    try {
      await _authService.updatePassword(
        currentPassword: currentPasswordController.text.trim(),
        newPassword: newPasswordController.text.trim(),
      );

      safeSetState(() {
        _model.isChangingPassword = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Senha alterada com sucesso!'),
            backgroundColor: FlutterFlowTheme.of(context).success,
          ),
        );
      }
    } catch (e) {
      safeSetState(() {
        _model.isChangingPassword = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao alterar senha: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final confirmController = TextEditingController();
    bool canDelete = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 20.0),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: FlutterFlowTheme.of(context).error,
                  size: 48.0,
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                  child: Text(
                    'Excluir Conta',
                    style: FlutterFlowTheme.of(context).titleLarge.override(
                          font: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                          color: FlutterFlowTheme.of(context).error,
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 16.0),
                  child: Text(
                    'Ao deletar sua conta, todas as informações, fotos e tudo que você tem no app serão apagados permanentemente. Esta ação não pode ser desfeita.',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.poppins(),
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
                TextField(
                  controller: confirmController,
                  decoration: InputDecoration(
                    labelText: 'Digite "DELETAR" para confirmar',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      canDelete = value.trim().toUpperCase() == 'DELETAR';
                    });
                  },
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancelar'),
                      ),
                      SizedBox(width: 8.0),
                      FFButtonWidget(
                        onPressed: canDelete && !_model.isDeletingAccount
                            ? () async {
                                Navigator.of(context).pop();
                                await _deleteAccount();
                              }
                            : null,
                        text: 'DELETAR',
                        options: FFButtonOptions(
                          height: 40.0,
                          padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                          color: FlutterFlowTheme.of(context).error,
                          textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                font: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                                color: Colors.white,
                                letterSpacing: 0.0,
                              ),
                          borderRadius: BorderRadius.circular(8.0),
                          disabledColor: FlutterFlowTheme.of(context).alternate,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    safeSetState(() {
      _model.isDeletingAccount = true;
    });

    try {
      await _profileService.deleteAccount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conta deletada com sucesso'),
            backgroundColor: FlutterFlowTheme.of(context).success,
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      safeSetState(() {
        _model.isDeletingAccount = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao deletar conta: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Sair',
          style: FlutterFlowTheme.of(context).titleMedium.override(
                font: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
                letterSpacing: 0.0,
              ),
        ),
        content: Text(
          'Tem certeza que deseja sair?',
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                font: GoogleFonts.poppins(),
                letterSpacing: 0.0,
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Sair',
              style: TextStyle(color: FlutterFlowTheme.of(context).error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _authService.signOut();
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao fazer logout: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 24.0,
            ),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Perfil',
            style: FlutterFlowTheme.of(context).titleLarge.override(
                  font: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                  letterSpacing: 0.0,
                ),
          ),
          centerTitle: false,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: _model.isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                )
              : _model.errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: FlutterFlowTheme.of(context).error,
                            size: 48,
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                            child: Text(
                              _model.errorMessage!,
                              textAlign: TextAlign.center,
                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.poppins(),
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                            child: FFButtonWidget(
                              onPressed: _loadProfileData,
                              text: 'Tentar Novamente',
                              options: FFButtonOptions(
                                height: 40.0,
                                padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                                color: FlutterFlowTheme.of(context).primary,
                                textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                      font: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      color: Colors.white,
                                      letterSpacing: 0.0,
                                    ),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(20.0, 24.0, 20.0, 24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            // Header Section - Foto e Username
                            Column(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      width: 120.0,
                                      height: 120.0,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: FlutterFlowTheme.of(context).primary,
                                          width: 3.0,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: _model.avatarUrl != null && _model.avatarUrl!.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: _model.avatarUrl!,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => Container(
                                                  color: FlutterFlowTheme.of(context).alternate,
                                                  child: Icon(
                                                    Icons.person,
                                                    size: 60,
                                                    color: FlutterFlowTheme.of(context).secondary,
                                                  ),
                                                ),
                                                errorWidget: (context, url, error) => Container(
                                                  color: FlutterFlowTheme.of(context).alternate,
                                                  child: Icon(
                                                    Icons.person,
                                                    size: 60,
                                                    color: FlutterFlowTheme.of(context).secondary,
                                                  ),
                                                ),
                                              )
                                            : Container(
                                                color: FlutterFlowTheme.of(context).alternate,
                                                child: Icon(
                                                  Icons.person,
                                                  size: 60,
                                                  color: FlutterFlowTheme.of(context).secondary,
                                                ),
                                              ),
                                      ),
                                    ),
                                    if (_model.isUpdatingAvatar)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.black.withOpacity(0.5),
                                          ),
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: _editAvatar,
                                          child: Container(
                                            width: 36.0,
                                            height: 36.0,
                                            decoration: BoxDecoration(
                                              color: FlutterFlowTheme.of(context).primary,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: FlutterFlowTheme.of(context).primaryBackground,
                                                width: 2.0,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.edit,
                                              color: Colors.white,
                                              size: 18.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _model.username ?? 'Sem username',
                                        style: FlutterFlowTheme.of(context).titleLarge.override(
                                              font: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                              ),
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                      if (_model.isFreePlan)
                                        Padding(
                                          padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 0.0, 0.0),
                                          child: GestureDetector(
                                            onTap: () {
                                              UpgradeModal.show(
                                                context,
                                                title: 'Upgrade para Planos Pagos',
                                                message: 'Desbloqueie todo o potencial do app com avaliações ilimitadas e armazenamento sem limites!',
                                                benefits: [
                                                  'Avaliações ilimitadas por mês',
                                                  'Armazenamento ilimitado de fotos',
                                                  'Sem interrupções no seu fluxo de trabalho',
                                                  'Acesso a todas as funcionalidades premium',
                                                ],
                                              );
                                            },
                                            child: Container(
                                              padding: EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
                                              decoration: BoxDecoration(
                                                color: FlutterFlowTheme.of(context).primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: FlutterFlowTheme.of(context).primary,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.star_rounded,
                                                    size: 14,
                                                    color: FlutterFlowTheme.of(context).primary,
                                                  ),
                                                  Padding(
                                                    padding: EdgeInsetsDirectional.fromSTEB(4, 0, 0, 0),
                                                    child: Text(
                                                      'Free',
                                                      style: FlutterFlowTheme.of(context).bodySmall.override(
                                                            font: GoogleFonts.poppins(
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                            color: FlutterFlowTheme.of(context).primary,
                                                            fontSize: 11,
                                                            letterSpacing: 0.0,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (_model.isUpdatingUsername)
                                        Padding(
                                          padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 0.0, 0.0),
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              color: FlutterFlowTheme.of(context).primary,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      else
                                        Padding(
                                          padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 0.0, 0.0),
                                          child: GestureDetector(
                                            onTap: _editUsername,
                                            child: Icon(
                                              Icons.edit,
                                              color: FlutterFlowTheme.of(context).primary,
                                              size: 20.0,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 0.0),
                                  child: Text(
                                    _model.email ?? '',
                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                          font: GoogleFonts.poppins(),
                                          color: FlutterFlowTheme.of(context).secondary,
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                ),
                                // Informações de contato
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 16.0),
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context).secondaryBackground,
                                      borderRadius: BorderRadius.circular(12.0),
                                      border: Border.all(
                                        color: FlutterFlowTheme.of(context).alternate,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Informações de contato',
                                              style: FlutterFlowTheme.of(context).titleSmall.override(
                                                    font: GoogleFonts.poppins(
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    letterSpacing: 0.0,
                                                  ),
                                            ),
                                            if (_model.isUpdatingContactInfo)
                                              SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  color: FlutterFlowTheme.of(context).primary,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            else
                                              GestureDetector(
                                                onTap: _editContactInfo,
                                                child: Icon(
                                                  Icons.edit,
                                                  color: FlutterFlowTheme.of(context).primary,
                                                  size: 20.0,
                                                ),
                                              ),
                                          ],
                                        ),
                                        if ((_model.city != null && _model.city!.isNotEmpty) ||
                                            (_model.state != null && _model.state!.isNotEmpty) ||
                                            (_model.phone != null && _model.phone!.isNotEmpty)) ...[
                                          Padding(
                                            padding: EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 0.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (_model.city != null && _model.city!.isNotEmpty)
                                                  Padding(
                                                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 4.0),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.location_city_outlined,
                                                          color: FlutterFlowTheme.of(context).secondary,
                                                          size: 18.0,
                                                        ),
                                                        Padding(
                                                          padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 0.0, 0.0),
                                                          child: Text(
                                                            '${_model.city}${_model.state != null && _model.state!.isNotEmpty ? ' - ${_model.state}' : ''}',
                                                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                  font: GoogleFonts.poppins(),
                                                                  letterSpacing: 0.0,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (_model.state != null && _model.state!.isNotEmpty && (_model.city == null || _model.city!.isEmpty))
                                                  Padding(
                                                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 4.0),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.map_outlined,
                                                          color: FlutterFlowTheme.of(context).secondary,
                                                          size: 18.0,
                                                        ),
                                                        Padding(
                                                          padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 0.0, 0.0),
                                                          child: Text(
                                                            'UF: ${_model.state}',
                                                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                  font: GoogleFonts.poppins(),
                                                                  letterSpacing: 0.0,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (_model.phone != null && _model.phone!.isNotEmpty)
                                                  Padding(
                                                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 4.0),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.smartphone,
                                                          color: FlutterFlowTheme.of(context).secondary,
                                                          size: 18.0,
                                                        ),
                                                        Padding(
                                                          padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 0.0, 0.0),
                                                          child: Text(
                                                            _model.phone!,
                                                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                  font: GoogleFonts.poppins(),
                                                                  letterSpacing: 0.0,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ] else
                                          Padding(
                                            padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 0.0),
                                            child: Text(
                                              'Nenhuma informação preenchida',
                                              style: FlutterFlowTheme.of(context).bodySmall.override(
                                                    font: GoogleFonts.poppins(),
                                                    color: FlutterFlowTheme.of(context).secondary,
                                                    letterSpacing: 0.0,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Estatísticas Section
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(0.0, 32.0, 0.0, 0.0),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 20.0),
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context).secondaryBackground,
                                  borderRadius: BorderRadius.circular(16.0),
                                  border: Border.all(
                                    color: FlutterFlowTheme.of(context).alternate,
                                    width: 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Estatísticas',
                                      style: FlutterFlowTheme.of(context).titleMedium.override(
                                            font: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            letterSpacing: 0.0,
                                          ),
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                                      child: Column(
                                        children: [
                                          _buildStatRow(
                                            Icons.photo_camera_outlined,
                                            'Fotos Avaliadas',
                                            '${_model.totalPhotosEvaluated}',
                                          ),
                                          Padding(
                                            padding: EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 0.0),
                                            child: _buildStatRow(
                                              Icons.calendar_today,
                                              'Conta Criada',
                                              _model.accountCreatedAt != null
                                                  ? DateFormat('dd/MM/yyyy', 'pt_BR').format(_model.accountCreatedAt!)
                                                  : 'N/A',
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 0.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildStatRow(
                                                  Icons.workspace_premium,
                                                  'Plano',
                                                  _model.planName,
                                                ),
                                                if (_model.planExpiresAt != null && !_model.isFreePlan)
                                                  Padding(
                                                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 0.0),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.calendar_today,
                                                          color: FlutterFlowTheme.of(context).primary,
                                                          size: 16.0,
                                                        ),
                                                        Expanded(
                                                          child: Padding(
                                                            padding: EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 0.0, 0.0),
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text(
                                                                  'Vencimento',
                                                                  style: FlutterFlowTheme.of(context).bodySmall.override(
                                                                        font: GoogleFonts.poppins(),
                                                                        color: FlutterFlowTheme.of(context).secondary,
                                                                        fontSize: 11.0,
                                                                        letterSpacing: 0.0,
                                                                      ),
                                                                ),
                                                                Text(
                                                                  DateFormat('dd/MM/yyyy', 'pt_BR').format(_model.planExpiresAt!),
                                                                  style: FlutterFlowTheme.of(context).bodySmall.override(
                                                                        font: GoogleFonts.poppins(
                                                                          fontWeight: FontWeight.w600,
                                                                        ),
                                                                        letterSpacing: 0.0,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (_model.isFreePlan && _model.habilitarPlanos)
                                                  Padding(
                                                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 0.0),
                                                    child: FFButtonWidget(
                                                      onPressed: () {
                                                        PlansNavigationHelper.navigateToPlans(context);
                                                      },
                                                      text: 'Ver Planos Disponíveis',
                                                      icon: Icon(
                                                        Icons.arrow_forward,
                                                        size: 18,
                                                      ),
                                                      options: FFButtonOptions(
                                                        width: double.infinity,
                                                        height: 40.0,
                                                        padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                                        iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                                        color: FlutterFlowTheme.of(context).primary,
                                                        textStyle: FlutterFlowTheme.of(context).bodySmall.override(
                                                              font: GoogleFonts.poppins(
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                              color: Colors.white,
                                                              fontSize: 12.0,
                                                              letterSpacing: 0.0,
                                                            ),
                                                        borderRadius: BorderRadius.circular(8.0),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Ações Section
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(0.0, 24.0, 0.0, 0.0),
                              child: Column(
                                children: [
                                  FFButtonWidget(
                                    onPressed: _model.isChangingPassword ? null : _changePassword,
                                    text: _model.isChangingPassword ? 'Alterando...' : 'Alterar Senha',
                                    icon: _model.isChangingPassword
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: FlutterFlowTheme.of(context).primaryText,
                                            ),
                                          )
                                        : Icon(
                                            Icons.lock_outline,
                                            size: 20,
                                          ),
                                    options: FFButtonOptions(
                                      width: double.infinity,
                                      height: 50.0,
                                      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                      iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                      color: FlutterFlowTheme.of(context).secondaryBackground,
                                      textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                            font: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            color: FlutterFlowTheme.of(context).primaryText,
                                            letterSpacing: 0.0,
                                          ),
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context).alternate,
                                        width: 1.0,
                                      ),
                                      disabledColor: FlutterFlowTheme.of(context).alternate,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                                    child: FFButtonWidget(
                                      onPressed: _handleLogout,
                                      text: 'Sair',
                                      icon: Icon(
                                        Icons.logout,
                                        size: 20,
                                      ),
                                      options: FFButtonOptions(
                                        width: double.infinity,
                                        height: 50.0,
                                        padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                        iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                        color: FlutterFlowTheme.of(context).secondaryBackground,
                                        textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                              font: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                              ),
                                              color: FlutterFlowTheme.of(context).primaryText,
                                              letterSpacing: 0.0,
                                            ),
                                        borderRadius: BorderRadius.circular(12.0),
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context).alternate,
                                          width: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                                    child: TextButton(
                                      onPressed: _model.isDeletingAccount ? null : _showDeleteAccountDialog,
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsetsDirectional.fromSTEB(16.0, 8.0, 16.0, 8.0),
                                        minimumSize: Size(0, 0),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        _model.isDeletingAccount ? 'Excluindo...' : 'Excluir Conta',
                                        style: FlutterFlowTheme.of(context).bodySmall.override(
                                              font: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w500,
                                              ),
                                              color: FlutterFlowTheme.of(context).error,
                                              fontSize: 14.0,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          color: FlutterFlowTheme.of(context).primary,
          size: 20.0,
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 0.0, 0.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        font: GoogleFonts.poppins(),
                        color: FlutterFlowTheme.of(context).secondary,
                        letterSpacing: 0.0,
                      ),
                ),
                Text(
                  value,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                        letterSpacing: 0.0,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

