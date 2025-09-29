import 'dart:convert';
import 'dart:typed_data';
import 'package:nfc_manager/nfc_manager.dart';
import '../models/nfc_card.dart';
import 'database_service.dart';
import 'hce_service.dart';
import 'file_manager_service.dart';

class NFCService {
  static final NFCService _instance = NFCService._internal();
  factory NFCService() => _instance;
  NFCService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final FileManagerService _fileManagerService = FileManagerService();

  Future<bool> isNFCAvailable() async {
    return await NfcManager.instance.isAvailable();
  }

  Future<void> startNFCSession({
    required Function(NFCCard) onCardDetected,
    required Function(String) onError,
  }) async {
    try {
      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            String uid = _bytesToHex(
              tag.data['nfca']?['identifier'] ??
                  tag.data['nfcb']?['identifier'] ??
                  tag.data['nfcf']?['identifier'] ??
                  tag.data['nfcv']?['identifier'] ??
                  tag.data['isodep']?['identifier'] ??
                  Uint8List(0),
            );

            String technology = _getTechnology(tag);
            String? data = await _extractData(tag);

            NFCCard card = NFCCard(
              name: 'Carte NFC ${uid.substring(0, 8)}',
              uid: uid,
              technology: technology,
              data: data,
              createdAt: DateTime.now(),
            );

            onCardDetected(card);
          } catch (e) {
            onError('Erreur lors de la lecture de la carte: $e');
          }
        },
      );
    } catch (e) {
      onError('Erreur lors du démarrage du scan NFC: $e');
    }
  }

  Future<void> stopNFCSession() async {
    NfcManager.instance.stopSession();
  }

  Future<bool> emulateCard(NFCCard card) async {
    try {
      // Vérifier si HCE est supporté et activé
      bool hceSupported = await HceService.isHceSupported();
      bool hceEnabled = await HceService.isHceEnabled();

      if (!hceSupported) {
        throw Exception('HCE n\'est pas supporté sur cet appareil');
      }

      if (!hceEnabled) {
        throw Exception('NFC n\'est pas activé sur cet appareil');
      }

      // Démarrer l'émulation HCE avec les données de la carte
      bool emulationStarted = await HceService.startEmulation(
        uid: card.uid,
        data: card.data,
        technology: card.technology,
      );

      if (emulationStarted) {
        // Mettre à jour la dernière utilisation dans la base de données
        await _databaseService.updateLastUsed(card.id!);
        return true;
      } else {
        throw Exception('Impossible de démarrer l\'émulation HCE');
      }
    } catch (e) {
      print('Erreur lors de l\'émulation: $e');
      return false;
    }
  }

  Future<bool> stopEmulation() async {
    try {
      return await HceService.stopEmulation();
    } catch (e) {
      print('Erreur lors de l\'arrêt de l\'émulation: $e');
      return false;
    }
  }

  Future<bool> isEmulating() async {
    try {
      return await HceService.isEmulating();
    } catch (e) {
      return false;
    }
  }

  Stream<Map<String, dynamic>> get hceEventStream {
    return HceService.eventStream;
  }

  String _bytesToHex(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  String _getTechnology(NfcTag tag) {
    if (tag.data.containsKey('nfca')) return 'NFC-A';
    if (tag.data.containsKey('nfcb')) return 'NFC-B';
    if (tag.data.containsKey('nfcf')) return 'NFC-F';
    if (tag.data.containsKey('nfcv')) return 'NFC-V';
    if (tag.data.containsKey('isodep')) return 'ISO-DEP';
    if (tag.data.containsKey('mifareclassic')) return 'MIFARE Classic';
    if (tag.data.containsKey('mifareultralight')) return 'MIFARE Ultralight';
    if (tag.data.containsKey('ndef')) return 'NDEF';
    return 'Unknown';
  }

  Future<String?> _extractData(NfcTag tag) async {
    try {
      // Essayer de lire les données NDEF si disponibles
      if (tag.data.containsKey('ndef')) {
        final ndef = Ndef.from(tag);
        if (ndef != null) {
          final ndefMessage = await ndef.read();
          if (ndefMessage.records.isNotEmpty) {
            Map<String, dynamic> ndefData = {};
            for (int i = 0; i < ndefMessage.records.length; i++) {
              final record = ndefMessage.records[i];
              ndefData['record_$i'] = {
                'typeNameFormat': record.typeNameFormat.index,
                'type': _bytesToHex(record.type),
                'identifier': _bytesToHex(record.identifier),
                'payload': _bytesToHex(record.payload),
              };
            }
            return jsonEncode(ndefData);
          }
        }
      }

      // Si pas de données NDEF, essayer d'autres technologies
      Map<String, dynamic> rawData = {};
      tag.data.forEach((key, value) {
        if (value is Map) {
          rawData[key] = value;
        }
      });

      return jsonEncode(rawData);
    } catch (e) {
      return null;
    }
  }

  Future<NFCCard?> saveScannedCard(NFCCard card, String customName) async {
    try {
      // Vérifier si la carte existe déjà
      NFCCard? existingCard = await _databaseService.getCardByUid(card.uid);

      if (existingCard != null) {
        // Mettre à jour le nom et la dernière utilisation
        NFCCard updatedCard = existingCard.copyWith(
          name: customName,
          lastUsed: DateTime.now(),
        );
        await _databaseService.updateCard(updatedCard);
        return updatedCard;
      } else {
        // Créer une nouvelle carte
        NFCCard newCard = card.copyWith(name: customName);
        int id = await _databaseService.insertCard(newCard);
        return newCard.copyWith(id: id);
      }
    } catch (e) {
      return null;
    }
  }

  Future<List<NFCCard>> getAllSavedCards() async {
    return await _databaseService.getAllCards();
  }

  Future<List<NFCCard>> searchCards(String query) async {
    return await _databaseService.searchCards(query);
  }

  Future<bool> deleteCard(int cardId) async {
    try {
      await _databaseService.deleteCard(cardId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateCardName(int cardId, String newName) async {
    try {
      // Cette méthode nécessite une implémentation dans DatabaseService
      // Pour l'instant, nous récupérons la carte, modifions le nom et la sauvegardons
      final cards = await _databaseService.getAllCards();
      final card = cards.firstWhere((c) => c.id == cardId);
      final updatedCard = card.copyWith(name: newName);
      await _databaseService.updateCard(updatedCard);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ===== Méthodes d'export/import =====

  /// Exporte une carte spécifique
  Future<String?> exportCard(NFCCard card) async {
    try {
      return await _fileManagerService.exportSingleCard(card);
    } catch (e) {
      print('Erreur lors de l\'export de carte: $e');
      return null;
    }
  }

  /// Exporte toutes les cartes
  Future<String?> exportAllCards() async {
    try {
      List<NFCCard> cards = await getAllSavedCards();
      return await _fileManagerService.exportAllCards(cards);
    } catch (e) {
      print('Erreur lors de l\'export de toutes les cartes: $e');
      return null;
    }
  }

  /// Partage un fichier d'export
  Future<bool> shareExportFile(String filePath) async {
    try {
      return await _fileManagerService.shareExportFile(filePath);
    } catch (e) {
      print('Erreur lors du partage: $e');
      return false;
    }
  }

  /// Sélectionne un fichier à importer
  Future<String?> selectImportFile() async {
    try {
      return await _fileManagerService.selectImportFile();
    } catch (e) {
      print('Erreur lors de la sélection: $e');
      return null;
    }
  }

  /// Importe des cartes depuis un fichier
  Future<ImportResult> importCardsFromFile(String filePath) async {
    try {
      // Lire les cartes du fichier
      List<NFCCard>? importedCards = await _fileManagerService
          .importCardsFromFile(filePath);

      if (importedCards == null) {
        return ImportResult(
          success: false,
          message: 'Impossible de lire le fichier',
        );
      }

      if (importedCards.isEmpty) {
        return ImportResult(
          success: false,
          message: 'Aucune carte trouvée dans le fichier',
        );
      }

      // Vérifier les doublons
      List<NFCCard> existingCards = await getAllSavedCards();
      List<NFCCard> newCards = [];
      List<NFCCard> duplicates = [];

      for (NFCCard importedCard in importedCards) {
        bool isDuplicate = existingCards.any(
          (existing) => existing.uid == importedCard.uid,
        );

        if (isDuplicate) {
          duplicates.add(importedCard);
        } else {
          newCards.add(importedCard);
        }
      }

      // Importer les nouvelles cartes
      int importedCount = 0;
      for (NFCCard card in newCards) {
        try {
          // Créer une nouvelle carte sans ID (sera généré par la DB)
          NFCCard newCard = card.copyWith(id: null, createdAt: DateTime.now());
          await _databaseService.insertCard(newCard);
          importedCount++;
        } catch (e) {
          print('Erreur lors de l\'import de la carte ${card.name}: $e');
        }
      }

      String message =
          'Import terminé: $importedCount nouvelles cartes importées';
      if (duplicates.isNotEmpty) {
        message += ', ${duplicates.length} doublons ignorés';
      }

      return ImportResult(
        success: true,
        message: message,
        importedCount: importedCount,
        duplicatesCount: duplicates.length,
        newCards: newCards,
        duplicates: duplicates,
      );
    } catch (e) {
      print('Erreur lors de l\'import: $e');
      return ImportResult(success: false, message: 'Erreur: $e');
    }
  }

  /// Obtient les informations d'un fichier d'import
  Future<Map<String, dynamic>?> getImportFileInfo(String filePath) async {
    try {
      return await _fileManagerService.getImportFileInfo(filePath);
    } catch (e) {
      print('Erreur lors de la lecture des informations: $e');
      return null;
    }
  }

  /// Liste les fichiers d'export existants
  Future<List<String>> listExportFiles() async {
    try {
      return await _fileManagerService.listExportFiles();
    } catch (e) {
      print('Erreur lors de la liste: $e');
      return [];
    }
  }

  /// Supprime un fichier d'export
  Future<bool> deleteExportFile(String filePath) async {
    try {
      return await _fileManagerService.deleteExportFile(filePath);
    } catch (e) {
      print('Erreur lors de la suppression: $e');
      return false;
    }
  }
}

/// Classe pour les résultats d'import
class ImportResult {
  final bool success;
  final String message;
  final int importedCount;
  final int duplicatesCount;
  final List<NFCCard> newCards;
  final List<NFCCard> duplicates;

  ImportResult({
    required this.success,
    required this.message,
    this.importedCount = 0,
    this.duplicatesCount = 0,
    this.newCards = const [],
    this.duplicates = const [],
  });
}
