import 'dart:convert';
import 'dart:typed_data';

import 'json_utils.dart';

/// 登录图形验证码（`GET /api/user/captcha`）。
///
/// 面板 `internal/service/user.go` `GetCaptcha()`：
/// 仅当面板开启「登录验证码」且**当前会话**连续登录失败达到 3 次时
/// 才返回 `{required: true, image: <PNG base64>}`，否则 `{required: false}`。
///
/// 注意：失败计数保存在会话（Cookie）中，因此通过 API 令牌（HMAC 签名，
/// 无会话）调用本接口拿到的始终是「不需要验证码」的结果 —— 它只能作为
/// 「面板是否启用了登录验证码」的参考，真正的验证码必须由建立会话的那一方
/// （`WsSessionManager`）取得。
class LoginCaptcha {
  const LoginCaptcha({required this.required, this.imageBase64 = ''});

  static const LoginCaptcha none = LoginCaptcha(required: false);

  final bool required;
  final String imageBase64;

  /// 解码后的验证码 PNG 字节；无图或数据非法时为 null。
  Uint8List? get imageBytes {
    if (imageBase64.isEmpty) return null;
    try {
      return base64Decode(imageBase64);
    } catch (_) {
      return null;
    }
  }

  factory LoginCaptcha.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return none;
    return LoginCaptcha(
      required: jsonBool(json['required']),
      imageBase64: jsonString(json['image']),
    );
  }
}
