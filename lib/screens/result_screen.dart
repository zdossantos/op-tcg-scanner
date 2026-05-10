import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;
import '../models/card_model.dart';
import '../widgets/rarity_badge.dart';

class ResultScreen extends StatefulWidget {
  final CardModel card;
  final String? warningMessage;

  const ResultScreen({super.key, required this.card, this.warningMessage});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    _saveToHistory();
  }

  Future<void> _saveToHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> history = prefs.getStringList('scan_history') ?? [];
      final cardJson = jsonEncode(widget.card.toJson());
      history.removeWhere((item) {
        try {
          final map = jsonDecode(item) as Map<String, dynamic>;
          return map['id'] == widget.card.id;
        } catch (_) { return false; }
      });
      history.insert(0, cardJson);
      if (history.length > 50) history.removeRange(50, history.length);
      await prefs.setStringList('scan_history', history);
    } catch (_) {}
  }

  Future<void> _openCardmarket() async {
    final url = widget.card.cardmarketUrl;
    if (url == null || url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir Cardmarket'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.warningMessage != null) _buildWarningBanner(),
                _buildMainInfo(),
                _buildDivider(),
                _buildPriceSection(),
                if (widget.card.cardmarketUrl != null) _buildCardmarketButton(),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 460,
      backgroundColor: const Color(0xFF080B14),
      pinned: true,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.5),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Image carte
            _buildCardImage(),
            // Dégradé bas
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x66080B14), Color(0xFF080B14)],
                  stops: [0.45, 0.8, 1.0],
                ),
              ),
            ),
            // Dégradé latéral (subtil)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0x33080B14), Colors.transparent, Color(0x33080B14)],
                ),
              ),
            ),
            // Animation rareté
            _buildRarityAnimation(),
          ],
        ),
      ),
    );
  }

  Widget _buildCardImage() {
    if (widget.card.imageUrl == null || widget.card.imageUrl!.isEmpty) {
      return Container(
        color: const Color(0xFF0F1628),
        child: const Center(child: Icon(Icons.style, color: Color(0xFFC0392B), size: 80)),
      );
    }
    return CachedNetworkImage(
      imageUrl: widget.card.imageUrl!,
      fit: BoxFit.contain,
      placeholder: (context, url) => Container(
        color: const Color(0xFF0F1628),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFFF1C40F), strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => Container(
        color: const Color(0xFF0F1628),
        child: const Center(child: Icon(Icons.broken_image, color: Colors.white12, size: 60)),
      ),
    );
  }

  Widget _buildRarityAnimation() {
    switch (widget.card.rarity) {
      case CardRarity.common:
      case CardRarity.unknown:
        return const SizedBox.shrink();

      case CardRarity.uncommon:
        return IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF2ECC71).withValues(alpha: 0.35), width: 2),
            ),
          ),
        ).animate().fadeIn(duration: 800.ms);

      case CardRarity.rare:
        return IgnorePointer(
          child: Shimmer.fromColors(
            baseColor: Colors.transparent,
            highlightColor: const Color(0xFF3498DB).withValues(alpha: 0.2),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF3498DB).withValues(alpha: 0.4), width: 2),
              ),
            ),
          ),
        );

      case CardRarity.superRare:
        return IgnorePointer(
          child: Shimmer.fromColors(
            baseColor: Colors.transparent,
            highlightColor: const Color(0xFFF1C40F).withValues(alpha: 0.25),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFF1C40F).withValues(alpha: 0.6), width: 2),
              ),
            ),
          ),
        );

      case CardRarity.secretRare:
      case CardRarity.leader:
        return IgnorePointer(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x2AE74C3C), Color(0x2AF39C12), Color(0x2A2ECC71), Color(0x2A3498DB), Color(0x2A9B59B6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .shimmer(duration: 2200.ms, colors: const [Color(0x33E74C3C), Color(0x33F1C40F), Color(0x333498DB), Color(0x339B59B6)]);
    }
  }

  Widget _buildWarningBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1800),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF39C12).withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF39C12), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.warningMessage!,
              style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Numéro + badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.card.cardNumber.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC0392B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFC0392B).withValues(alpha: 0.3), width: 1),
                  ),
                  child: Text(
                    widget.card.cardNumber,
                    style: const TextStyle(
                      color: Color(0xFFE74C3C),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
              const SizedBox(width: 8),
              RarityBadge(rarity: widget.card.rarity),
            ],
          ),
          const SizedBox(height: 10),
          // Nom
          Text(
            widget.card.name,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.1),
          )
              .animate()
              .fadeIn(duration: 500.ms, delay: 150.ms)
              .slideY(begin: 0.15, duration: 400.ms, curve: Curves.easeOut),
          const SizedBox(height: 6),
          // Édition
          if (widget.card.edition.isNotEmpty)
            Text(
              widget.card.edition,
              style: const TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w400),
            ).animate().fadeIn(duration: 400.ms, delay: 250.ms),
        ],
      ),
    );
  }

  Widget _buildDivider() => Container(
        height: 1,
        color: Colors.white.withValues(alpha: 0.06),
      );

  Widget _buildPriceSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PRIX DU MARCHÉ',
            style: TextStyle(
              color: Colors.white30,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildPriceTile(
                  label: 'Prix minimum',
                  value: widget.card.priceMin != null
                      ? '\$${widget.card.priceMin!.toStringAsFixed(2)}'
                      : '–',
                  icon: Icons.arrow_downward_rounded,
                  color: const Color(0xFF27AE60),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPriceTile(
                  label: 'Tendance',
                  value: widget.card.priceTrend != null
                      ? '\$${widget.card.priceTrend!.toStringAsFixed(2)}'
                      : '–',
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF3498DB),
                ),
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 500.ms, delay: 350.ms)
              .slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOut),
        ],
      ),
    );
  }

  Widget _buildPriceTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color.withValues(alpha: 0.7), size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w800, height: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildCardmarketButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _openCardmarket,
          icon: const Icon(Icons.open_in_new_rounded, size: 17),
          label: const Text('Voir sur Cardmarket'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A1A2E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Colors.white12, width: 1),
            ),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 450.ms)
        .slideY(begin: 0.1, duration: 350.ms, curve: Curves.easeOut);
  }
}
