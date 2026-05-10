// Widget carte résultat affiché dans l'historique et l'écran de résultat
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/card_model.dart';
import 'rarity_badge.dart';

/// Carte visuelle affichant les informations d'une carte One Piece scannée
class CardResultCard extends StatelessWidget {
  final CardModel card;

  /// Callback lors du tap sur la carte
  final VoidCallback? onTap;

  const CardResultCard({
    super.key,
    required this.card,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image de la carte
            _buildCardImage(),

            // Informations de la carte
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Numéro de carte
                    if (card.cardNumber.isNotEmpty)
                      Text(
                        card.cardNumber,
                        style: const TextStyle(
                          color: Color(0xFFC0392B),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),

                    const SizedBox(height: 4),

                    // Nom de la carte
                    Text(
                      card.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Édition
                    if (card.edition.isNotEmpty)
                      Text(
                        card.edition,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),

                    const SizedBox(height: 10),

                    // Badge de rareté
                    RarityBadge(rarity: card.rarity, animate: false),

                    const SizedBox(height: 10),

                    // Prix
                    _buildPriceRow(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construit l'image de la carte avec fallback
  Widget _buildCardImage() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      ),
      child: card.imageUrl != null && card.imageUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: card.imageUrl!,
              width: 90,
              height: 130,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 90,
                height: 130,
                color: const Color(0xFF0D0D0D),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFC0392B),
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => _placeholderImage(),
            )
          : _placeholderImage(),
    );
  }

  /// Image de remplacement si l'URL est manquante
  Widget _placeholderImage() {
    return Container(
      width: 90,
      height: 130,
      color: const Color(0xFF0D0D0D),
      child: const Icon(
        Icons.style,
        color: Color(0xFFC0392B),
        size: 36,
      ),
    );
  }

  /// Ligne des prix avec min et tendance
  Widget _buildPriceRow() {
    if (card.priceMin == null && card.priceTrend == null) {
      return const Text(
        'Prix non disponible',
        style: TextStyle(color: Colors.white38, fontSize: 12),
      );
    }

    return Wrap(
      spacing: 12,
      children: [
        if (card.priceMin != null)
          _priceChip(
            label: 'Min',
            value: '${card.priceMin!.toStringAsFixed(2)} €',
            color: const Color(0xFF27AE60),
          ),
        if (card.priceTrend != null)
          _priceChip(
            label: 'Tendance',
            value: '${card.priceTrend!.toStringAsFixed(2)} €',
            color: const Color(0xFF3498DB),
          ),
      ],
    );
  }

  /// Chip pour afficher un prix
  Widget _priceChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
