// Widget badge animé selon la rareté d'une carte One Piece
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../models/card_model.dart';

/// Badge affichant la rareté d'une carte avec animation adaptée
class RarityBadge extends StatelessWidget {
  final CardRarity rarity;
  final bool animate;

  const RarityBadge({
    super.key,
    required this.rarity,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return _buildBadge(context);
  }

  Widget _buildBadge(BuildContext context) {
    switch (rarity) {
      case CardRarity.common:
        return _commonBadge();
      case CardRarity.uncommon:
        return _uncommonBadge();
      case CardRarity.rare:
        return _rareBadge();
      case CardRarity.superRare:
        return _superRareBadge();
      case CardRarity.secretRare:
        return _secretRareBadge();
      case CardRarity.leader:
        return _leaderBadge();
      case CardRarity.unknown:
        return _unknownBadge();
    }
  }

  /// Badge Common : texte simple, fond semi-transparent
  Widget _commonBadge() {
    final badge = _baseBadge(
      label: rarity.label,
      color: Colors.white12,
      textColor: Colors.white54,
    );
    if (!animate) return badge;
    return badge.animate().fadeIn(duration: 300.ms);
  }

  /// Badge Uncommon : vert discret
  Widget _uncommonBadge() {
    final badge = _baseBadge(
      label: rarity.label,
      color: const Color(0xFF1A4731),
      textColor: const Color(0xFF2ECC71),
    );
    if (!animate) return badge;
    return badge.animate().fadeIn(duration: 300.ms);
  }

  /// Badge Rare : bleu sans shimmer
  Widget _rareBadge() {
    return _baseBadge(
      label: rarity.label,
      color: const Color(0xFF1A2F45),
      textColor: const Color(0xFF5DADE2),
    );
  }

  /// Badge Super Rare : shimmer doré léger
  Widget _superRareBadge() {
    final badge = Shimmer.fromColors(
      baseColor: const Color(0xFFF39C12),
      highlightColor: const Color(0xFFF1C40F),
      child: _baseBadge(
        label: rarity.label,
        color: const Color(0xFF3D2800),
        textColor: const Color(0xFFF1C40F),
      ),
    );
    if (!animate) return badge;
    return badge;
  }

  /// Badge Secret Rare : arc-en-ciel animé
  Widget _secretRareBadge() {
    final badge = _rainbowBadge(rarity.label);
    if (!animate) return badge;
    return badge
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1800.ms, color: Colors.white30);
  }

  /// Badge Leader : rouge sobre
  Widget _leaderBadge() {
    final badge = _baseBadge(
      label: rarity.label,
      color: const Color(0xFF3D0A08),
      textColor: const Color(0xFFE74C3C),
      icon: Icons.star,
    );
    if (!animate) return badge;
    return badge.animate().fadeIn(duration: 300.ms);
  }

  /// Badge inconnu : style neutre
  Widget _unknownBadge() {
    return _baseBadge(
      label: '?',
      color: Colors.white10,
      textColor: Colors.white38,
    );
  }

  /// Construit le badge de base avec les paramètres donnés
  Widget _baseBadge({
    required String label,
    required Color color,
    required Color textColor,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: textColor, size: 11),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Badge arc-en-ciel pour les Secret Rare
  Widget _rainbowBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE74C3C),
            Color(0xFFF39C12),
            Color(0xFFF1C40F),
            Color(0xFF2ECC71),
            Color(0xFF3498DB),
            Color(0xFF9B59B6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.4),
            blurRadius: 14,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
        ),
      ),
    );
  }
}
