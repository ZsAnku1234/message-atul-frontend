import 'package:dio/dio.dart';

Dio createApiClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        // defaultValue: 'http://localhost:3000/api',
        defaultValue: 'https://api.nuttgram.com/api',
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
