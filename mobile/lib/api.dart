import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({this.onUnauthorized});

  final void Function()? onUnauthorized;
  String? token;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = AppConfig.apiUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base$path').replace(
      queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
    );
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('ja_token');
  }

  Future<void> saveToken(String value) async {
    token = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ja_token', value);
  }

  Future<void> clearToken() async {
    token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ja_token');
  }

  dynamic _decode(http.Response response, {bool skipAuthRedirect = false}) {
    dynamic body;
    try {
      body = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      body = null;
    }

    if (response.statusCode == 401 && !skipAuthRedirect) {
      onUnauthorized?.call();
    }

    if (response.statusCode >= 400) {
      final message = body is Map ? '${body['message'] ?? 'Request failed.'}' : 'Request failed.';
      throw ApiException(message, status: response.statusCode);
    }
    return body;
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool skipAuthRedirect = false,
  }) async {
    final uri = _uri(path, query);
    late http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: _headers);
      case 'POST':
        response = await http.post(uri, headers: _headers, body: jsonEncode(body ?? {}));
      case 'PUT':
        response = await http.put(uri, headers: _headers, body: jsonEncode(body ?? {}));
      case 'DELETE':
        response = await http.delete(uri, headers: _headers);
      default:
        throw ApiException('Unsupported method $method');
    }
    return _decode(response, skipAuthRedirect: skipAuthRedirect);
  }

  Future<dynamic> _multipart(
    String method,
    String path, {
    required Map<String, String> fields,
    File? file,
    String fileField = 'image',
  }) async {
    final request = http.MultipartRequest(method, _uri(path));
    if (token != null && token!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields.addAll(fields);
    if (file != null) {
      request.files.add(await http.MultipartFile.fromPath(fileField, file.path));
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Future<User> login(String email, String password) async {
    final data = await _send(
      'POST',
      '/auth/login',
      body: {'email': email.trim().toLowerCase(), 'password': password},
      skipAuthRedirect: true,
    );
    await saveToken('${data['token']}');
    return User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<List<NamedRef>> staff() async {
    final data = await _send('GET', '/auth/staff', skipAuthRedirect: true);
    return (data as List).whereType<Map>().map((item) => NamedRef.fromJson(item)).toList();
  }

  Future<User> loginWithPin({required String userId, required String pincode}) async {
    final data = await _send(
      'POST',
      '/auth/pin-login',
      body: {'userId': userId, 'pincode': pincode},
      skipAuthRedirect: true,
    );
    await saveToken('${data['token']}');
    return User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<User> me() async {
    final data = await _send('GET', '/auth/me');
    return User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<void> verifySuperAdminPin(String pincode) async {
    await _send(
      'POST',
      '/auth/verify-superadmin-pin',
      body: {'pincode': pincode},
      skipAuthRedirect: true,
    );
  }

  Future<User> updateProfile({
    required String name,
    required String email,
    File? image,
    bool removeImage = false,
  }) async {
    final data = await _multipart(
      'PUT',
      '/auth/profile',
      fields: {
        'name': name,
        'email': email,
        if (removeImage) 'removeImage': 'true',
      },
      file: image,
    );
    return User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<void> updatePassword({required String currentPassword, required String newPassword}) async {
    await _send(
      'PUT',
      '/auth/password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<List<Product>> products({bool? active}) async {
    final data = await _send(
      'GET',
      '/products',
      query: {if (active == true) 'active': 'true'},
    );
    return (data as List).whereType<Map>().map((item) => Product.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  Future<void> saveProduct(Map<String, String> fields, {String? id, File? image}) async {
    if (id == null) {
      await _multipart('POST', '/products', fields: fields, file: image);
    } else {
      await _multipart('PUT', '/products/$id', fields: fields, file: image);
    }
  }

  Future<void> deleteProduct(String id) async {
    await _send('DELETE', '/products/$id');
  }

  Future<List<Category>> categories() async {
    final data = await _send('GET', '/categories');
    return (data as List).whereType<Map>().map((item) => Category.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  Future<void> saveCategory({String? id, required String name, String description = ''}) async {
    final body = {'name': name, 'description': description};
    if (id == null) {
      await _send('POST', '/categories', body: body);
    } else {
      await _send('PUT', '/categories/$id', body: body);
    }
  }

  Future<void> deleteCategory(String id) async {
    await _send('DELETE', '/categories/$id');
  }

  Future<List<Sale>> sales({int limit = 100}) async {
    final data = await _send('GET', '/sales', query: {'limit': '$limit'});
    return (data as List).whereType<Map>().map((item) => Sale.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  Future<Sale> createSale(Map<String, dynamic> body) async {
    final data = await _send('POST', '/sales', body: body);
    return Sale.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<DashboardData> dashboard({required int year}) async {
    final data = await _send('GET', '/dashboard', query: {'year': '$year'});
    return DashboardData.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<MonthDetail> dashboardMonth({required int year, required int month}) async {
    final data = await _send('GET', '/dashboard/month', query: {'year': '$year', 'month': '$month'});
    return MonthDetail.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<CutoffReport> cutoff({
    required String date,
    required String payment,
    required String cashier,
  }) async {
    final data = await _send(
      'GET',
      '/cutoff',
      query: {'date': date, 'payment': payment, 'cashier': cashier},
    );
    return CutoffReport.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<User>> users() async {
    final data = await _send('GET', '/users');
    return (data as List).whereType<Map>().map((item) => User.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  Future<void> saveUser({String? id, required Map<String, dynamic> body}) async {
    if (id == null) {
      await _send('POST', '/users', body: body);
    } else {
      await _send('PUT', '/users/$id', body: body);
    }
  }

  Future<void> deleteUser(String id) async {
    await _send('DELETE', '/users/$id');
  }
}
