// Écran de résultat affichant les détails d'une carte scannée
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;
import '../models/card_model.dart';
import '../widgets/rarity_badge.dart';

/// Écran de résultat affichant la carte avec animations selon la rareté
class ResultScreen extends StatefulWidget {
  final CardModel card;

  /// Message d'avertissement (ex: Cardmarket bloqué)
  final String? warningMessage;

  const ResultScreen({super.key, required this.card, this.warningMessage});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    // Sauvegarde la carte dans l'historique dès l'affichage du résultat
    _saveToHistory();
  }

  /// Sauvegarde la carte dans l'historique local (SharedPreferences)
  Future<void> _saveToHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> history =
          prefs.getStringList('scan_history') ?? [];

      // Encode la carte en JSON
      final cardJson = jsonEncode(widget.card.toJson());

      // Évite les doublons basés sur le numéro de carte
      history.removeWhere((item) {
        try {
          final map = jsonDecode(item) as Map<String, dynamic>;
          return map['id'] == widget.card.id;
        } catch (_) {
          return false;
        }
      });

      // Ajoute la nouvelle carte en tête de liste
      history.insert(0, cardJson);

      // Conserve au maximum 50 cartes dans l'historique
      if (history.length > 50) {
        history.removeRange(50, history.length);
      }

      await prefs.setStringList('scan_history', history);
    } catch (_) {
      // La sauvegarde n'est pas critique, on ignore l'erreur silencieusement
    }
  }

  /// Ouvre la page Cardmarket dans le navigateur
  Future<void> _openCardmarket() async {
    final url = widget.card.cardmarketUrl;
    if (url == null || url.isEmpty) return;

    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir Cardmarket'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: CustomScrollView(
        slivers: [
          // App bar avec image de fond
          _buildSliverAppBar(context),

          // Contenu défilable
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informations principales
                _buildMainInfo(),

                // Bannière d'avertissement si Cardmarket a bloqué
                if (widget.warningMessage != null)
                  _buildWarningBanner(),

                const Divider(color: Colors.white12, height: 1),

                // Section prix
                _buildPriceSection(),

                const Divider(color: Colors.white12, height: 1),

                // Bouton Cardmarket
                if (widget.card.cardmarketUrl != null)
                  _buildCardmarketButton(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Construit la SliverAppBar avec l'image de la carte en fond
  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 380,
      backgroundColor: const Color(0xFF0D0D0D),
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Image de la carte
            _buildCardImage(),

            // Overlay dégradé bas
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xFF0D0D0D)],
                  stops: [0.5, 1.0],
                ),
              ),
            ),

            // Animation selon la rareté (par-dessus l'image)
            _buildRarityAnimation(),
          ],
        ),
      ),
    );
  }

  /// Construit l'image de la carte
  Widget _buildCardImage() {
    if (widget.card.imageUrl == null || widget.card.imageUrl!.isEmpty) {
      return Container(
        color: const Color(0xFF1A1A2E),
        child: const Center(
          child: Icon(Icons.style, color: Color(0xFFC0392B), size: 80),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: widget.card.imageUrl!,
      fit: BoxFit.contain,
      placeholder: (context, url) => Container(
        color: const Color(0xFF1A1A2E),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFC0392B)),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: const Color(0xFF1A1A2E),
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.white24, size: 60),
        ),
      ),
    );
  }

  /// Construit l'animation de rareté superposée à l'image
  Widget _buildRarityAnimation() {
    switch (widget.card.rarity) {
      case CardRarity.common:
        // Simple fade in, pas d'animation supplémentaire
        return const SizedBox.shrink();

      case CardRarity.uncommon:
        // Lueur verte sur les bords
        return IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.4),
                  width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms)
            .slideY(begin: 0.1, duration: 500.ms, curve: Curves.easeOut);

      case CardRarity.rare:
        // Shimmer bleu
        return IgnorePointer(
          child: Shimmer.fromColors(
            baseColor: Colors.transparent,
            highlightColor: const Color(0xFF3498DB).withValues(alpha: 0.25),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color: const Color(0xFF3498DB).withValues(alpha: 0.5),
                    width: 2),
              ),
            ),
          ),
        );

      case CardRarity.superRare:
        // Shimmer doré + particules
        return IgnorePointer(
          child: Shimmer.fromColors(
            baseColor: Colors.transparent,
            highlightColor: const Color(0xFFF1C40F).withValues(alpha: 0.3),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color: const Color(0xFFF1C40F).withValues(alpha: 0.7),
                    width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF1C40F).withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        );

      case CardRarity.secretRare:
      case CardRarity.leader:
        // Arc-en-ciel holographique
        return IgnorePointer(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x33E74C3C),
                  Color(0x33F39C12),
                  Color(0x332ECC71),
                  Color(0x333498DB),
                  Color(0x339B59B6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .shimmer(
              duration: 2000.ms,
              colors: const [
                Color(0x44E74C3C),
                Color(0x44F1C40F),
                Color(0x443498DB),
                Color(0x449B59B6),
              ],
            );

      case CardRarity.unknown:
        return const SizedBox.shrink();
    }
  }

  /// Bannière d'avertissement Cardmarket bloqué
  Widget _buildWarningBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade900.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade700, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orange.shade400, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prix non disponible',
                  style: TextStyle(
                    color: Colors.orange.shade300,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cardmarket a bloqué la requête automatique. '
                  'Utilisez le bouton ci-dessous pour consulter le prix directement.',
                  style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Informations principales de la carte
  Widget _buildMainInfo() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Numéro de carte
          if (widget.card.cardNumber.isNotEmpty)
            Text(
              widget.card.cardNumber,
              style: const TextStyle(
                color: Color(0xFFC0392B),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 200.ms),

          const SizedBox(height: 8),

          // Nom de la carte
          Text(
            widget.card.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms, delay: 300.ms)
              .slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOut),

          const SizedBox(height: 12),

          // Édition et badge de rareté
          Row(
            children: [
              if (widget.card.edition.isNotEmpty)
                Expanded(
                  child: Text(
                    widget.card.edition,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ),
              RarityBadge(rarity: widget.card.rarity),
            ],
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 400.ms),
        ],
      ),
    );
  }

  /// Section d'affichage des prix
  Widget _buildPriceSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prix du marché (USD)',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Prix minimum
              Expanded(
                child: _buildPriceTile(
                  label: 'Prix minimum',
                  value: widget.card.priceMin != null
                      ? '\$${widget.card.priceMin!.toStringAsFixed(2)}'
                      : '–',
                  icon: Icons.arrow_downward,
                  color: const Color(0xFF27AE60),
                ),
              ),
              const SizedBox(width: 12),
              // Prix tendance
              Expanded(
                child: _buildPriceTile(
                  label: 'Tendance',
                  value: widget.card.priceTrend != null
                      ? '\$${widget.card.priceTrend!.toStringAsFixed(2)}'
                      : '–',
                  icon: Icons.trending_up,
                  color: const Color(0xFF3498DB),
                ),
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 500.ms, delay: 500.ms)
              .slideY(begin: 0.15, duration: 400.ms, curve: Curves.easeOut),
        ],
      ),
    );
  }

  /// Tuile de prix individuelle
  Widget _buildPriceTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// Bouton pour ouvrir la page Cardmarket
  Widget _buildCardmarketButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _openCardmarket,
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Voir sur Cardmarket'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC0392B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 600.ms)
        .slideY(begin: 0.1, duration: 350.ms, curve: Curves.easeOut);
  }
}
