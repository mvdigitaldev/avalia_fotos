// lib/services/content_moderation_service.dart
import '../utils/logger.dart';

class ContentModerationService {
  // Lista de palavras ofensivas e termos proibidos
  // Esta lista deve ser expandida e mantida atualizada
  static final List<String> _blockedWords = [
    // Palavrões comuns (em português)
    'caralho', 'porra', 'puta', 'fod', 'merda', 'cu', 'buceta', 'xoxota',
    'vai se foder', 'vai tomar no cu', 'vai pro inferno',
    
    // Termos racistas
    'macaco', 'preto sujo', 'negro de merda', 'crioulo', 'macaquito',
    
    // Termos sexistas/misóginos
    'vadia', 'puta', 'vagabunda', 'piranha', 'mulher de programa',
    'femi nazi', 'feminazi',
    
    // Termos nazistas/xenofóbicos
    'nazista', 'hitler', 'heil hitler', 'sieg heil',
    'judeu de merda', 'morte aos judeus',
    'imigrante de merda', 'volta pro seu país',
    
    // Termos homofóbicos
    'viado', 'bicha', 'sapatão', 'traveco', 'gay de merda',
    
    // Outros termos ofensivos
    'retardado', 'mongol', 'deficiente', 'imbecil',
  ];

  /// Verifica se o conteúdo contém palavras ofensivas
  static bool containsOffensiveContent(String content) {
    if (content.isEmpty) return false;

    final normalizedContent = content.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ') // Remove pontuação
        .replaceAll(RegExp(r'\s+'), ' ') // Normaliza espaços
        .trim();

    for (final word in _blockedWords) {
      final normalizedWord = word.toLowerCase().trim();
      
      // Verifica se a palavra está no conteúdo (como palavra completa)
      final regex = RegExp(r'\b' + RegExp.escape(normalizedWord) + r'\b', caseSensitive: false);
      if (regex.hasMatch(normalizedContent)) {
        Logger.warning('Conteúdo ofensivo detectado: $normalizedWord');
        return true;
      }
    }

    return false;
  }

  /// Filtra e substitui palavras ofensivas (não usado no momento, mas pode ser útil)
  static String filterOffensiveContent(String content) {
    String filtered = content;
    
    for (final word in _blockedWords) {
      final regex = RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false);
      filtered = filtered.replaceAll(regex, '*' * word.length);
    }

    return filtered;
  }

  /// Retorna mensagem educativa para o usuário
  static String getEducationalMessage() {
    return 'Seu comentário contém palavras ou expressões que não são permitidas em nossa comunidade. '
        'Por favor, revise seu comentário e evite linguagem ofensiva, racista, sexista, homofóbica ou que promova ódio. '
        'Valorizamos um ambiente respeitoso para todos.';
  }

  /// Valida comentário antes de publicar
  static bool validateComment(String comment) {
    if (containsOffensiveContent(comment)) {
      Logger.info('Comentário bloqueado por conteúdo ofensivo');
      return false;
    }
    return true;
  }
}



