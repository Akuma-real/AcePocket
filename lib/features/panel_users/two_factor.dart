/// 面板会话两步验证的对外导出。
///
/// **默认无需任何接入工作**：应用启动时 `lib/app.dart` 调用一次
/// [installWsLoginChallengeHandler]，把本模块的对话框注册为 core
/// `WsSessionManager.challengeHandler`。此后所有走 `wsConnect` 的功能
/// （终端 / SSH / 容器日志 / 计划任务日志 / 证书签发 / 面板升级 / 迁移进度…）
/// 在面板账号开启两步验证或需要图形验证码时都会自动弹窗，各页面无需改动。
///
/// 其他模块 `import '../../panel_users/two_factor.dart';` 后还可使用：
///
/// - [installWsLoginChallengeHandler]：注册全局登录挑战处理器（启动时调用一次）；
/// - [showTwoFactorPrompt] / [TwoFactorPromptDialog]：需要自行控制流程时使用；
/// - [TwoFactorPromptResult]：对话框返回值（`passCode` / `captchaCode`）；
/// - [connectWsWithTwoFactor]：历史 API，现已等价于 `wsConnect`；
/// - [LoginCaptcha]：`GET /api/user/captcha` 的响应模型，用于给对话框传图形验证码。
library;

export 'models/login_captcha.dart';
export 'widgets/two_factor_prompt.dart';
