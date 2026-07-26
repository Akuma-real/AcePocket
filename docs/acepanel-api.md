# AcePanel API 参考（面向手机端 App 开发）

> 整理日期：2026-07-26。基于 deep-research 多源检索 + 源码核查（最新 commit `3a2f0db`，2026-07-25，v3.2.x/v3.3.0 时期）。所有结论均经 3 票对抗性验证。

## 1. 项目概况

- **AcePanel** 是全开源（BSD-3-Clause）、永久免费、Go 编写的服务器运维管理面板，是**耗子面板（RatPanel）2.x 的品牌延续**（同一仓库改名而来，`tnb-labs/panel` 301 重定向到 `acepanel/panel`）。
- 官方主仓库：<https://github.com/acepanel/panel>（约 2.9k stars，`module github.com/acepanel/panel/v3`，Go 1.26）
- 官网/文档：<https://acepanel.net/>，**API 专页：<https://acepanel.net/advanced/api>**
- 配套仓库：`acepanel/helper`（安装器）、`acepanel/templates`（容器模板）、`acepanel/acepanel.github.io`（文档站）
- 官方 Gitea 镜像：`git.haozi.net/acepanel/panel`（mirror，网页浏览需登录，可匿名走 Gitea API；**以 GitHub 为准即可**）
- **没有官方 SDK，也没有官方或第三方移动端客户端** —— 我们要做的 App 是第一个。

## 2. API 总体结构

- 所有接口统一挂在 **`/api` 前缀**下（前端 `VITE_BASE_API='/api'`），RESTful 风格，统一 JSON 响应格式（`msg` / `data` 字段）。
- 后端使用 **chi/v5** 路由器；非 API 请求回退到内嵌 SPA 的 `index.html`。
- **权威接口清单来源：`internal/route/` 目录**（当前 main 分支约 44 个按功能拆分的 Go 文件）。每条路由声明包含 HTTP 方法、路径、处理函数、OpenAPI 式文档摘要（Summary/Tags/Request/Response 样例）及可选限流规则。

### 功能模块（路由文件维度）

| 模块 | 说明 |
|---|---|
| `website` | 网站管理（如 `GET/POST /api/website`、`GET/PUT/DELETE /api/website/{id}`、`POST /api/website/{id}/obtain_cert`） |
| `database` / `database_redis` / `database_elasticsearch` | 数据库管理 |
| `file` / `file_share` | 文件管理 |
| `container` | Docker/容器（内嵌 `/compose`、`/image`、`/network`、`/volume` 子路由） |
| `cert` | SSL 证书 |
| `monitor` / `home` | 监控与系统状态（仪表盘） |
| `firewall` | 防火墙 |
| `ssh` | SSH 管理 |
| `cron` | 计划任务 |
| `backup` | 备份 |
| `systemctl` | 系统服务 |
| `user` / `user_token` | 用户、API 令牌管理 |
| `app` | 应用商店（mysql、nginx、php、redis、postgresql、podman、supervisor…） |
| `alert` / `webhook` | 告警与 Webhook |
| `ws` | WebSocket 端点 |

### WebSocket 端点（`internal/route/ws.go`）

- `/api/ws/exec` —— 命令执行
- `/api/ws/pty` —— 终端
- `/api/ws/ssh` —— SSH 会话
- `/api/ws/container/{id}` —— 容器控制台
- `/api/ws/cert/obtain` —— 证书签发进度

## 3. 认证方式（App 必须实现）

### 3.1 API 令牌 + HMAC-SHA256 签名（推荐用于 App）

令牌管理接口：`GET/POST /api/user_tokens`、`PUT/DELETE /api/user_tokens/{id}`（令牌支持有效期、IP 白名单）。

**注意：令牌不是 Bearer token，而是 HMAC 签名密钥**，每个请求都要签名。签名逻辑见 `internal/data/user_token.go` 的 `ValidateReq()`：

```
请求头：
  Authorization: HMAC-SHA256 Credential=<token_id>, Signature=<signature>
  X-Timestamp: <unix 秒级时间戳>

规范化请求（canonicalRequest）：
  METHOD \n PATH \n QUERY(已编码) \n SHA256(body)

待签字符串（stringToSign）：
  "HMAC-SHA256" \n <timestamp> \n SHA256(canonicalRequest)

签名：
  hex( HMAC-SHA256( key=令牌, stringToSign ) )
```

- 时间戳有效窗口 **300 秒**（代码只拒绝过期 >300s 的请求，未显式拒绝未来时间）。
- 官方文档页 <https://acepanel.net/advanced/api> 提供 Go/PHP/Python/Java/Node.js 签名示例，与源码一致。

### 3.2 Cookie 会话登录（Web UI 流程，可选）

- `GET /api/user/key` 获取公钥 → 用公钥加密密码 → `POST /api/user/login` 提交 `username` / `password` / `safe_login`。
- 登录接口限流 **5 次/分钟**（`Throttle{Tokens: 5, Interval: time.Minute}`）。
- 会话经 Cookie 维持（`must_login` 中间件检查 session 中的 `user_id`）。
- App 若走这条路，需要实现 Cookie 管理 + 公钥加密；**建议 App 优先用 3.1 的 API 令牌方案**。

## 4. 客户端调用参考：`web/src/api/`

前端 API 层分三组，可直接对照移植到 App：

- **`panel/`** —— 核心面板模块，当前 main 约 34 个模块（home、website、database、file、container、cert、cron、firewall、monitor、ssh、backup、backup-storage、user、setting、app、project、alert、notify、webhook、tamper、toolbox-*、environment、log、template…）
- **`apps/`** —— 每个可安装应用一个模块（mysql、nginx、php、redis、postgresql、podman、supervisor 等）
- **`ws/`** —— WebSocket 封装（`/api/ws/exec`、`/api/ws/ssh` 等）

## 5. 同类产品参考

- [`teguh02/aapanel-mobile`](https://github.com/teguh02/aapanel-mobile)：**aaPanel**（不同产品）的非官方 Expo React Native 客户端（Axios + CryptoJS + AsyncStorage）。仅可作为「面板类移动客户端」的架构参考；其认证是 aaPanel 的 `md5(request_time + md5(api_key))` 表单签名，**与 AcePanel 的 HMAC-SHA256 完全不同，不可套用**。

## 6. 注意事项（Caveats）

1. **版本迭代快**：`internal/route` 文件数（44，早前 47–49）与前端模块数（16→18→34）随版本明显变化。开发前应**锁定目标面板版本，以对应 git tag 的源码为准**生成接口清单。
2. 历史版本（如 commit `fca7065d`，2025-03）只有 session 认证、无 database 模块——旧版兼容需单独处理。
3. HMAC 时间戳校验实为单向（只拒绝过期），"±300 秒"是简化说法。
4. deepwiki 等二手来源有错漏（如 `internal/route/http.go` 已被按域拆分的多文件取代），**一切以源码复核为准**。
5. 「永久免费」是维护者承诺而非法律保证。

## 7. 主要引用

- 源码：<https://github.com/acepanel/panel>（`internal/route/`、`internal/data/user_token.go`、`web/src/api/`）
- 官方 API 文档：<https://acepanel.net/advanced/api>
- 发布公告：<https://acepanel.net/quickstart/news/acepanel-3-release>
- 镜像：<https://git.haozi.net/acepanel/panel>
