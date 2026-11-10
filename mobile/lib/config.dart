import 'package:flutter/foundation.dart';

class AppConfig {
  static String get apiUrl {
    const fromEnv = String.fromEnvironment('API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://localhost:5000/api/jamerchandiseRoutes';
      }
    }
    return 'https://178.128.211.176/api/jamerchandiseRoutes';
  }
}
