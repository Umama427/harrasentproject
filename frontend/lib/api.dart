import 'package:dio/dio.dart';
import 'dart:typed_data';

/// Change the backend address when building:
/// flutter run -d chrome --dart-define=API_URL=https://your-server/api
class Api {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: const String.fromEnvironment('API_URL', defaultValue: 'http://localhost:4000/api'),
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  static String? token;
  static Map<String, dynamic>? user;

  static Future<Map<String, dynamic>> _req(String method, String path,
      {dynamic body, Map<String, dynamic>? query}) async {
    try {
      final r = await _dio.request(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, headers: token == null ? null : {'Authorization': 'Bearer $token'}),
      );
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      final d = e.response?.data;
      if (d is Map && d['message'] != null) throw d['message'].toString();
      throw 'Cannot reach the server. Is the backend running?';
    }
  }

  static Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) => _req('GET', path, query: query);
  static Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) => _req('POST', path, body: body ?? {});

  static Future<List<dynamic>> list(String path, {Map<String, dynamic>? query}) async =>
      List<dynamic>.from((await get(path, query: query))['data'] as List);

  static Future<Map<String, dynamic>> obj(String path) async =>
      Map<String, dynamic>.from((await get(path))['data'] as Map);

  static Future<void> upload(String path, Uint8List bytes, String filename) async {
    // ignore: avoid_print
    print('[UPLOAD] path=$path filename=$filename size=${bytes.length}B token=${token == null ? "NULL" : "present"}');
    if (token == null) throw 'You are not logged in. Please sign in again.';
    try {
      final form = FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: filename)});
      final r = await _dio.post(path, data: form, options: Options(headers: {'Authorization': 'Bearer $token'}));
      // ignore: avoid_print
      print('[UPLOAD] success: ${r.statusCode}');
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[UPLOAD] FAILED: status=${e.response?.statusCode} data=${e.response?.data} message=${e.message}');
      final d = e.response?.data;
      if (d is Map && d['message'] != null) throw d['message'].toString();
      throw 'Upload failed: ${e.message ?? "Unknown error"}';
    }
  }

  /// Downloads a protected file (e.g. evidence) as raw bytes, using the auth token.
  static Future<Uint8List> downloadBytes(String path) async {
    if (token == null) throw 'You are not logged in. Please sign in again.';
    try {
      final r = await _dio.get(
        path,
        options: Options(responseType: ResponseType.bytes, headers: {'Authorization': 'Bearer $token'}),
      );
      return Uint8List.fromList(List<int>.from(r.data as List));
    } on DioException catch (e) {
      final d = e.response?.data;
      if (d is Map && d['message'] != null) throw d['message'].toString();
      throw 'Download failed: ${e.message ?? "Unknown error"}';
    }
  }

  static void logout() {
    token = null;
    user = null;
  }
}