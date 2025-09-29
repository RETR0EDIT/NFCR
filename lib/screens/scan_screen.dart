import 'package:flutter/material.dart';
import '../models/nfc_card.dart';
import '../services/nfc_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  final NFCService _nfcService = NFCService();
  final TextEditingController _nameController = TextEditingController();

  bool _isScanning = false;
  bool _cardDetected = false;
  NFCCard? _detectedCard;
  String _statusMessage =
      'Appuyez sur "Commencer le scan" pour détecter une carte NFC';

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.repeat(reverse: true);
  }

  Future<void> _startScanning() async {
    setState(() {
      _isScanning = true;
      _cardDetected = false;
      _detectedCard = null;
      _statusMessage = 'Approchez votre carte NFC du téléphone...';
    });

    try {
      await _nfcService.startNFCSession(
        onCardDetected: (NFCCard card) {
          setState(() {
            _cardDetected = true;
            _detectedCard = card;
            _statusMessage = 'Carte détectée ! Donnez-lui un nom.';
            _nameController.text = card.name;
          });
          _nfcService.stopNFCSession();
        },
        onError: (String error) {
          setState(() {
            _isScanning = false;
            _statusMessage = 'Erreur: $error';
          });
        },
      );
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Erreur lors du scan: $e';
      });
    }
  }

  Future<void> _stopScanning() async {
    await _nfcService.stopNFCSession();
    setState(() {
      _isScanning = false;
      _statusMessage = 'Scan arrêté';
    });
  }

  Future<void> _saveCard() async {
    if (_detectedCard == null) return;

    String cardName = _nameController.text.trim();
    if (cardName.isEmpty) {
      _showErrorSnackBar('Veuillez entrer un nom pour la carte');
      return;
    }

    try {
      NFCCard? savedCard = await _nfcService.saveScannedCard(
        _detectedCard!,
        cardName,
      );

      if (mounted) {
        if (savedCard != null) {
          Navigator.pop(context, true);
        } else {
          _showErrorSnackBar('Erreur lors de la sauvegarde de la carte');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erreur: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildScanAnimation() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isScanning ? _scaleAnimation.value : 1.0,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _cardDetected
                    ? Colors.green
                    : _isScanning
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
                width: 4,
              ),
            ),
            child: Icon(
              Icons.nfc,
              size: 80,
              color: _cardDetected
                  ? Colors.green
                  : _isScanning
                  ? Theme.of(context).primaryColor
                  : Colors.grey,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardInfo() {
    if (_detectedCard == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informations de la carte',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('UID', _detectedCard!.uid.toUpperCase()),
            _buildInfoRow('Technologie', _detectedCard!.technology),
            _buildInfoRow(
              'Détectée le',
              '${_detectedCard!.createdAt.day}/${_detectedCard!.createdAt.month}/${_detectedCard!.createdAt.year} à ${_detectedCard!.createdAt.hour}:${_detectedCard!.createdAt.minute.toString().padLeft(2, '0')}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner une carte NFC'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Animation de scan
            Center(child: _buildScanAnimation()),

            const SizedBox(height: 32),

            // Message de statut
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),

            const SizedBox(height: 32),

            // Boutons de contrôle
            if (!_cardDetected) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? _stopScanning : _startScanning,
                  icon: Icon(_isScanning ? Icons.stop : Icons.nfc),
                  label: Text(
                    _isScanning ? 'Arrêter le scan' : 'Commencer le scan',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],

            // Informations de la carte détectée
            if (_cardDetected) ...[
              _buildCardInfo(),

              const SizedBox(height: 16),

              // Champ de nom
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la carte',
                  hintText: 'Donnez un nom à votre carte...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                ),
                maxLength: 50,
              ),

              const SizedBox(height: 16),

              // Boutons d'action
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _cardDetected = false;
                          _detectedCard = null;
                          _statusMessage =
                              'Appuyez sur "Commencer le scan" pour détecter une carte NFC';
                          _nameController.clear();
                        });
                      },
                      child: const Text('Scanner une autre'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveCard,
                      child: const Text('Sauvegarder'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    if (_isScanning) {
      _nfcService.stopNFCSession();
    }
    super.dispose();
  }
}
