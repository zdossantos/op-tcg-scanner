// Écran d'historique des cartes scannées
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/card_model.dart';
import '../widgets/card_result_card.dart';
import 'result_screen.dart';

/// Écran affichant l'historique des cartes précédemment scannées
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Liste des cartes de l'historique
  List<CardModel> _history = [];

  // Indique si le chargement est en cours
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// Charge l'historique depuis SharedPreferences
  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> rawHistory =
          prefs.getStringList('scan_history') ?? [];

      final List<CardModel> cards = [];
      for (final item in rawHistory) {
        try {
          final map = jsonDecode(item) as Map<String, dynamic>;
          cards.add(CardModel.fromJson(map));
        } catch (_) {
          // Ignore les entrées corrompues
        }
      }

      if (mounted) {
        setState(() {
          _history = cards;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de charger l\'historique.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Supprime une carte de l'historique
  Future<void> _deleteCard(int index) async {
    final removed = _history[index];

    setState(() {
      _history.removeAt(index);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> rawHistory =
          prefs.getStringList('scan_history') ?? [];

      rawHistory.removeWhere((item) {
        try {
          final map = jsonDecode(item) as Map<String, dynamic>;
          return map['id'] == removed.id;
        } catch (_) {
          return false;
        }
      });

      await prefs.setStringList('scan_history', rawHistory);
    } catch (_) {
      // Recharge en cas d'erreur de suppression
      await _loadHistory();
    }
  }

  /// Vide tout l'historique après confirmation
  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Vider l\'historique ?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Cette action supprimera toutes les cartes de votre historique. Cette opération est irréversible.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Annuler',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Vider',
              style: TextStyle(color: Color(0xFFC0392B)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('scan_history');
        if (mounted) {
          setState(() => _history = []);
        }
      } catch (_) {}
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
        title: const Text(
          'Historique',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white54),
              tooltip: 'Vider l\'historique',
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFC0392B)),
      );
    }

    if (_history.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: const Color(0xFFC0392B),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final card = _history[index];
          return Dismissible(
            key: Key(card.id + index.toString()),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade800,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete, color: Colors.white, size: 28),
            ),
            onDismissed: (_) => _deleteCard(index),
            child: CardResultCard(
              card: card,
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      ResultScreen(card: card),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
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
                    curve: Curves.easeOut),
          );
        },
      ),
    );
  }

  /// État vide quand aucune carte n'a été scannée
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.style_outlined,
            color: Colors.white12,
            size: 80,
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .scaleXY(begin: 0.8, duration: 500.ms, curve: Curves.easeOut),

          const SizedBox(height: 20),

          const Text(
            'Aucune carte scannée',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 200.ms),

          const SizedBox(height: 8),

          const Text(
            'Scannez votre première carte\npour la voir apparaître ici.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white30, fontSize: 14, height: 1.6),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 350.ms),

          const SizedBox(height: 32),

          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('Scanner une carte'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC0392B),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 500.ms)
              .slideY(begin: 0.1, duration: 350.ms, curve: Curves.easeOut),
        ],
      ),
    );
  }
}
