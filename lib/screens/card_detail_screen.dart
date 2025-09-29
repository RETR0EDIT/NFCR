import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/nfc_card.dart';
import '../services/nfc_service.dart';
import '../services/hce_service.dart';

class CardDetailScreen extends StatefulWidget {
  final NFCCard card;

  const CardDetailScreen({super.key, required this.card});

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  final NFCService _nfcService = NFCService();
  final TextEditingController _nameController = TextEditingController();

  bool _isEditing = false;
  bool _isEmulating = false;
  bool _hceSupported = false;
  bool _hceEnabled = false;
  String? _emulationError;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.card.name;
    _checkHceSupport();
  }

  Future<void> _checkHceSupport() async {
    try {
      final supported = await HceService.isHceSupported();
      final enabled = await HceService.isHceEnabled();

      if (mounted) {
        setState(() {
          _hceSupported = supported;
          _hceEnabled = enabled;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hceSupported = false;
          _hceEnabled = false;
          _emulationError = 'Erreur lors de la vérification HCE: $e';
        });
      }
    }
  }

  Future<void> _updateCardName() async {
    String newName = _nameController.text.trim();
    if (newName.isEmpty) {
      _showErrorSnackBar('Le nom ne peut pas être vide');
      return;
    }

    bool success = await _nfcService.updateCardName(widget.card.id!, newName);

    if (mounted) {
      if (success) {
        setState(() {
          _isEditing = false;
        });
        _showSuccessSnackBar('Nom mis à jour avec succès');
        Navigator.pop(
          context,
          true,
        ); // Retourner true pour indiquer une modification
      } else {
        _showErrorSnackBar('Erreur lors de la mise à jour du nom');
      }
    }
  }

  Future<void> _emulateCard() async {
    if (_isEmulating) {
      // Arrêter l'émulation
      try {
        bool success = await _nfcService.stopEmulation();
        setState(() {
          _isEmulating = false;
          _emulationError = null;
        });

        if (success) {
          _showSuccessSnackBar('Émulation arrêtée');
        } else {
          _showErrorSnackBar('Erreur lors de l\'arrêt de l\'émulation');
        }
      } catch (e) {
        setState(() {
          _isEmulating = false;
          _emulationError = e.toString();
        });
        _showErrorSnackBar('Erreur: $e');
      }
    } else {
      // Démarrer l'émulation
      if (!_hceSupported) {
        _showErrorSnackBar('HCE n\'est pas supporté sur cet appareil');
        return;
      }

      if (!_hceEnabled) {
        _showErrorSnackBar('Veuillez activer NFC dans les paramètres');
        return;
      }

      setState(() {
        _isEmulating = true;
        _emulationError = null;
      });

      try {
        bool success = await _nfcService.emulateCard(widget.card);

        if (success) {
          _showSuccessSnackBar(
            'Émulation démarrée ! Approchez votre téléphone d\'un lecteur NFC',
          );
          // L'émulation reste active, ne pas modifier _isEmulating ici
        } else {
          setState(() {
            _isEmulating = false;
          });
          _showErrorSnackBar('Erreur lors du démarrage de l\'émulation');
        }
      } catch (e) {
        setState(() {
          _isEmulating = false;
          _emulationError = e.toString();
        });
        _showErrorSnackBar('Erreur: $e');
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSuccessSnackBar('Copié dans le presse-papiers');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Widget _buildInfoCard(String title, String content, {bool copyable = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (copyable) ...[
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () => _copyToClipboard(content),
                    tooltip: 'Copier',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection() {
    if (widget.card.data == null || widget.card.data!.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Aucune donnée supplémentaire disponible',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return _buildInfoCard(
      'Données de la carte',
      widget.card.data!,
      copyable: true,
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} à ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de la carte'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              tooltip: 'Modifier le nom',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section nom de la carte
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nom de la carte',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isEditing) ...[
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Entrez le nom de la carte',
                        ),
                        maxLength: 50,
                        autofocus: true,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isEditing = false;
                                _nameController.text = widget.card.name;
                              });
                            },
                            child: const Text('Annuler'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _updateCardName,
                            child: const Text('Sauvegarder'),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        widget.card.name,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Bouton d'émulation/utilisation
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _emulateCard,
                icon: _isEmulating
                    ? const Icon(Icons.stop, color: Colors.white)
                    : const Icon(Icons.nfc),
                label: Text(
                  _isEmulating ? 'Arrêter l\'émulation' : 'Émuler cette carte',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _isEmulating ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            // Informations d'état HCE
            if (!_hceSupported || !_hceEnabled || _emulationError != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Colors.orange.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'État HCE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!_hceSupported)
                      const Text('• HCE non supporté sur cet appareil'),
                    if (!_hceEnabled)
                      const Text(
                        '• NFC désactivé - Veuillez l\'activer dans les paramètres',
                      ),
                    if (_emulationError != null)
                      Text('• Erreur: $_emulationError'),
                  ],
                ),
              ),
            ],

            // Instructions d'utilisation pour HCE
            if (_isEmulating) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade600,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Émulation active',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Approchez votre téléphone d\'un lecteur NFC pour simuler cette carte.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('En attente de lecture...'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Informations techniques
            const Text(
              'Informations techniques',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            _buildInfoCard(
              'UID (Identifiant unique)',
              widget.card.uid.toUpperCase(),
              copyable: true,
            ),

            _buildInfoCard('Technologie', widget.card.technology),

            _buildInfoCard(
              'Date de création',
              _formatDateTime(widget.card.createdAt),
            ),

            if (widget.card.lastUsed != null)
              _buildInfoCard(
                'Dernière utilisation',
                _formatDateTime(widget.card.lastUsed!),
              ),

            const SizedBox(height: 16),

            // Section données
            const Text(
              'Données stockées',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            _buildDataSection(),

            const SizedBox(height: 32),

            // Note d'information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
