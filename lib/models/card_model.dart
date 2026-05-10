// Modèle de données pour une carte One Piece TCG

/// Enumération des raretés possibles d'une carte One Piece
enum CardRarity {
  common,      // Commune
  uncommon,    // Peu commune
  rare,        // Rare
  superRare,   // Super Rare
  secretRare,  // Secret Rare
  leader,      // Leader
  unknown,     // Inconnue (si non trouvée)
}

/// Extension pour obtenir le libellé d'une rareté
extension CardRarityExtension on CardRarity {
  /// Retourne le libellé en français de la rareté
  String get label {
    switch (this) {
      case CardRarity.common:
        return 'Common';
      case CardRarity.uncommon:
        return 'Uncommon';
      case CardRarity.rare:
        return 'Rare';
      case CardRarity.superRare:
        return 'Super Rare';
      case CardRarity.secretRare:
        return 'Secret Rare';
      case CardRarity.leader:
        return 'Leader';
      case CardRarity.unknown:
        return 'Inconnue';
    }
  }

  /// Convertit une chaîne en rareté
  static CardRarity fromString(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'c' || normalized == 'common') return CardRarity.common;
    if (normalized == 'uc' || normalized == 'uncommon') return CardRarity.uncommon;
    if (normalized == 'r' || normalized == 'rare') return CardRarity.rare;
    if (normalized == 'sr' || normalized == 'super rare') return CardRarity.superRare;
    if (normalized == 'sec' || normalized == 'secret rare') return CardRarity.secretRare;
    if (normalized == 'l' || normalized == 'leader') return CardRarity.leader;
    return CardRarity.unknown;
  }
}

/// Modèle représentant une carte One Piece TCG
class CardModel {
  /// Identifiant unique de la carte (ex: OP01-001)
  final String id;

  /// Nom de la carte
  final String name;

  /// Numéro de la carte dans son édition
  final String cardNumber;

  /// Nom de l'édition / set
  final String edition;

  /// Rareté de la carte
  final CardRarity rarity;

  /// Prix minimum actuel sur Cardmarket (en euros)
  final double? priceMin;

  /// Prix tendance sur Cardmarket (en euros)
  final double? priceTrend;

  /// URL de l'image de la carte
  final String? imageUrl;

  /// URL de la page Cardmarket
  final String? cardmarketUrl;

  /// Date et heure du scan
  final DateTime scannedAt;

  const CardModel({
    required this.id,
    required this.name,
    required this.cardNumber,
    required this.edition,
    required this.rarity,
    this.priceMin,
    this.priceTrend,
    this.imageUrl,
    this.cardmarketUrl,
    required this.scannedAt,
  });

  /// Sérialise la carte en Map pour stockage JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'cardNumber': cardNumber,
      'edition': edition,
      'rarity': rarity.name,
      'priceMin': priceMin,
      'priceTrend': priceTrend,
      'imageUrl': imageUrl,
      'cardmarketUrl': cardmarketUrl,
      'scannedAt': scannedAt.toIso8601String(),
    };
  }

  /// Désérialise une carte depuis un Map JSON
  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      cardNumber: json['cardNumber'] as String? ?? '',
      edition: json['edition'] as String? ?? '',
      rarity: CardRarity.values.firstWhere(
        (r) => r.name == json['rarity'],
        orElse: () => CardRarity.unknown,
      ),
      priceMin: (json['priceMin'] as num?)?.toDouble(),
      priceTrend: (json['priceTrend'] as num?)?.toDouble(),
      imageUrl: json['imageUrl'] as String?,
      cardmarketUrl: json['cardmarketUrl'] as String?,
      scannedAt: DateTime.parse(json['scannedAt'] as String),
    );
  }

  /// Crée une copie de la carte avec des champs modifiés
  CardModel copyWith({
    String? id,
    String? name,
    String? cardNumber,
    String? edition,
    CardRarity? rarity,
    double? priceMin,
    double? priceTrend,
    String? imageUrl,
    String? cardmarketUrl,
    DateTime? scannedAt,
  }) {
    return CardModel(
      id: id ?? this.id,
      name: name ?? this.name,
      cardNumber: cardNumber ?? this.cardNumber,
      edition: edition ?? this.edition,
      rarity: rarity ?? this.rarity,
      priceMin: priceMin ?? this.priceMin,
      priceTrend: priceTrend ?? this.priceTrend,
      imageUrl: imageUrl ?? this.imageUrl,
      cardmarketUrl: cardmarketUrl ?? this.cardmarketUrl,
      scannedAt: scannedAt ?? this.scannedAt,
    );
  }
}
