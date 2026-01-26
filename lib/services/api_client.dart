import 'package:dio/dio.dart';

const _defaultConnectTimeout = Duration(hours: 5);
const _defaultTransferTimeout = Duration(hours: 5);

Dio createApiClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://10.0.2.2:3000/api',
        // defaultValue: 'https://api.nuttgram.com/api',
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
