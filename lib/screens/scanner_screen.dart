import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image/image.dart' as img;
import '../services/vision_service.dart';
import '../services/cardmarket_service.dart';
import '../models/card_model.dart';
import 'result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];

  final VisionService _visionService = VisionService();
  final CardmarketService _cardmarketService = CardmarketService();

  bool _isCameraReady = false;
  bool _isScanning = false;
  String? _errorMessage;

  // Auto-scan
  bool _autoScanEnabled = false;
  bool _isAutoProcessing = false;
  String? _detectedCardNumber;
  Timer? _autoScanTimer;

  late final AnimationController _laserController;

  /// Clé globale sur le cadre de scan pour connaître sa position exacte
  final GlobalKey _frameKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _initCamera();
  }

  @override
  void dispose() {
    _autoScanTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _visionService.dispose();
    _laserController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _autoScanTimer?.cancel();
      _autoScanTimer = null;
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera().then((_) {
        if (_autoScanEnabled && mounted) _startAutoScanTimer();
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _errorMessage = 'Aucune caméra disponible.');
        return;
      }
      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() { _isCameraReady = true; _errorMessage = null; });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Impossible d\'accéder à la caméra.');
    }
  }

  // ─── Auto-scan ──────────────────────────────────────────────────────────────

  void _toggleAutoScan() {
    if (_autoScanEnabled) {
      _autoScanTimer?.cancel();
      _autoScanTimer = null;
      setState(() { _autoScanEnabled = false; _detectedCardNumber = null; });
    } else {
      setState(() { _autoScanEnabled = true; _detectedCardNumber = null; _errorMessage = null; });
      _startAutoScanTimer();
    }
  }

  void _startAutoScanTimer() {
    _autoScanTimer?.cancel();
    _autoScanTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) => _autoScanTick());
  }

  Future<void> _autoScanTick() async {
    if (!mounted || _isScanning || _isAutoProcessing) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    _isAutoProcessing = true;
    try {
      final imageFile = await _cameraController!.takePicture();
      final croppedPath = await _cropImageToFrame(imageFile.path);
      final scanResult = await _visionService.recognizeCard(croppedPath ?? imageFile.path);
      if (croppedPath != null) try { await File(croppedPath).delete(); } catch (_) {}
      try { await File(imageFile.path).delete(); } catch (_) {}

      if (!mounted || scanResult.cardNumber == null) return;

      // Carte détectée → pause timer + feedback visuel + scan complet
      _autoScanTimer?.cancel();
      _autoScanTimer = null;
      setState(() {
        _detectedCardNumber = scanResult.cardNumber;
        _isScanning = true;
        _errorMessage = null;
      });

      await _performScan(scanResult);

      if (mounted && _autoScanEnabled) {
        setState(() { _detectedCardNumber = null; _isScanning = false; });
        _startAutoScanTimer();
      }
    } catch (_) {
      // Ignore silencieusement les erreurs en auto-scan
    } finally {
      _isAutoProcessing = false;
    }
  }

  // ─── Scan manuel ────────────────────────────────────────────────────────────

  Future<void> _captureAndScan() async {
    if (_isScanning || _cameraController == null) return;
    if (!_cameraController!.value.isInitialized) return;

    // Pause l'auto-scan pendant le scan manuel
    _autoScanTimer?.cancel();
    _autoScanTimer = null;

    setState(() { _isScanning = true; _errorMessage = null; });

    try {
      final XFile imageFile = await _cameraController!.takePicture();
      final croppedPath = await _cropImageToFrame(imageFile.path);
      final scanResult = await _visionService.recognizeCard(croppedPath ?? imageFile.path);
      if (croppedPath != null) try { await File(croppedPath).delete(); } catch (_) {}
      try { await File(imageFile.path).delete(); } catch (_) {}

      if (!scanResult.isValid) {
        _showError('Aucune carte détectée. Assurez-vous que le numéro (ex: OP01-001) est visible.');
        return;
      }
      await _performScan(scanResult);
    } on CardmarketException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Erreur inattendue lors du scan. Veuillez réessayer.');
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
        if (_autoScanEnabled) _startAutoScanTimer();
      }
    }
  }

  // ─── Traitement commun (API + navigation) ───────────────────────────────────

  Future<void> _performScan(CardScanResult scanResult) async {
    List<CardModel>? cards;
    String? warningMessage;

    try {
      cards = await _cardmarketService.searchCard(
        cardNumber: scanResult.cardNumber,
        cardName: scanResult.cardName,
      );
    } on CardmarketException catch (e) {
      if (e.isBlocked) {
        warningMessage = e.message;
        final cardId = scanResult.cardNumber ??
            (scanResult.cardName ?? 'unknown').replaceAll(' ', '_').toLowerCase();
        cards = [
          CardModel(
            id: cardId,
            name: scanResult.cardName ?? 'Carte scannée',
            cardNumber: scanResult.cardNumber ?? '',
            edition: 'One Piece TCG',
            rarity: CardRarity.unknown,
            scannedAt: DateTime.now(),
            cardmarketUrl: scanResult.cardNumber != null
                ? 'https://www.cardmarket.com/en/OnePiece/Products/Singles?searchString=${Uri.encodeComponent(scanResult.cardNumber!)}'
                : null,
          ),
        ];
      } else {
        if (mounted) _showError(e.message);
        return;
      }
    }

    if (!mounted) return;

    if (cards.length == 1) {
      await _navigateToResult(cards.first, warningMessage);
    } else {
      if (mounted) setState(() => _isScanning = false);
      await _showVariantSelector(cards, warningMessage);
    }
  }

  /// Recadre l'image capturée aux coordonnées exactes du cadre de scan affiché.
  ///
  /// Utilise le [_frameKey] pour obtenir la position réelle du cadre sur l'écran,
  /// puis mappe ces coordonnées vers les pixels de l'image capturée en tenant
  /// compte du letterboxing du CameraPreview.
  Future<String?> _cropImageToFrame(String imagePath) async {
    try {
      if (_frameKey.currentContext == null) return null;

      // Position exacte du cadre sur l'écran
      final renderBox = _frameKey.currentContext!.findRenderObject() as RenderBox;
      final frameOffset = renderBox.localToGlobal(Offset.zero);
      final frameSize = renderBox.size;
      final screenSize = MediaQuery.of(context).size;

      // Charge et oriente l'image (corrige l'EXIF iOS/Android)
      final bytes = await File(imagePath).readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;
      image = img.bakeOrientation(image);

      final imgW = image.width.toDouble();
      final imgH = image.height.toDouble();
      final screenW = screenSize.width;
      final screenH = screenSize.height;

      // Le CameraPreview utilise AspectRatio → letterboxing possible
      final cameraAspect = imgW / imgH;
      final screenAspect = screenW / screenH;

      double previewW, previewH, offsetX = 0, offsetY = 0;
      if (cameraAspect > screenAspect) {
        // Préview remplit la largeur, barres noires haut/bas
        previewW = screenW;
        previewH = screenW / cameraAspect;
        offsetY = (screenH - previewH) / 2;
      } else {
        // Préview remplit la hauteur, barres noires gauche/droite
        previewH = screenH;
        previewW = screenH * cameraAspect;
        offsetX = (screenW - previewW) / 2;
      }

      // Facteurs d'échelle préview → pixels image
      final scaleX = imgW / previewW;
      final scaleY = imgH / previewH;

      // Coordonnées du cadre dans l'image
      final x = ((frameOffset.dx - offsetX) * scaleX).round().clamp(0, image.width - 1);
      final y = ((frameOffset.dy - offsetY) * scaleY).round().clamp(0, image.height - 1);
      final w = (frameSize.width * scaleX).round().clamp(1, image.width - x);
      final h = (frameSize.height * scaleY).round().clamp(1, image.height - y);

      final cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);

      final croppedPath = imagePath.replaceFirst('.jpg', '_crop.jpg');
      await File(croppedPath).writeAsBytes(img.encodeJpg(cropped, quality: 95));
      return croppedPath;
    } catch (_) {
      return null; // En cas d'erreur, on utilise l'image complète
    }
  }

  Future<void> _navigateToResult(CardModel card, String? warningMessage) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ResultScreen(card: card, warningMessage: warningMessage),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _showVariantSelector(List<CardModel> cards, String? warningMessage) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F1628),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.layers_outlined, color: Color(0xFFF1C40F), size: 20),
                        const SizedBox(width: 10),
                        const Text(
                          'Plusieurs versions trouvées',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(
                          '${cards.length} résultats',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Choisissez la version de votre carte',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.58,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: cards.length,
                      itemBuilder: (_, i) {
                        final card = cards[i];
                        final price = card.priceMin != null
                            ? '\$${card.priceMin!.toStringAsFixed(2)}'
                            : '–';
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            _navigateToResult(card, warningMessage);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A2E),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white12, width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Card image
                                Expanded(
                                  flex: 7,
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                                    child: card.imageUrl != null
                                        ? Image.network(
                                            card.imageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stack) => Container(
                                              color: const Color(0xFF12122A),
                                              child: const Center(child: Icon(Icons.style, color: Color(0xFFC0392B), size: 40)),
                                            ),
                                          )
                                        : Container(
                                            color: const Color(0xFF12122A),
                                            child: const Center(child: Icon(Icons.style, color: Color(0xFFC0392B), size: 40)),
                                          ),
                                  ),
                                ),
                                // Card info
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        card.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            price,
                                            style: const TextStyle(
                                              color: Color(0xFFF1C40F),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            card.rarity.label,
                                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() { _errorMessage = message; _isScanning = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildCameraPreview(),
          _buildTopBar(),
          _buildScanFrame(),
          _buildBottomBar(),
          if (_isScanning) _buildScanningOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraReady || _cameraController == null) {
      return Container(
        color: const Color(0xFF0A0A1A),
        child: Center(
          child: _errorMessage != null
              ? _buildErrorWidget()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFF1C40F), strokeWidth: 2),
                    const SizedBox(height: 16),
                    const Text('Initialisation caméra...', style: TextStyle(color: Colors.white38, fontSize: 13)),
                  ],
                ),
        ),
      );
    }
    return SizedBox.expand(child: CameraPreview(_cameraController!));
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16, right: 16, bottom: 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            // Logo + titre
            _buildLogo(),
            const Spacer(),
            // Bouton historique
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/history'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.history, color: Colors.white70, size: 16),
                    SizedBox(width: 6),
                    Text('Historique', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    // Vérifie si l'asset logo existe, sinon affiche l'icône de secours
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF0E1F4D),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFF1C40F), width: 1.5),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const Icon(
                Icons.explore,
                color: Color(0xFFF1C40F),
                size: 22,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'OP SCANNER',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              'One Piece TCG',
              style: TextStyle(color: Color(0xFFF1C40F), fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.5),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScanFrame() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 60), // décale légèrement vers le haut du centre
          SizedBox(
            key: _frameKey,
            width: 260,
            height: 364,
            child: Stack(
              children: [
                // Fond semi-transparent dans le cadre
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.transparent,
                  ),
                ),
                // Coins dorés
                ..._buildCorners(),
                // Laser animé
                AnimatedBuilder(
                  animation: _laserController,
                  builder: (context, child) {
                    final y = _laserController.value * 352.0;
                    return Positioned(
                      top: y,
                      left: 8,
                      right: 8,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.transparent, Color(0xFFC0392B), Color(0xFFFF6B6B), Color(0xFFC0392B), Colors.transparent],
                          ),
                          borderRadius: BorderRadius.circular(1),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFC0392B).withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Badge "carte détectée" (auto-scan)
          if (_detectedCardNumber != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF0D3320),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF27AE60), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _detectedCardNumber!,
                    style: const TextStyle(
                      color: Color(0xFF2ECC71),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 200.ms)
            .scaleXY(begin: 0.85, end: 1.0, duration: 200.ms)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _autoScanEnabled ? 'Auto-scan actif...' : 'Pointez vers le numéro de carte',
                style: TextStyle(
                  color: _autoScanEnabled ? const Color(0xFF2ECC71) : Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 1200.ms)
              .then()
              .fadeOut(duration: 1200.ms),
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    const size = 24.0;
    const thickness = 3.0;
    const color = Color(0xFFF1C40F);

    Widget corner({required bool top, required bool left}) => Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border(
            top: top ? const BorderSide(color: color, width: thickness) : BorderSide.none,
            bottom: !top ? const BorderSide(color: color, width: thickness) : BorderSide.none,
            left: left ? const BorderSide(color: color, width: thickness) : BorderSide.none,
            right: !left ? const BorderSide(color: color, width: thickness) : BorderSide.none,
          ),
        ),
      ),
    );

    return [
      corner(top: true, left: true),
      corner(top: true, left: false),
      corner(top: false, left: true),
      corner(top: false, left: false),
    ];
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: 24,
          left: 32,
          right: 32,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.92), Colors.transparent],
            stops: const [0.0, 1.0],
          ),
        ),
        child: Column(
          children: [
            // Erreur
            if (_errorMessage != null)
              GestureDetector(
                onTap: () => setState(() => _errorMessage = null),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D0A08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC0392B).withValues(alpha: 0.4), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFE74C3C), size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                      const Icon(Icons.close, color: Colors.white38, size: 16),
                    ],
                  ),
                ),
              ),
            // Bouton scan + aide
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Aide
                GestureDetector(
                  onTap: _showHelp,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: const Icon(Icons.info_outline, color: Colors.white54, size: 20),
                  ),
                ),
                const SizedBox(width: 28),
                // Bouton capture principal
                GestureDetector(
                  onTap: _isScanning ? null : _captureAndScan,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isScanning ? Colors.grey.shade700 : const Color(0xFFC0392B),
                      boxShadow: _isScanning ? [] : [
                        BoxShadow(
                          color: const Color(0xFFC0392B).withValues(alpha: 0.45),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                          ),
                        ),
                        Icon(
                          _isScanning ? Icons.hourglass_empty : Icons.camera_alt,
                          color: Colors.white,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(begin: 1.0, end: 1.03, duration: 1400.ms, curve: Curves.easeInOut),
                const SizedBox(width: 28),
                // Bouton auto-scan
                GestureDetector(
                  onTap: _toggleAutoScan,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _autoScanEnabled
                          ? const Color(0xFF1E5F3A)
                          : Colors.white.withValues(alpha: 0.08),
                      border: Border.all(
                        color: _autoScanEnabled ? const Color(0xFF27AE60) : Colors.white24,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      _autoScanEnabled ? Icons.sensors : Icons.sensors_off,
                      color: _autoScanEnabled ? const Color(0xFF2ECC71) : Colors.white54,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1628),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: const Color(0xFFF1C40F),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Analyse en cours',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Reconnaissance et recherche\ndes données de la carte...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3D0A08),
              border: Border.all(color: const Color(0xFFC0392B).withValues(alpha: 0.4), width: 1),
            ),
            child: const Icon(Icons.camera_alt, color: Color(0xFFC0392B), size: 30),
          ),
          const SizedBox(height: 20),
          Text(
            _errorMessage ?? 'Erreur inconnue',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _initCamera,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC0392B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Réessayer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.explore, color: Color(0xFFF1C40F), size: 22),
            SizedBox(width: 10),
            Text('Comment scanner ?', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HelpStep(number: '1', text: 'Placez la carte dans le cadre'),
            _HelpStep(number: '2', text: 'Assurez-vous que le numéro (ex: OP01-001) est bien visible'),
            _HelpStep(number: '3', text: 'Appuyez sur le bouton rouge pour capturer'),
            _HelpStep(number: '4', text: 'Choisissez la version si plusieurs variantes apparaissent'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris', style: TextStyle(color: Color(0xFFF1C40F), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Étape d'aide dans la boîte de dialogue
class _HelpStep extends StatelessWidget {
  final String number;
  final String text;

  const _HelpStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFC0392B),
            ),
            child: Center(
              child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }
}
