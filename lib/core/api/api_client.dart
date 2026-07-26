import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../models/server.dart';
import 'api_exception.dart';

/// AcePanel HTTP API 客户端。
///
/// 认证方式为「API 令牌 + HMAC-SHA256 签名」，签名算法与面板源码
/// `internal/data/user_token.go` 的 `ValidateReq()` 逐字段对齐：
///
/// ```
/// canonicalRequest = METHOD \n PATH \n QUERY \n SHA256hex(body)
/// stringToSign     = "HMAC-SHA256" \n <unix 秒时间戳> \n SHA256hex(canonicalRequest)
/// signature        = hex( HMAC-SHA256( key = 令牌, stringToSign ) )
/// 请求头:
///   Authorization: HMAC-SHA256 Credential=<token_id>, Signature=<signature>
///   X-Timestamp: <unix 秒时间戳>
/// ```
///
/// 源码核对要点（以 commit 3a2f0db 为准）：
/// - PATH 为服务端看到的 `req.URL.Path`，含 `/api` 前缀。若面板设置了「访问入口」，
///   请求需发往 `<entrance>/api/...`，但入口中间件（entrance.go 情况三）会在鉴权前
///   把路径重写回 `/api/...`，因此**参与签名的 PATH 恒为 `/api/...`（不含入口前缀）**。
/// - QUERY 为 Go `url.Values.Encode()` 的结果：键按字典序排序、
///   `url.QueryEscape` 编码（空格 -> `+`，保留 `-._~` 与字母数字，其余 %XX 大写）。
///   Dart 的 `Uri.encodeQueryComponent` 保留 `!*'()`，与 Go 不一致，
///   因此这里自行实现 [_goQueryEscape]。发出的 URL 使用与签名完全相同的 query 串。
/// - body 为实际发送的原始字节；无 body 时对空字符串求 SHA256。
/// - 时间戳有效窗口 300 秒（服务端只拒绝过期）。
///
/// 响应统一解包：2xx 时返回响应 JSON 的 `data` 字段（可能为 null / Map / List / 标量），
/// 否则抛出 [ApiException]（message 取 `msg` 字段）。
class ApiClient {
  ApiClient(this.server) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
    ));
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 15);
        if (server.allowSelfSigned) {
          // 用户在服务器配置中显式允许自签名证书时放行。
          client.badCertificateCallback = (cert, host, port) => true;
        }
        return client;
      },
    );
  }

  final ServerConfig server;
  late final Dio _dio;

  /// [receiveTimeout] 用于个别耗时远超默认 60 秒的接口（如服务器跑分），
  /// 省略时使用客户端默认值。
  Future<dynamic> get(String path,
          {Map<String, dynamic>? query, Duration? receiveTimeout}) =>
      _request('GET', path, query: query, receiveTimeout: receiveTimeout);

  Future<dynamic> post(String path,
          {Object? body,
          Map<String, dynamic>? query,
          Duration? receiveTimeout}) =>
      _request('POST', path,
          body: body, query: query, receiveTimeout: receiveTimeout);

  Future<dynamic> put(String path,
          {Object? body,
          Map<String, dynamic>? query,
          Duration? receiveTimeout}) =>
      _request('PUT', path,
          body: body, query: query, receiveTimeout: receiveTimeout);

  /// DELETE 请求。
  ///
  /// [query] 用于面板中把参数声明为 `query:"xxx"` 的删除接口
  /// （如 `DELETE /api/user_passkeys/{id}?user_id=`，见
  /// `internal/request/user_passkey.go`）；query 会参与 HMAC 签名的规范化，
  /// 因此**必须**通过本参数传入，不能自行拼接到 [path] 上。
  Future<dynamic> delete(String path,
          {Object? body, Map<String, dynamic>? query}) =>
      _request('DELETE', path, body: body, query: query);

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    Duration? receiveTimeout,
  }) async {
    final apiPath = _apiPath(path);
    final canonicalQuery = _canonicalQuery(query);
    final bodyString = body == null ? '' : jsonEncode(body);
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final canonicalRequest =
        '$method\n$apiPath\n$canonicalQuery\n${_sha256Hex(bodyString)}';
    final stringToSign =
        'HMAC-SHA256\n$timestamp\n${_sha256Hex(canonicalRequest)}';
    final signature = Hmac(sha256, utf8.encode(server.token))
        .convert(utf8.encode(stringToSign))
        .toString();

    // 实际请求路径带入口前缀（未设置入口时 entrancePath 为空）。
    final url = '${server.normalizedBaseUrl}${server.entrancePath}$apiPath'
        '${canonicalQuery.isEmpty ? '' : '?$canonicalQuery'}';

    Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        url,
        data: bodyString.isEmpty ? null : bodyString,
        options: Options(
          method: method,
          receiveTimeout: receiveTimeout,
          headers: {
            'Authorization':
                'HMAC-SHA256 Credential=${server.tokenId}, Signature=$signature',
            'X-Timestamp': '$timestamp',
            if (bodyString.isNotEmpty)
              Headers.contentTypeHeader: Headers.jsonContentType,
          },
        ),
      );
    } on DioException catch (e) {
      throw ApiException(_friendlyDioError(e));
    }

    final status = response.statusCode ?? 0;
    final text = response.data is String ? response.data as String : '';
    dynamic decoded;
    if (text.isNotEmpty) {
      try {
        decoded = jsonDecode(text);
      } catch (_) {
        decoded = null;
      }
    }

    if (status >= 200 && status < 300) {
      if (decoded is Map<String, dynamic>) return decoded['data'];
      return decoded;
    }

    String message;
    if (decoded is Map<String, dynamic> &&
        decoded['msg'] is String &&
        (decoded['msg'] as String).isNotEmpty) {
      message = decoded['msg'] as String;
    } else if (status == 418 || status == 404) {
      // 418/404 常见于「访问入口」校验失败（entrance.go abortEntrance）。
      message = '请求被面板拒绝（HTTP $status），请检查服务器地址与访问入口配置';
    } else {
      message = '请求失败（HTTP $status）';
    }
    throw ApiException(message, statusCode: status);
  }

  /// 归一化为以 /api 开头的路径。
  static String _apiPath(String path) {
    var p = path.trim();
    if (!p.startsWith('/')) p = '/$p';
    if (p == '/api' || p.startsWith('/api/')) return p;
    return '/api$p';
  }

  /// 与 Go `url.Values.Encode()` 完全一致的 query 规范化：
  /// 键按字典序排序，键值均用 QueryEscape 编码，`k=v` 以 `&` 连接。
  /// null 值跳过；Iterable 值展开为多个同名参数（保持原顺序）。
  static String _canonicalQuery(Map<String, dynamic>? query) {
    if (query == null || query.isEmpty) return '';
    final keys = query.keys.where((k) => query[k] != null).toList()..sort();
    final parts = <String>[];
    for (final key in keys) {
      final value = query[key];
      if (value is Iterable) {
        for (final v in value) {
          parts.add('${_goQueryEscape(key)}=${_goQueryEscape('$v')}');
        }
      } else {
        parts.add('${_goQueryEscape(key)}=${_goQueryEscape('$value')}');
      }
    }
    return parts.join('&');
  }

  /// Go `url.QueryEscape` 的 Dart 实现：
  /// 字母数字与 `-._~` 保留，空格转 `+`，其余字节转 `%XX`（大写十六进制）。
  static String _goQueryEscape(String s) {
    const hexDigits = '0123456789ABCDEF';
    final bytes = utf8.encode(s);
    final sb = StringBuffer();
    for (final b in bytes) {
      final isUnreserved = (b >= 0x30 && b <= 0x39) || // 0-9
          (b >= 0x41 && b <= 0x5A) || // A-Z
          (b >= 0x61 && b <= 0x7A) || // a-z
          b == 0x2D || // -
          b == 0x2E || // .
          b == 0x5F || // _
          b == 0x7E; // ~
      if (isUnreserved) {
        sb.writeCharCode(b);
      } else if (b == 0x20) {
        sb.write('+');
      } else {
        sb
          ..write('%')
          ..write(hexDigits[(b >> 4) & 0xF])
          ..write(hexDigits[b & 0xF]);
      }
    }
    return sb.toString();
  }

  static String _sha256Hex(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  static String _friendlyDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接服务器超时，请检查网络与服务器地址';
      case DioExceptionType.badCertificate:
        return '服务器证书校验失败，可在服务器配置中开启「允许自签名证书」';
      case DioExceptionType.connectionError:
        return '无法连接服务器，请检查网络与服务器地址';
      case DioExceptionType.cancel:
        return '请求已取消';
      default:
        return e.message ?? '网络请求失败';
    }
  }
}
