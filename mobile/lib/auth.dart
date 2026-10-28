import 'dart:io';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'models.dart';

class AuthController extends ChangeNotifier {
  AuthController(this.api);

  final ApiClient api;
  User? user;
  bool loading = true;

  Future<void> bootstrap() async {
    await api.loadToken();
    if (api.token == null || api.token!.isEmpty) {
      loading = false;
      notifyListeners();
      return;
    }
    try {
      user = await api.me();
    } catch (_) {
      await api.clearToken();
      user = null;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    user = await api.login(email, password);
    notifyListeners();
  }

  Future<void> loginWithPin({required String userId, required String pincode}) async {
    user = await api.loginWithPin(userId: userId, pincode: pincode);
    notifyListeners();
  }

  Future<void> logout() async {
    await api.clearToken();
    user = null;
    notifyListeners();
  }

  void setUser(User next) {
    user = next;
    notifyListeners();
  }

  Future<void> saveProfile({
    required String name,
    required String email,
    File? image,
    bool removeImage = false,
  }) async {
    final next = await api.updateProfile(
      name: name,
      email: email,
      image: image,
      removeImage: removeImage,
    );
    setUser(next);
  }
}
