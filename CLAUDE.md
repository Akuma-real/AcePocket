# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

AcePocket 是 [AcePanel](https://github.com/acepanel/panel) 服务器面板的**非官方** Flutter 手机客户端（Android / iOS）。UI 全中文，代码注释与提交信息也用中文。

## 常用命令

```bash
flutter pub get
flutter analyze                      # 必须做到 0 error 0 warning 0 info（含 info 级废弃提示）
flutter test                         # 全部用例
flutter test test/core/downsample_test.dart          # 单个文件
flutter test --plain-name '端口写成斜杠时提示改用冒号'  # 单个用例（按名称）
flutter build apk --release --target-platform android-arm64
```

**装到真机时用 `adb install -r <apk>`，不要用 `flutter install`** —— 后者会先卸载再装，
应用私有数据（服务器配置、令牌，存在 flutter_secure_storage）会被清空。`adb install -r`
是更新安装，数据保留（已实测 `ceDataInode` 不变）。

发布签名：`android/key.properties`（不入库，模板见同目录 `.example`）。文件缺失时
Gradle 回退 debug 签名并告警，构建不会断，但产物不可分发。

## 架构要点

### 认证：HTTP 与 WebSocket 走两套完全不同的机制

这是本项目最容易踩坑的地方。

**HTTP 用 API 令牌 + HMAC-SHA256 签名**（`lib/core/api/api_client.dart`）。签名与面板
`internal/data/user_token.go` 的 `ValidateReq()` 逐项对齐：规范化请求为
`METHOD\nPATH\nQUERY\nSHA256(body)`，待签串为 `"HMAC-SHA256"\n<ts>\nSHA256(canonical)`。
其中 QUERY 必须按 Go 的 `url.Values.Encode()` 编码（Dart 的 `Uri.encodeQueryComponent`
与之不兼容，已自行实现）。**query 必须走 `ApiClient` 的 `query` 参数**，自己拼进 path
会导致签名与实际请求不一致。

**WebSocket 不接受 HMAC 令牌**：面板 `internal/middleware/must_login.go` 见到请求带
`Authorization` 头且路径以 `/api/ws` 开头会直接 403。因此 `lib/core/api/ws_client.dart`
内置了完整的会话登录流（取 RSA 公钥 → RSA-OAEP(SHA-512) 加密账号密码 → 换 Cookie），
`ServerConfig` 才有 `username`/`password` 这两个可选字段。`wsConnect` 是 **async**。
2FA 与图形验证码由 `WsSessionManager.challengeHandler` 全局处理（`lib/app.dart` 注册一次），
功能页无需各自弹窗。

**访问入口（entrance）**：面板设了访问入口时，请求要发到 `<entrance>/api/...`，但**签名
算的是去掉入口后的 `/api/...`**（面板 `entrance.go` 情况三会在鉴权前重写路径）。

### 证书信任：TOFU，不是无条件放行

`lib/core/api/panel_http_client.dart` 是**唯一**创建 HttpClient 的地方，所有走网络的代码
都必须用它（历史上曾有 6 处复制粘贴的 `badCertificateCallback => true`）。三种状态：
关闭自签名开关走系统信任链；已固定指纹只认匹配者；指纹为空时**暂存证书信息并拒绝本次
连接**，抛 `CertificateTrustRequiredException` 由 UI 弹窗确认——`badCertificateCallback`
是同步回调且可能在非 UI 线程语境触发，不可在其中直接弹窗。

### 功能模块结构

`lib/features/<key>/` 下统一为 `models/ repo/ providers/ pages/ widgets/ + routes.dart`。
`routes.dart` 导出 `final List<RouteBase> <camelKey>Routes`，由 `lib/core/router/router.dart`
聚合；新增模块还要在 `lib/core/pages/more_page.dart` 的 `kMoreGroups` 挂入口。

底部导航是 `StatefulShellRoute.indexedStack`（首页 / 网站 / 更多），其余页面都是**顶层
路由**，push 后全屏覆盖导航栏。同一模块内静态段路由必须声明在动态段之前。

### 几条必须遵守的约定

**Notifier 的 `build()` 里要 `ref.watch(xxxRepoProvider)`**（不是 `read`）。所有 repo
provider 都 watch 了 `apiClientProvider`，切换服务器时会重建；Notifier 不 watch 就收不到
通知，会继续显示上一台服务器的数据，且 loadMore 会把新服务器的第 2 页追加到旧数据后面。

**分页统一用 `lib/core/providers/paged_notifier_base.dart`**。它用请求代次（generation）
丢弃过期响应，在途标志放在 pager 字段而非 state 里（refresh 重建 state 不会误清）。
不要再手写分页——历史上 8 套复制粘贴的实现全都有竞态。

**时间一律 `.toLocal()`**。面板返回带时区偏移的 RFC3339，`DateTime.parse` 得到的是
`isUtc=true` 的实例，直接取 `.hour` 会差 8 小时。在解析处转换，不要在每个展示点补。
Go 零值时间（`year <= 1`）按 null 处理。

**面板版本门控**：`lib/core/version/panel_feature.dart` 记录每个功能的最低面板版本
（数据来自对面板仓库 199 个发布 tag 逐版本还原路由表比对）。新增功能要在 `PanelFeature`
里登记并在页面顶部加 `FeatureUnsupportedBanner`。纯本地页面（如应用设置）的 `MoreEntry`
`feature` 传 null，不应受门控。

**生命周期**：`lib/core/lifecycle/app_lifecycle.dart` 提供前台状态。轮询与心跳类逻辑要用
`ref.listen` 而非 `ref.watch` 消费它——watch 会在切前后台时重建 Notifier，清空首页趋势图
历史 / 断开终端 / 重置迁移向导。

### 接口真相以面板源码为准

所有接口路径、方法、请求与响应字段必须对照面板 Go 源码，不要凭前端或文档猜：
路由定义在 `internal/route/*.go`（每条路由的 Summary/Request/Response 注释即文档），
请求结构在 `internal/request/*.go`，返回形状看 `internal/service/*.go` 的 `Success(w, ...)`。
需要时克隆 `https://github.com/acepanel/panel` 查阅。`docs/acepanel-api.md` 有 API 总览与
认证细节，`docs/architecture.md` 是模块开发契约。

## Android 侧的两个坑

`flutter create` 只把 `INTERNET` 权限写进 debug/profile 的 manifest，**主 manifest 没有**。
release 包因此完全无法联网，而报错表现是「无法连接服务器」，极易误判为网络或地址问题。
本仓库已在 `android/app/src/main/AndroidManifest.xml` 显式声明，执行 `flutter create .`
若覆盖了该文件需要加回。

同一 manifest 里还用 `tools:node="remove"` 移除了 `open_filex` 插件合入的四个存储/媒体
权限，并用 `tools:replace` 覆盖了它的 FileProvider 路径配置（原含 `<root-path path="."/>`，
可为整个文件系统签发 content URI）。改动 manifest 后用
`cd android && ./gradlew :app:processReleaseManifest` 检查 merged 结果。

## 测试中不要写真实地址

用 `example.com`、`192.0.2.1`（RFC 5737）、`2001:db8::` 等占位值，不要出现真实服务器
地址、域名、令牌或密码。
