import 'dart:convert';
import 'dart:typed_data';

import 'package:acepocket/core/api/api_client.dart';
import 'package:acepocket/core/api/api_exception.dart';
import 'package:acepocket/core/models/server.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? request;
  List<int> body = const [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      body = chunks.expand((chunk) => chunk).toList();
    }
    return ResponseBody.fromString(
      '{"data":{"accepted":true}}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _httpsServer = ServerConfig(
  id: 'server-1',
  name: '测试面板',
  baseUrl: 'https://panel.example.com:8443/',
  tokenId: '42',
  token: 'secret-token',
  entrance: '/secret/',
);

void main() {
  test('ApiClient 发出的 URL、body 与签名头来自同一规范化结果', () async {
    final adapter = _CapturingAdapter();
    final client = ApiClient(
      _httpsServer,
      httpClientAdapter: adapter,
      timestampProvider: () => 1700000000,
    );

    final result = await client.post(
      'widgets',
      query: {
        'z': "!*'() ~",
        'ignored': null,
        'a': ['x y', '中文'],
      },
      body: {'name': '测试'},
    );

    expect(result, {'accepted': true});
    final request = adapter.request!;
    expect(request.method, 'POST');
    expect(
      request.uri.toString(),
      'https://panel.example.com:8443/secret/api/widgets?'
      'a=x+y&a=%E4%B8%AD%E6%96%87&z=%21%2A%27%28%29+~',
    );
    expect(utf8.decode(adapter.body), '{"name":"测试"}');
    expect(request.headers['X-Timestamp'], '1700000000');
    expect(request.headers[Headers.contentTypeHeader], Headers.jsonContentType);
    expect(
      request.headers['Authorization'],
      'HMAC-SHA256 Credential=42, '
      'Signature=d4ff06594bdfeff97a98971f21dbf7af1713562f1abef89714dfb549c1fafdc3',
    );
  });

  test('旧 HTTP 配置在发起网络请求前返回明确错误', () async {
    final adapter = _CapturingAdapter();
    final client = ApiClient(
      _httpsServer.copyWith(baseUrl: 'http://panel.example.com:8080'),
      httpClientAdapter: adapter,
    );

    await expectLater(
      client.get('/home/panel'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('必须使用 HTTPS'),
        ),
      ),
    );
    expect(adapter.request, isNull);
  });
}
