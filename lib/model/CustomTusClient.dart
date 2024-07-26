// import 'package:tus_client_dart/tus_client_dart.dart';
// import 'package:http/http.dart' as http;
//
// class CustomTusClient extends TusClient {
//   late final http.Client _httpClient;
//
//   CustomTusClient(
//       super.file, {
//         super.store,
//         super.maxChunkSize,
//         super.retries,
//         super.retryScale,
//         super.retryInterval,
//         httpClient
//   }) {
//     _httpClient = httpClient ?? http.Client();
//   }
//
//   @override
//
//   int get getOffset => _getOffset();
//
//   @override
//   http.Client getHttpClient() => _httpClient;
// }