// Écran résultat d'une session de scan à la chaîne
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/card_model.dart';
import '../widgets/card_result_card.dart';
import 'result_screen.dart';

/// Écran affichant toutes les cartes scannées lors d'une session chaîne
class ChainScanResultScreen extends StatefulWidget {
  /// Liste des cartes scannées durant la session
  final List<CardModel> cards;

  /// Callback appelé quand l'utilisateur vide la session
  final VoidCallback? onClear;

  const ChainScanResultScreen({
    super.key,
    required this.cards,
    this.onClear,
  });

  @override
  State<ChainScanResultScreen> createState() => _ChainScanResultScreenState();
}

class _ChainScanResultScreenState extends State<ChainScanResultScreen> {
  late List<CardModel> _cards;

  @override
  void initState() {
    super.initState();
    _cards = List.from(widget.cards);
  }

  double get _totalMin => _cards.fold(
        0.0,
        (sum, c) => sum + (c.priceMin ?? 0.0),
      );

  double get _totalTrend => _cards.fold(
        0.0,
        (sum, c) => sum + (c.priceTrend ?? 0.0),
      );

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Vider la session ?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Toutes les cartes de cette session seront supprimées. '
          'L\'historique global ne sera pas affecté.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vider',
                style: TextStyle(color: Color(0xFFC0392B))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onClear?.call();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.link, color: Color(0xFF2ECC71), size: 18),
            const SizedBox(width: 8),
            const Text(
              'Session chaîne',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          if (_cards.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white54),
              tooltip: 'Vider la session',
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: _cards.isEmpty ? _buildEmptyState() : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildSummaryBanner(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: _cards.length,
            itemBuilder: (context, index) {
              final card = _cards[index];
              return CardResultCard(
                card: card,
                onTap: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        ResultScreen(card: card),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) =>
                            FadeTransition(opacity: animation, child: child),
                    transitionDuration: const Duration(milliseconds: 350),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(
                      duration: 350.ms,
                      delay: Duration(milliseconds: index * 60))
                  .slideX(
                      begin: 0.05,
                      duration: 300.ms,
                      delay: Duration(milliseconds: index * 60),
                      curve: Curves.easeOut);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D3320),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF27AE60).withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_cards.length} carte${_cards.length > 1 ? 's' : ''} scannée${_cards.length > 1 ? 's' : ''}',
              style: const TextStyle(
                color: Color(0xFF2ECC71),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Total min : ${_totalMin.toStringAsFixed(2)} €',
                style: const TextStyle(
                    color: Color(0xFF27AE60),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              Text(
                'Tendance : ${_totalTrend.toStringAsFixed(2)} €',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, duration: 350.ms);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link_off, color: Colors.white12, size: 72)
              .animate()
              .fadeIn(duration: 600.ms)
              .scaleXY(begin: 0.8, duration: 500.ms, curve: Curves.easeOut),
          const SizedBox(height: 20),
          const Text(
            'Aucune carte dans la session',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 17,
                fontWeight: FontWeight.w600),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
          const SizedBox(height: 8),
          const Text(
            'Activez le mode chaîne et scannez\nvos cartes pour les voir apparaître ici.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Colors.white30, fontSize: 13, height: 1.6),
          ).animate().fadeIn(duration: 400.ms, delay: 350.ms),
        ],
      ),
    );
  }
}
