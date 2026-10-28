import 'package:flutter/foundation.dart';

class AppConfig {
  static String get apiUrl {
    const fromEnv = String.fromEnvironment('API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://localhost:5000/api';
      }
    }
    return 'https://jamerchandise.onrender.com/api';
  }
}
