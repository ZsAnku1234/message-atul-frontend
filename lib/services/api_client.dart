import 'package:dio/dio.dart';

const _defaultConnectTimeout = Duration(seconds: 120);
const _defaultTransferTimeout = Duration(minutes: 30);

Dio createApiClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        // defaultValue: 'http://localhost:3000/api',
        defaultValue: 'https://api.nuttgram.com/api',
      ),
      connectTimeout: _defaultConnectTimeout,
      receiveTimeout: _defaultTransferTimeout,
      sendTimeout: _defaultTransferTimeout,
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    LogInterceptor(
      requestBody: false, // Prevent logging huge multipart payloads.
      responseBody: false,
      requestHeader: false,
    ),
  );

  return dio;
}
