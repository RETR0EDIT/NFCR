import 'dart:async';
import 'package:flutter/services.dart';

class HceService {
  static const MethodChannel _channel = MethodChannel('com.example.nfcr/hce');
  static const EventChannel _eventChannel = EventChannel(
    'com.example.nfcr/hce_events',
  );

  static Stream<Map<String, dynamic>>? _eventStream;

  /// Vérifie si HCE est supporté sur cet appareil
  static Future<bool> isHceSupported() async {
    try {
      final bool result = await _channel.invokeMethod('isHceSupported');
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Vérifie si HCE est activé
  static Future<bool> isHceEnabled() async {
    try {
      final bool result = await _channel.invokeMethod('isHceEnabled');
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Démarre l'émulation d'une carte
  static Future<bool> startEmulation({
    required String uid,
    String? data,
    String? technology,
  }) async {
    try {
      final bool result = await _channel.invokeMethod('startEmulation', {
        'uid': uid,
        'data': data,
        'technology': technology,
      });
      return result;
    } catch (e) {
      print('Erreur lors du démarrage de l\'émulation: $e');
      return false;
    }
  }

  /// Arrête l'émulation
  static Future<bool> stopEmulation() async {
    try {
      final bool result = await _channel.invokeMethod('stopEmulation');
      return result;
    } catch (e) {
      print('Erreur lors de l\'arrêt de l\'émulation: $e');
      return false;
    }
  }

  /// Vérifie si l'émulation est en cours
  static Future<bool> isEmulating() async {
    try {
      final bool result = await _channel.invokeMethod('isEmulating');
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Stream pour écouter les événements HCE
  static Stream<Map<String, dynamic>> get eventStream {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map<Map<String, dynamic>>((event) => Map<String, dynamic>.from(event));
    return _eventStream!;
  }
}
