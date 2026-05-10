// Service de reconnaissance de texte via Google ML Kit
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Résultat de la reconnaissance d'une carte
class CardScanResult {
  /// Nom de la carte détecté (peut être null si non trouvé)
  final String? cardName;

  /// Numéro de la carte détecté (ex: OP01-001)
  final String? cardNumber;

  /// Tout le texte brut détecté sur la carte
  final String rawText;

  const CardScanResult({
    this.cardName,
    this.cardNumber,
    required this.rawText,
  });

  /// Indique si au moins un élément utile a été trouvé
  bool get isValid => cardName != null || cardNumber != null;
}

/// Service de vision pour la reconnaissance de texte sur les cartes
class VisionService {
  // Reconnaissance de texte Latin (One Piece utilise des caractères latins)
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Expression régulière pour détecter un numéro de carte One Piece
  /// Format strict : 2-3 lettres + 2 chiffres + tiret + 3 chiffres
  /// Ex: OP01-001, ST01-003, EB04-007
  ///
  /// Le regex accepte O et 0 partout car l'OCR les confond souvent.
  /// La normalisation est faite après match dans [_fixOCRConfusions].
  static final RegExp _cardNumberRegex = RegExp(
    r'[A-Za-z0O]{2,3}[0-9oO]{2}-[0-9oO]{3}',
  );

  /// Analyse une image de carte et extrait le nom et le numéro
  ///
  /// [imagePath] : chemin vers le fichier image à analyser
  /// Retourne un [CardScanResult] avec les informations détectées
  Future<CardScanResult> recognizeCard(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);

    try {
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      final String rawText = recognizedText.text;

      // Extraction du numéro de carte
      final String? cardNumber = _extractCardNumber(rawText);

      // Extraction du nom de carte (première ligne significative)
      final String? cardName = _extractCardName(recognizedText, cardNumber);

      return CardScanResult(
        cardName: cardName,
        cardNumber: cardNumber,
        rawText: rawText,
      );
    } catch (e) {
      return CardScanResult(
        rawText: 'Erreur de reconnaissance: $e',
      );
    }
  }

  /// Extrait le numéro de carte depuis tout le texte OCR.
  ///
  /// Stratégie : on concatène tout le texte en une seule chaîne,
  /// on remplace chaque caractère non alphanumérique/tiret par un espace,
  /// puis on cherche le pattern [A-Z]{2,3}[0-9]{2}-[0-9]{3} partout.
  /// Cela résiste aux parasites OCR du type "eb04-007 ) 0 \" )".
  String? _extractCardNumber(String text) {
    // Remplace tout sauf lettres, chiffres, O/0 et tirets par un espace
    final cleaned = text.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), ' ');

    final match = _cardNumberRegex.firstMatch(cleaned);
    if (match == null) return null;

    return _fixOCRConfusions(match.group(0)!.toUpperCase());
  }

  /// Corrige les confusions O/0 selon la structure du numéro de carte.
  ///
  /// Format : [LETTRES][CHIFFRES]-[CHIFFRES]
  /// - Partie préfixe (lettres) : 0 → O
  /// - Parties numériques       : O → 0
  ///
  /// Ex: "0P01-001" → "OP01-001"  /  "OP0O-OO1" → "OP00-001"
  String _fixOCRConfusions(String raw) {
    final parts = raw.split('-');
    if (parts.length != 2) return raw;

    final prefix = parts[0]; // ex: "0P01" ou "EB04"
    final suffix = parts[1]; // ex: "001"

    // Identifie la frontière lettres/chiffres dans le préfixe
    // Les 2-3 premiers caractères sont des lettres, le reste des chiffres
    final letterEnd = prefix.indexOf(RegExp(r'[0-9O]'));
    if (letterEnd <= 0) return raw;

    final letters = prefix
        .substring(0, letterEnd)
        .replaceAll('0', 'O'); // 0 → O dans la partie lettre
    final digits1 = prefix
        .substring(letterEnd)
        .replaceAll('O', '0'); // O → 0 dans la partie chiffre
    final digits2 = suffix.replaceAll('O', '0');

    return '$letters$digits1-$digits2';
  }

  /// Extrait le nom de la carte depuis le texte reconnu
  ///
  /// Sur les cartes One Piece, le nom est généralement le bloc de texte
  /// le plus grand / le plus en haut de la carte
  String? _extractCardName(RecognizedText recognizedText, String? cardNumber) {
    if (recognizedText.blocks.isEmpty) return null;

    // Trie les blocs par position verticale (y croissant = plus haut)
    final sortedBlocks = List.of(recognizedText.blocks)
      ..sort((a, b) =>
          a.boundingBox.top.compareTo(b.boundingBox.top));

    for (final block in sortedBlocks) {
      for (final line in block.lines) {
        final text = line.text.trim();

        // Ignore les lignes trop courtes ou trop longues
        if (text.length < 2 || text.length > 60) continue;

        // Ignore les lignes qui ressemblent à un numéro de carte
        if (_cardNumberRegex.hasMatch(text)) continue;

        // Ignore les lignes purement numériques (coût, puissance, etc.)
        if (RegExp(r'^\d+$').hasMatch(text)) continue;

        // Ignore les lignes qui contiennent uniquement des symboles
        if (RegExp(r'^[^a-zA-ZÀ-ÿ]+$').hasMatch(text)) continue;

        // La première ligne significative est probablement le nom
        return text;
      }
    }

    return null;
  }

  /// Libère les ressources ML Kit
  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
