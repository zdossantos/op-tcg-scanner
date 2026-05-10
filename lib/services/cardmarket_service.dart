// Service de récupération des données via l'API OPTCG (https://optcgapi.com)
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/card_model.dart';

/// Exception du service de carte
class CardmarketException implements Exception {
  final String message;
  final bool isBlocked;

  const CardmarketException(this.message, {this.isBlocked = false});

  @override
  String toString() => 'CardmarketException: $message';
}

/// Réponse brute d'une carte depuis l'API OPTCG
class _OPTCGCard {
  final double? inventoryPrice;
  final double? marketPrice;
  final String cardName;
  final String setName;
  final String setId;
  final String rarity;
  final String cardSetId;
  final String? cardImage;

  const _OPTCGCard({
    required this.inventoryPrice,
    required this.marketPrice,
    required this.cardName,
    required this.setName,
    required this.setId,
    required this.rarity,
    required this.cardSetId,
    required this.cardImage,
  });

  factory _OPTCGCard.fromJson(Map<String, dynamic> json) {
    return _OPTCGCard(
      inventoryPrice: (json['inventory_price'] as num?)?.toDouble(),
      marketPrice: (json['market_price'] as num?)?.toDouble(),
      cardName: json['card_name'] as String? ?? 'Carte inconnue',
      setName: json['set_name'] as String? ?? 'One Piece TCG',
      setId: json['set_id'] as String? ?? '',
      rarity: json['rarity'] as String? ?? '',
      cardSetId: json['card_set_id'] as String? ?? '',
      cardImage: json['card_image'] as String?,
    );
  }
}

/// Service de données cartes via l'API OPTCG
class CardmarketService {
  static const String _baseUrl = 'https://optcgapi.com/api';

  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'User-Agent': 'OPCardScanner/1.0 (Flutter)',
  };

  /// Recherche une carte par numéro ou nom.
  ///
  /// Retourne tous les variants disponibles (normal, parallèle, alternative…)
  /// dans une liste ordonnée : version normale en premier.
  Future<List<CardModel>> searchCard({
    String? cardNumber,
    String? cardName,
  }) async {
    if (cardNumber == null && cardName == null) {
      throw const CardmarketException(
          'Numéro ou nom de carte requis pour la recherche.');
    }

    if (cardNumber != null) {
      return await _fetchAllVariants(cardNumber);
    }

    // Le nom seul ne permet pas la recherche via l'API OPTCG
    throw CardmarketException(
      'Numéro de carte non détecté (texte reconnu : "$cardName").\n'
      'Assurez-vous que le numéro au bas de la carte (ex: OP01-001) est bien visible.',
    );
  }

  /// Récupère tous les variants d'une carte (ex: normal + parallèle)
  Future<List<CardModel>> _fetchAllVariants(String cardId) async {
    final normalizedId = _normalizeCardId(cardId);
    final url = Uri.parse('$_baseUrl/sets/card/$normalizedId/');

    final body = await _makeRequest(url);

    late final List<dynamic> jsonList;
    try {
      jsonList = jsonDecode(body) as List<dynamic>;
    } catch (_) {
      throw const CardmarketException(
          'Réponse inattendue de l\'API. Veuillez réessayer.');
    }

    if (jsonList.isEmpty) {
      throw CardmarketException(
          'Aucune carte trouvée pour l\'identifiant : $normalizedId\n'
          'Vérifiez que la carte est bien dans la base OPTCG (OP01 → OP15).');
    }

    // Convertit chaque entrée JSON en CardModel
    final cards = jsonList
        .whereType<Map<String, dynamic>>()
        .map((json) {
          final c = _OPTCGCard.fromJson(json);
          return CardModel(
            id: c.cardSetId,
            name: _cleanCardName(c.cardName),
            cardNumber: c.cardSetId,
            edition: '${c.setName} (${c.setId})',
            rarity: CardRarityExtension.fromString(c.rarity),
            priceMin: c.inventoryPrice,
            priceTrend: c.marketPrice,
            imageUrl: c.cardImage,
            cardmarketUrl: _buildCardmarketUrl(c.cardSetId, c.cardName),
            scannedAt: DateTime.now(),
          );
        })
        .toList();

    // Met les versions non-parallèles en premier
    cards.sort((a, b) {
      final aParallel =
          a.name.toLowerCase().contains('parallel') ? 1 : 0;
      final bParallel =
          b.name.toLowerCase().contains('parallel') ? 1 : 0;
      return aParallel.compareTo(bParallel);
    });

    return cards;
  }

  /// Construit l'URL de recherche Cardmarket pour la carte
  String _buildCardmarketUrl(String cardSetId, String cardName) {
    // Format Cardmarket : OP01-001 → recherche par numéro de carte
    final query = Uri.encodeComponent(cardSetId);
    return 'https://www.cardmarket.com/en/OnePiece/Products/Singles?searchString=$query';
  }

  /// Normalise le numéro de carte pour l'API : OP01001 → OP01-001
  String _normalizeCardId(String raw) {
    String id = raw.trim().toUpperCase();

    if (RegExp(r'^[A-Z]{2,3}\d{2}-\d{3}$').hasMatch(id)) return id;

    final match = RegExp(r'^([A-Z]{2,3})(\d{2})(\d{3})$').firstMatch(id);
    if (match != null) {
      return '${match.group(1)}${match.group(2)}-${match.group(3)}';
    }

    return id;
  }

  /// Nettoie le nom de carte : "Roronoa Zoro (001)" → "Roronoa Zoro"
  String _cleanCardName(String name) {
    return name.replaceAll(RegExp(r'\s*\(\d{3}\)\s*$'), '').trim();
  }

  /// Effectue une requête HTTP GET avec gestion d'erreur
  Future<String> _makeRequest(Uri url) async {
    try {
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 15));

      switch (response.statusCode) {
        case 200:
          return response.body;
        case 404:
          throw const CardmarketException(
              'Carte introuvable dans la base OPTCG.\n'
              'Cette carte n\'est peut-être pas encore référencée (OP01 → OP15 supportés).');
        case 429:
          throw const CardmarketException(
            'Trop de requêtes envoyées. Veuillez patienter quelques secondes.',
            isBlocked: true,
          );
        case 500:
        case 503:
          throw const CardmarketException(
            'L\'API OPTCG est temporairement indisponible.\nRéessayez dans quelques instants.',
            isBlocked: true,
          );
        default:
          throw CardmarketException('Erreur réseau: ${response.statusCode}');
      }
    } on CardmarketException {
      rethrow;
    } catch (e) {
      throw const CardmarketException(
          'Impossible de contacter l\'API.\nVérifiez votre connexion Internet.');
    }
  }
}
