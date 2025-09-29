import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../models/nfc_card.dart';

class FileManagerService {
  /// Demande les permissions nécessaires pour accéder au stockage
  Future<bool> requestStoragePermissions() async {
    if (Platform.isAndroid) {
      // Pour Android 13+ (API 33+)
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }

      // Demander les permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.manageExternalStorage,
      ].request();

      return statuses[Permission.storage]?.isGranted == true ||
          statuses[Permission.manageExternalStorage]?.isGranted == true;
    }
    return true; // iOS n'a pas besoin de permissions spéciales
  }

  /// Exporte une carte NFC vers un fichier JSON
  Future<String?> exportSingleCard(NFCCard card) async {
    try {
      if (!await requestStoragePermissions()) {
        throw Exception('Permissions de stockage refusées');
      }

      // Créer le contenu JSON
      Map<String, dynamic> exportData = {
        'version': '1.0',
        'export_date': DateTime.now().toIso8601String(),
        'card_count': 1,
        'cards': [card.toMap()],
      };

      String jsonContent = const JsonEncoder.withIndent(
        '  ',
      ).convert(exportData);

      // Obtenir le répertoire de sauvegarde
      Directory? directory = await getExternalStorageDirectory();
      if (directory == null) {
        directory = await getApplicationDocumentsDirectory();
      }

      // Créer le fichier
      String fileName =
          'nfcr_card_${card.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.json';
      File file = File('${directory.path}/$fileName');

      await file.writeAsString(jsonContent);
      return file.path;
    } catch (e) {
      print('Erreur lors de l\'export de carte: $e');
      return null;
    }
  }

  /// Exporte toutes les cartes vers un fichier JSON
  Future<String?> exportAllCards(List<NFCCard> cards) async {
    try {
      if (!await requestStoragePermissions()) {
        throw Exception('Permissions de stockage refusées');
      }

      // Créer le contenu JSON
      Map<String, dynamic> exportData = {
        'version': '1.0',
        'export_date': DateTime.now().toIso8601String(),
        'card_count': cards.length,
        'cards': cards.map((card) => card.toMap()).toList(),
      };

      String jsonContent = const JsonEncoder.withIndent(
        '  ',
      ).convert(exportData);

      // Obtenir le répertoire de sauvegarde
      Directory? directory = await getExternalStorageDirectory();
      if (directory == null) {
        directory = await getApplicationDocumentsDirectory();
      }

      // Créer le fichier
      String fileName =
          'nfcr_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      File file = File('${directory.path}/$fileName');

      await file.writeAsString(jsonContent);
      return file.path;
    } catch (e) {
      print('Erreur lors de l\'export des cartes: $e');
      return null;
    }
  }

  /// Partage un fichier d'export
  Future<bool> shareExportFile(String filePath) async {
    try {
      File file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Fichier inexistant');
      }

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Sauvegarde des cartes NFC - NFCR',
        subject: 'Export NFCR',
      );

      return true;
    } catch (e) {
      print('Erreur lors du partage: $e');
      return false;
    }
  }

  /// Sélectionne un fichier d'import
  Future<String?> selectImportFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        return result.files.single.path!;
      }

      return null;
    } catch (e) {
      print('Erreur lors de la sélection du fichier: $e');
      return null;
    }
  }

  /// Importe des cartes depuis un fichier JSON
  Future<List<NFCCard>?> importCardsFromFile(String filePath) async {
    try {
      File file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Fichier inexistant');
      }

      String jsonContent = await file.readAsString();
      Map<String, dynamic> importData = jsonDecode(jsonContent);

      // Vérifier le format du fichier
      if (!importData.containsKey('cards') ||
          !importData.containsKey('version')) {
        throw Exception('Format de fichier invalide');
      }

      // Vérifier la version
      String version = importData['version'];
      if (version != '1.0') {
        throw Exception('Version de fichier non supportée: $version');
      }

      // Convertir les données en objets NFCCard
      List<dynamic> cardsData = importData['cards'];
      List<NFCCard> cards = cardsData
          .map(
            (cardData) => NFCCard.fromMap(Map<String, dynamic>.from(cardData)),
          )
          .toList();

      return cards;
    } catch (e) {
      print('Erreur lors de l\'import: $e');
      return null;
    }
  }

  /// Obtient les informations d'un fichier d'export
  Future<Map<String, dynamic>?> getImportFileInfo(String filePath) async {
    try {
      File file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      String jsonContent = await file.readAsString();
      Map<String, dynamic> importData = jsonDecode(jsonContent);

      return {
        'version': importData['version'] ?? 'Inconnue',
        'export_date': importData['export_date'],
        'card_count': importData['card_count'] ?? 0,
        'file_size': await file.length(),
        'file_name': file.path.split('/').last,
      };
    } catch (e) {
      print('Erreur lors de la lecture des informations: $e');
      return null;
    }
  }

  /// Supprime un fichier d'export
  Future<bool> deleteExportFile(String filePath) async {
    try {
      File file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Erreur lors de la suppression: $e');
      return false;
    }
  }

  /// Liste les fichiers d'export existants
  Future<List<String>> listExportFiles() async {
    try {
      Directory? directory = await getExternalStorageDirectory();
      if (directory == null) {
        directory = await getApplicationDocumentsDirectory();
      }

      List<FileSystemEntity> files = directory.listSync();
      List<String> exportFiles = [];

      for (FileSystemEntity file in files) {
        if (file is File &&
            file.path.contains('nfcr') &&
            file.path.endsWith('.json')) {
          exportFiles.add(file.path);
        }
      }

      // Trier par date de modification (plus récent en premier)
      exportFiles.sort((a, b) {
        File fileA = File(a);
        File fileB = File(b);
        return fileB.lastModifiedSync().compareTo(fileA.lastModifiedSync());
      });

      return exportFiles;
    } catch (e) {
      print('Erreur lors de la liste des fichiers: $e');
      return [];
    }
  }
}
