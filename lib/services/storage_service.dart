import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import 'supabase_service.dart';

class StorageService {
  final SupabaseService _supabaseService;
  final ImagePicker _imagePicker = ImagePicker();

  StorageService(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;

  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      return image;
    } catch (e) {
      throw Exception('Erro ao selecionar imagem: $e');
    }
  }

  Future<String> uploadPhoto({
    required File imageFile,
    required String userId,
  }) async {
    try {
      // Validar tamanho do arquivo
      final fileSize = await imageFile.length();
      if (fileSize > maxFileSize) {
        throw Exception('Arquivo muito grande. Tamanho máximo: 10MB');
      }

      // Validar extensão
      final fileName = imageFile.path.split('/').last.toLowerCase();
      final extension = fileName.split('.').last;
      if (!allowedExtensions.contains(extension)) {
        throw Exception(
          'Formato não permitido. Use: ${allowedExtensions.join(", ")}',
        );
      }

      // Gerar nome único para o arquivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueFileName = '$userId/$timestamp.$extension';

      // Upload para Supabase Storage
      await _client.storage.from('photos').upload(
            uniqueFileName,
            imageFile,
            fileOptions: const FileOptions(
              upsert: false,
              cacheControl: '3600',
            ),
          );

      // Obter URL pública
      final String publicUrl = _client.storage
          .from('photos')
          .getPublicUrl(uniqueFileName);

      return publicUrl;
    } catch (e) {
      if (e is StorageException) {
        throw Exception('Erro ao fazer upload: ${e.message}');
      }
      throw Exception('Erro ao fazer upload: $e');
    }
  }

  Future<void> deletePhoto(String imageUrl) async {
    try {
      // Extrair o caminho do arquivo da URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf('photos');
      if (bucketIndex == -1 || bucketIndex == pathSegments.length - 1) {
        throw Exception('URL inválida');
      }

      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
      await _client.storage.from('photos').remove([filePath]);
    } catch (e) {
      if (e is StorageException) {
        throw Exception('Erro ao deletar foto: ${e.message}');
      }
      throw Exception('Erro ao deletar foto: $e');
    }
  }

  Future<List<String>> deleteMultiplePhotos(List<String> imageUrls) async {
    final deletedUrls = <String>[];
    final filePaths = <String>[];

    // Extrair todos os caminhos de arquivo
    for (final imageUrl in imageUrls) {
      try {
        final uri = Uri.parse(imageUrl);
        final pathSegments = uri.pathSegments;
        final bucketIndex = pathSegments.indexOf('photos');
        if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
          final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
          filePaths.add(filePath);
        }
      } catch (e, stackTrace) {
        Logger.warning('Erro ao processar URL $imageUrl', e, stackTrace);
      }
    }

    if (filePaths.isEmpty) return deletedUrls;

    try {
      // Deletar todos os arquivos de uma vez
      await _client.storage.from('photos').remove(filePaths);
      deletedUrls.addAll(imageUrls);
    } catch (e) {
      // Se falhar em lote, tentar individualmente
      if (e is StorageException) {
        for (int i = 0; i < imageUrls.length; i++) {
          try {
            await deletePhoto(imageUrls[i]);
            deletedUrls.add(imageUrls[i]);
          } catch (individualError, stackTrace) {
            Logger.warning('Erro ao deletar foto individual ${imageUrls[i]}', individualError, stackTrace);
          }
        }
      } else {
        throw Exception('Erro ao deletar múltiplas fotos: $e');
      }
    }

    return deletedUrls;
  }
}

