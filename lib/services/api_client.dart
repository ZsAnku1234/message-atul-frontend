import 'package:dio/dio.dart';

Dio createApiClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        // defaultValue: 'http://localhost:5001/api',
        defaultValue: 'http://10.196.219.111:5001/api',
      ),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: false,
    ),
  );

  return dio;
}
