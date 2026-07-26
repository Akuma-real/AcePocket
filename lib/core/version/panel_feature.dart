/// 面板版本兼容性：每个功能对应的最低面板版本要求。
///
/// 数据来源：对 acepanel/panel 仓库全部发布 tag（v2.3.0 ~ v3.3.0，共 199 个）
/// 逐版本还原其 HTTP 路由表（v3.3.0 起为 `internal/route/*.go` 的
/// `Endpoints{Path: "/api/..."}`，更早为 `internal/route/http.go` 中的 chi 嵌套
/// 路由组），再把 App 实际调用的 285 个接口逐一比对，取「首次出现该接口的
/// 最早 tag」，同一功能取其所有接口中最高的那个版本。
///
/// 注意 v3.3.0 是一次较大的接口重构（大量路径改名，如 `/cert/cert`、
/// `/database_server`、`/tamper/rule`），因此多数功能的下限都落在 v3.3.0。
library;

/// 面板版本号（形如 `3.3.0`，可带 `v` 前缀与 `-beta.1` 之类的后缀）。
///
/// 只比较主/次/修订三段数字；预发布后缀视为等于对应正式版，避免把
/// `3.3.0-beta.1` 判成低于 `3.3.0` 而误报不支持。
class PanelVersion implements Comparable<PanelVersion> {
  const PanelVersion(this.major, this.minor, this.patch, {this.raw = ''});

  final int major;
  final int minor;
  final int patch;

  /// 面板原样返回的版本串，用于展示。
  final String raw;

  static final RegExp _pattern = RegExp(r'(\d+)\.(\d+)(?:\.(\d+))?');

  /// 解析失败返回 null（例如面板返回空串或 `dev`）。
  static PanelVersion? tryParse(String? value) {
    if (value == null) return null;
    final text = value.trim();
    if (text.isEmpty) return null;
    final m = _pattern.firstMatch(text);
    if (m == null) return null;
    return PanelVersion(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.tryParse(m.group(3) ?? '0') ?? 0,
      raw: text,
    );
  }

  @override
  int compareTo(PanelVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator >=(PanelVersion other) => compareTo(other) >= 0;
  bool operator <(PanelVersion other) => compareTo(other) < 0;

  /// 展示用：优先用面板原样返回的串。
  String get display => raw.isEmpty ? '$major.$minor.$patch' : raw;

  @override
  String toString() => display;

  @override
  bool operator ==(Object other) =>
      other is PanelVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);
}

/// 尚未随任何正式版发布的功能（只存在于面板主分支）。
///
/// 用一个不可能达到的版本号表示，这样比较逻辑无需特判。
const kUnreleasedVersion = PanelVersion(9999, 0, 0, raw: '尚未发布');

/// 功能标识。命名与「更多」页入口 / 路由一一对应。
enum PanelFeature {
  // ── 概览与监控 ───────────────────────────────────────────
  dashboard,
  monitor,
  panelUpdate,
  runtimeInfo,

  // ── 网站 ────────────────────────────────────────────────
  website,
  websiteStat,
  websiteDefaults,

  // ── 数据库 ──────────────────────────────────────────────
  database,
  databaseServer,
  databaseUser,
  redis,
  elasticsearch,

  // ── 文件 ────────────────────────────────────────────────
  files,
  fileShare,

  // ── 容器 ────────────────────────────────────────────────
  container,

  // ── 证书 ────────────────────────────────────────────────
  cert,

  // ── 计划任务与备份 ──────────────────────────────────────
  cron,
  backup,
  backupStorage,

  // ── 安全 ────────────────────────────────────────────────
  firewall,
  panelSafe,
  ssh,
  tamper,

  // ── 终端与远程 ──────────────────────────────────────────
  terminal,
  sshHosts,

  // ── 运行环境与项目 ──────────────────────────────────────
  environment,
  project,
  template,

  // ── 工具箱 ──────────────────────────────────────────────
  toolboxSystem,
  toolboxDisk,
  toolboxLog,
  toolboxNetwork,
  toolboxBenchmark,
  migration,

  // ── 告警与通知 ──────────────────────────────────────────
  alert,
  notify,
  webhook,

  // ── 应用与系统 ──────────────────────────────────────────
  appStore,
  systemctl,
  process,

  // ── 面板管理 ────────────────────────────────────────────
  settings,
  panelCert,
  userToken,
  task,
  panelLog,
  panelUsers,
  passkey,
}

/// 每个功能的最低面板版本要求。
///
/// 未列出的功能视为无版本限制（所有支持的面板版本都可用）。
const Map<PanelFeature, PanelVersion> kFeatureRequirements = {
  // 尚未随正式版发布 —— 面板主分支已有，等待下一个版本
  PanelFeature.alert: kUnreleasedVersion,
  PanelFeature.notify: kUnreleasedVersion,

  // v3.3.0（接口重构，大量路径改名）
  PanelFeature.website: PanelVersion(3, 3, 0),
  PanelFeature.websiteStat: PanelVersion(3, 3, 0),
  PanelFeature.websiteDefaults: PanelVersion(3, 3, 0),
  PanelFeature.database: PanelVersion(3, 3, 0),
  PanelFeature.databaseServer: PanelVersion(3, 3, 0),
  PanelFeature.databaseUser: PanelVersion(3, 3, 0),
  PanelFeature.fileShare: PanelVersion(3, 3, 0),
  PanelFeature.container: PanelVersion(3, 3, 0),
  PanelFeature.cert: PanelVersion(3, 3, 0),
  PanelFeature.cron: PanelVersion(3, 3, 0),
  PanelFeature.backup: PanelVersion(3, 3, 0),
  PanelFeature.backupStorage: PanelVersion(3, 3, 0),
  PanelFeature.tamper: PanelVersion(3, 3, 0),
  PanelFeature.panelSafe: PanelVersion(3, 3, 0),
  PanelFeature.sshHosts: PanelVersion(3, 3, 0),
  PanelFeature.project: PanelVersion(3, 3, 0),
  PanelFeature.template: PanelVersion(3, 3, 0),
  PanelFeature.webhook: PanelVersion(3, 3, 0),
  PanelFeature.appStore: PanelVersion(3, 3, 0),
  PanelFeature.process: PanelVersion(3, 3, 0),
  PanelFeature.settings: PanelVersion(3, 3, 0),
  PanelFeature.panelCert: PanelVersion(3, 3, 0),
  PanelFeature.userToken: PanelVersion(3, 3, 0),
  PanelFeature.task: PanelVersion(3, 3, 0),
  PanelFeature.panelUsers: PanelVersion(3, 3, 0),
  PanelFeature.passkey: PanelVersion(3, 3, 0),

  // v3.2.6
  PanelFeature.dashboard: PanelVersion(3, 2, 6),

  // v3.2.2
  PanelFeature.files: PanelVersion(3, 2, 2),
  PanelFeature.systemctl: PanelVersion(3, 2, 2),

  // v3.2.0
  PanelFeature.elasticsearch: PanelVersion(3, 2, 0),

  // v3.1.0
  PanelFeature.firewall: PanelVersion(3, 1, 0),
  PanelFeature.redis: PanelVersion(3, 1, 0),
  PanelFeature.toolboxDisk: PanelVersion(3, 1, 0),

  // v3.0.8
  PanelFeature.environment: PanelVersion(3, 0, 8),
  PanelFeature.toolboxNetwork: PanelVersion(3, 0, 8),
  PanelFeature.panelLog: PanelVersion(3, 0, 8),

  // v3.0.0
  PanelFeature.ssh: PanelVersion(3, 0, 0),
  PanelFeature.toolboxSystem: PanelVersion(3, 0, 0),
  PanelFeature.toolboxLog: PanelVersion(3, 0, 0),
  PanelFeature.panelUpdate: PanelVersion(3, 0, 0),
  PanelFeature.runtimeInfo: PanelVersion(3, 0, 0),

  // v2.5.11
  PanelFeature.migration: PanelVersion(2, 5, 11),

  // v2.5.2
  PanelFeature.toolboxBenchmark: PanelVersion(2, 5, 2),

  // v2.3.0
  PanelFeature.monitor: PanelVersion(2, 3, 0),
  PanelFeature.terminal: PanelVersion(2, 3, 11),
};

/// 功能的中文名，用于提示文案。
const Map<PanelFeature, String> kFeatureNames = {
  PanelFeature.dashboard: '仪表盘',
  PanelFeature.monitor: '历史监控',
  PanelFeature.panelUpdate: '面板升级',
  PanelFeature.runtimeInfo: '运行时诊断',
  PanelFeature.website: '网站管理',
  PanelFeature.websiteStat: '网站访问统计',
  PanelFeature.websiteDefaults: '网站默认设置',
  PanelFeature.database: '数据库',
  PanelFeature.databaseServer: '数据库服务器',
  PanelFeature.databaseUser: '数据库用户',
  PanelFeature.redis: 'Redis 管理',
  PanelFeature.elasticsearch: 'Elasticsearch 管理',
  PanelFeature.files: '文件管理',
  PanelFeature.fileShare: '文件分享',
  PanelFeature.container: '容器管理',
  PanelFeature.cert: 'SSL 证书',
  PanelFeature.cron: '计划任务',
  PanelFeature.backup: '备份',
  PanelFeature.backupStorage: '备份存储',
  PanelFeature.firewall: '防火墙',
  PanelFeature.panelSafe: '面板安全',
  PanelFeature.ssh: 'SSH 服务',
  PanelFeature.tamper: '防篡改',
  PanelFeature.terminal: '终端',
  PanelFeature.sshHosts: 'SSH 主机管理',
  PanelFeature.environment: '运行环境',
  PanelFeature.project: '项目管理',
  PanelFeature.template: '应用模板',
  PanelFeature.toolboxSystem: '系统工具',
  PanelFeature.toolboxDisk: '磁盘管理',
  PanelFeature.toolboxLog: '日志清理',
  PanelFeature.toolboxNetwork: '网络信息',
  PanelFeature.toolboxBenchmark: '服务器跑分',
  PanelFeature.migration: '面板迁移',
  PanelFeature.alert: '告警',
  PanelFeature.notify: '通知渠道',
  PanelFeature.webhook: 'WebHook',
  PanelFeature.appStore: '应用商店',
  PanelFeature.systemctl: '系统服务',
  PanelFeature.process: '进程管理',
  PanelFeature.settings: '面板设置',
  PanelFeature.panelCert: '面板证书',
  PanelFeature.userToken: 'API 令牌',
  PanelFeature.task: '任务中心',
  PanelFeature.panelLog: '面板日志',
  PanelFeature.panelUsers: '面板用户',
  PanelFeature.passkey: '通行密钥',
};

/// 判断某功能在给定面板版本下是否可用。
///
/// [current] 为 null（版本未知，例如尚未连接成功）时一律返回 true，
/// 避免因为拿不到版本就把所有入口灰掉。
bool isFeatureSupported(PanelFeature feature, PanelVersion? current) {
  final required = kFeatureRequirements[feature];
  if (required == null || current == null) return true;
  return current >= required;
}

/// 功能要求的最低版本；无要求返回 null。
PanelVersion? requiredVersionOf(PanelFeature feature) =>
    kFeatureRequirements[feature];

/// 生成不支持时的提示文案。
String featureUnsupportedMessage(PanelFeature feature, PanelVersion? current) {
  final name = kFeatureNames[feature] ?? '该功能';
  final required = kFeatureRequirements[feature];
  if (required == null) return '$name在当前面板版本不可用。';
  if (identical(required, kUnreleasedVersion) ||
      required == kUnreleasedVersion) {
    return '$name尚未随面板正式版发布，需等待新版本（当前面板 '
        '${current?.display ?? '版本未知'}）。';
  }
  return '$name需要面板 v${required.major}.${required.minor}.${required.patch} '
      '或更高版本，当前为 v${current?.display ?? '未知'}，请先升级面板。';
}
