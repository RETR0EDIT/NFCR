import 'package:flutter/material.dart';
import '../models/nfc_card.dart';
import '../services/nfc_service.dart';
import 'scan_screen.dart';
import 'card_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NFCService _nfcService = NFCService();
  final TextEditingController _searchController = TextEditingController();
  List<NFCCard> _cards = [];
  List<NFCCard> _filteredCards = [];
  bool _isLoading = true;
  bool _isNFCAvailable = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _checkNFCAvailability();
    await _loadCards();
  }

  Future<void> _checkNFCAvailability() async {
    bool available = await _nfcService.isNFCAvailable();
    setState(() {
      _isNFCAvailable = available;
    });
  }

  Future<void> _loadCards() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<NFCCard> cards = await _nfcService.getAllSavedCards();
      setState(() {
        _cards = cards;
        _filteredCards = cards;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Erreur lors du chargement des cartes: $e');
    }
  }

  void _filterCards(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCards = _cards;
      } else {
        _filteredCards = _cards
            .where(
              (card) =>
                  card.name.toLowerCase().contains(query.toLowerCase()) ||
                  card.uid.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
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

  Future<void> _navigateToScanScreen() async {
    if (!_isNFCAvailable) {
      _showErrorSnackBar('NFC n\'est pas disponible sur cet appareil');
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanScreen()),
    );

    if (result == true) {
      await _loadCards();
      _showSuccessSnackBar('Carte ajoutée avec succès !');
    }
  }

  Future<void> _navigateToCardDetail(NFCCard card) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CardDetailScreen(card: card)),
    );

    if (result == true) {
      await _loadCards();
    }
  }

  Future<void> _deleteCard(NFCCard card) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Supprimer la carte'),
          content: Text('Êtes-vous sûr de vouloir supprimer "${card.name}" ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      bool success = await _nfcService.deleteCard(card.id!);
      if (success) {
        await _loadCards();
        _showSuccessSnackBar('Carte supprimée avec succès');
      } else {
        _showErrorSnackBar('Erreur lors de la suppression');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Cartes NFC'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export_all':
                  _exportAllCards();
                  break;
                case 'import':
                  _importCards();
                  break;
                case 'manage_exports':
                  _manageExports();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'export_all',
                child: Row(
                  children: [
                    Icon(Icons.upload),
                    SizedBox(width: 8),
                    Text('Exporter toutes les cartes'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Importer des cartes'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'manage_exports',
                child: Row(
                  children: [
                    Icon(Icons.folder),
                    SizedBox(width: 8),
                    Text('Gérer les exports'),
                  ],
                ),
              ),
            ],
          ),
          if (!_isNFCAvailable)
            const Icon(Icons.nfc_outlined, color: Colors.red),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Rechercher par nom ou UID...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterCards,
            ),
          ),

          // Liste des cartes
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCards.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.nfc, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Aucune carte trouvée',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Appuyez sur + pour scanner votre première carte',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadCards,
                    child: ListView.builder(
                      itemCount: _filteredCards.length,
                      itemBuilder: (context, index) {
                        final card = _filteredCards[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              child: const Icon(Icons.nfc, color: Colors.white),
                            ),
                            title: Text(
                              card.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('UID: ${card.uid.toUpperCase()}'),
                                Text('Tech: ${card.technology}'),
                                Text(
                                  'Créée: ${card.createdAt.day}/${card.createdAt.month}/${card.createdAt.year}',
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'details':
                                    _navigateToCardDetail(card);
                                    break;
                                  case 'export':
                                    _exportSingleCard(card);
                                    break;
                                  case 'delete':
                                    _deleteCard(card);
                                    break;
                                }
                              },
                              itemBuilder: (BuildContext context) => [
                                const PopupMenuItem<String>(
                                  value: 'details',
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline),
                                      SizedBox(width: 8),
                                      Text('Détails'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'export',
                                  child: Row(
                                    children: [
                                      Icon(Icons.upload_outlined),
                                      SizedBox(width: 8),
                                      Text('Exporter'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Supprimer',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _navigateToCardDetail(card),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToScanScreen,
        tooltip: 'Scanner une nouvelle carte',
        child: const Icon(Icons.add),
      ),
    );
  }

  // ===== Méthodes d'export/import =====

  Future<void> _exportSingleCard(NFCCard card) async {
    try {
      String? filePath = await _nfcService.exportCard(card);

      if (filePath != null) {
        // Proposer de partager le fichier
        bool? share = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Export réussi'),
              content: Text(
                'La carte "${card.name}" a été exportée.\n\nVoulez-vous partager le fichier ?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Non'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Partager'),
                ),
              ],
            );
          },
        );

        if (share == true) {
          bool shared = await _nfcService.shareExportFile(filePath);
          if (!shared) {
            _showErrorSnackBar('Erreur lors du partage');
          }
        } else {
          _showSuccessSnackBar('Carte exportée avec succès');
        }
      } else {
        _showErrorSnackBar('Erreur lors de l\'export');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur: $e');
    }
  }

  Future<void> _exportAllCards() async {
    if (_cards.isEmpty) {
      _showErrorSnackBar('Aucune carte à exporter');
      return;
    }

    try {
      String? filePath = await _nfcService.exportAllCards();

      if (filePath != null) {
        // Proposer de partager le fichier
        bool? share = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Export réussi'),
              content: Text(
                '${_cards.length} cartes ont été exportées.\n\nVoulez-vous partager le fichier ?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Non'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Partager'),
                ),
              ],
            );
          },
        );

        if (share == true) {
          bool shared = await _nfcService.shareExportFile(filePath);
          if (!shared) {
            _showErrorSnackBar('Erreur lors du partage');
          }
        } else {
          _showSuccessSnackBar('${_cards.length} cartes exportées avec succès');
        }
      } else {
        _showErrorSnackBar('Erreur lors de l\'export');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur: $e');
    }
  }

  Future<void> _importCards() async {
    try {
      String? filePath = await _nfcService.selectImportFile();

      if (filePath == null) return;

      // Afficher les informations du fichier
      Map<String, dynamic>? fileInfo = await _nfcService.getImportFileInfo(
        filePath,
      );

      if (fileInfo == null) {
        _showErrorSnackBar('Impossible de lire le fichier');
        return;
      }

      // Confirmer l'import
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirmer l\'import'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fichier: ${fileInfo['file_name']}'),
                Text('Nombre de cartes: ${fileInfo['card_count']}'),
                Text('Version: ${fileInfo['version']}'),
                if (fileInfo['export_date'] != null)
                  Text(
                    'Date d\'export: ${DateTime.parse(fileInfo['export_date']).toLocal().toString().split('.')[0]}',
                  ),
                const SizedBox(height: 16),
                const Text('Les cartes avec le même UID seront ignorées.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Importer'),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        ImportResult result = await _nfcService.importCardsFromFile(filePath);

        // Afficher les résultats
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                result.success ? 'Import terminé' : 'Erreur d\'import',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.message),
                  if (result.success && result.importedCount > 0) ...[
                    const SizedBox(height: 8),
                    Text('Nouvelles cartes: ${result.importedCount}'),
                    if (result.duplicatesCount > 0)
                      Text('Doublons ignorés: ${result.duplicatesCount}'),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );

        if (result.success && result.importedCount > 0) {
          await _loadCards();
        }
      }
    } catch (e) {
      _showErrorSnackBar('Erreur: $e');
    }
  }

  Future<void> _manageExports() async {
    try {
      List<String> exportFiles = await _nfcService.listExportFiles();

      if (exportFiles.isEmpty) {
        _showErrorSnackBar('Aucun fichier d\'export trouvé');
        return;
      }

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Gérer les exports'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: exportFiles.length,
                itemBuilder: (context, index) {
                  String filePath = exportFiles[index];
                  String fileName = filePath.split('/').last;

                  return ListTile(
                    leading: const Icon(Icons.file_present),
                    title: Text(fileName),
                    subtitle: FutureBuilder<Map<String, dynamic>?>(
                      future: _nfcService.getImportFileInfo(filePath),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Text('${snapshot.data!['card_count']} cartes');
                        }
                        return const Text('...');
                      },
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        switch (value) {
                          case 'share':
                            bool shared = await _nfcService.shareExportFile(
                              filePath,
                            );
                            if (!shared) {
                              _showErrorSnackBar('Erreur lors du partage');
                            }
                            break;
                          case 'delete':
                            bool? confirmDelete = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Supprimer le fichier'),
                                content: Text('Supprimer $fileName ?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Annuler'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Supprimer'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmDelete == true) {
                              bool deleted = await _nfcService.deleteExportFile(
                                filePath,
                              );
                              if (deleted) {
                                Navigator.pop(context); // Fermer le dialog
                                _manageExports(); // Recharger la liste
                              } else {
                                _showErrorSnackBar(
                                  'Erreur lors de la suppression',
                                );
                              }
                            }
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share),
                              SizedBox(width: 8),
                              Text('Partager'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Supprimer',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _showErrorSnackBar('Erreur: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
