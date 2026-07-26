/// 面板设置模型。
///
/// 字段与面板源码 `internal/request/setting.go` 的 `SettingPanel` 逐一对应：
/// `GET /api/setting` 返回该结构，`POST /api/setting` 需要提交完整结构
/// （未修改的字段原样回传，避免被清空）。
class PanelSetting {
  const PanelSetting({
    this.name = '',
    this.channel = 'stable',
    this.locale = 'zh_CN',
    this.entrance = '',
    this.entranceError = '418',
    this.loginCaptcha = false,
    this.offlineMode = false,
    this.autoUpdate = false,
    this.twoFA = false,
    this.lifetime = 120,
    this.ipHeader = '',
    this.bindDomain = const [],
    this.bindIp = const [],
    this.bindUa = const [],
    this.websitePath = '',
    this.backupPath = '',
    this.backupFormat = 'tar.xz',
    this.projectPath = '',
    this.containerSock = '',
    this.hiddenMenu = const [],
    this.customLogo = '',
    this.ipdbType = '',
    this.ipdbUrl = '',
    this.ipdbPath = '',
    this.port = 8888,
    this.tls = 'off',
    this.publicIp = const [],
    this.cert = '',
    this.key = '',
  });

  /// 面板名称。
  final String name;

  /// 更新渠道：stable / beta。
  final String channel;

  /// 面板语言：en / zh_CN / zh_TW。
  final String locale;

  /// 访问入口路径（如 `/entrance`）。
  final String entrance;

  /// 入口错误页伪装类型：418 / nginx / close。
  final String entranceError;

  /// 登录验证码开关。
  final bool loginCaptcha;

  /// 离线模式。
  final bool offlineMode;

  /// 自动更新。
  final bool autoUpdate;

  /// 两步验证（面板侧按用户管理，此处仅作字段回传）。
  final bool twoFA;

  /// 登录超时（分钟，10 - 43200）。
  final int lifetime;

  /// 真实 IP 请求头（如 X-Real-IP）。
  final String ipHeader;

  /// 绑定域名。
  final List<String> bindDomain;

  /// 绑定 IP（支持 CIDR）。
  final List<String> bindIp;

  /// 绑定 UA。
  final List<String> bindUa;

  /// 网站目录。
  final String websitePath;

  /// 备份目录。
  final String backupPath;

  /// 备份压缩格式：tar.xz / tar.gz / tar.zst / zip / 7z。
  final String backupFormat;

  /// 项目目录。
  final String projectPath;

  /// 容器 Sock 路径。
  final String containerSock;

  /// 隐藏的菜单项。
  final List<String> hiddenMenu;

  /// 自定义 Logo URL。
  final String customLogo;

  /// IPDB 来源类型：'' / custom / subscribe。
  final String ipdbType;

  /// IPDB 订阅链接。
  final String ipdbUrl;

  /// IPDB 地理位置库路径。
  final String ipdbPath;

  /// 面板端口（1 - 65535）。
  final int port;

  /// 面板 TLS：off / acme / self-signed / custom。
  final String tls;

  /// 公网 IP 列表。
  final List<String> publicIp;

  /// 面板证书（PEM）。
  final String cert;

  /// 面板证书私钥（PEM）。
  final String key;

  factory PanelSetting.fromJson(Map<String, dynamic> json) {
    return PanelSetting(
      name: _asString(json['name']),
      channel: _asString(json['channel'], fallback: 'stable'),
      locale: _asString(json['locale'], fallback: 'zh_CN'),
      entrance: _asString(json['entrance']),
      entranceError: _asString(json['entrance_error']),
      loginCaptcha: _asBool(json['login_captcha']),
      offlineMode: _asBool(json['offline_mode']),
      autoUpdate: _asBool(json['auto_update']),
      twoFA: _asBool(json['two_fa']),
      lifetime: _asInt(json['lifetime'], fallback: 120),
      ipHeader: _asString(json['ip_header']),
      bindDomain: _asStringList(json['bind_domain']),
      bindIp: _asStringList(json['bind_ip']),
      bindUa: _asStringList(json['bind_ua']),
      websitePath: _asString(json['website_path']),
      backupPath: _asString(json['backup_path']),
      backupFormat: _asString(json['backup_format'], fallback: 'tar.xz'),
      projectPath: _asString(json['project_path']),
      containerSock: _asString(json['container_sock']),
      hiddenMenu: _asStringList(json['hidden_menu']),
      customLogo: _asString(json['custom_logo']),
      ipdbType: _asString(json['ipdb_type']),
      ipdbUrl: _asString(json['ipdb_url']),
      ipdbPath: _asString(json['ipdb_path']),
      port: _asInt(json['port'], fallback: 8888),
      tls: _asString(json['tls'], fallback: 'off'),
      publicIp: _asStringList(json['public_ip']),
      cert: _asString(json['cert']),
      key: _asString(json['key']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'channel': channel,
      'locale': locale,
      'entrance': entrance,
      'entrance_error': entranceError,
      'login_captcha': loginCaptcha,
      'offline_mode': offlineMode,
      'auto_update': autoUpdate,
      'two_fa': twoFA,
      'lifetime': lifetime,
      'ip_header': ipHeader,
      'bind_domain': bindDomain,
      'bind_ip': bindIp,
      'bind_ua': bindUa,
      'website_path': websitePath,
      'backup_path': backupPath,
      'backup_format': backupFormat,
      'project_path': projectPath,
      'container_sock': containerSock,
      'hidden_menu': hiddenMenu,
      'custom_logo': customLogo,
      'ipdb_type': ipdbType,
      'ipdb_url': ipdbUrl,
      'ipdb_path': ipdbPath,
      'port': port,
      'tls': tls,
      'public_ip': publicIp,
      'cert': cert,
      'key': key,
    };
  }

  PanelSetting copyWith({
    String? name,
    String? channel,
    String? locale,
    String? entrance,
    String? entranceError,
    bool? loginCaptcha,
    bool? offlineMode,
    bool? autoUpdate,
    bool? twoFA,
    int? lifetime,
    String? ipHeader,
    List<String>? bindDomain,
    List<String>? bindIp,
    List<String>? bindUa,
    String? websitePath,
    String? backupPath,
    String? backupFormat,
    String? projectPath,
    String? containerSock,
    List<String>? hiddenMenu,
    String? customLogo,
    String? ipdbType,
    String? ipdbUrl,
    String? ipdbPath,
    int? port,
    String? tls,
    List<String>? publicIp,
    String? cert,
    String? key,
  }) {
    return PanelSetting(
      name: name ?? this.name,
      channel: channel ?? this.channel,
      locale: locale ?? this.locale,
      entrance: entrance ?? this.entrance,
      entranceError: entranceError ?? this.entranceError,
      loginCaptcha: loginCaptcha ?? this.loginCaptcha,
      offlineMode: offlineMode ?? this.offlineMode,
      autoUpdate: autoUpdate ?? this.autoUpdate,
      twoFA: twoFA ?? this.twoFA,
      lifetime: lifetime ?? this.lifetime,
      ipHeader: ipHeader ?? this.ipHeader,
      bindDomain: bindDomain ?? this.bindDomain,
      bindIp: bindIp ?? this.bindIp,
      bindUa: bindUa ?? this.bindUa,
      websitePath: websitePath ?? this.websitePath,
      backupPath: backupPath ?? this.backupPath,
      backupFormat: backupFormat ?? this.backupFormat,
      projectPath: projectPath ?? this.projectPath,
      containerSock: containerSock ?? this.containerSock,
      hiddenMenu: hiddenMenu ?? this.hiddenMenu,
      customLogo: customLogo ?? this.customLogo,
      ipdbType: ipdbType ?? this.ipdbType,
      ipdbUrl: ipdbUrl ?? this.ipdbUrl,
      ipdbPath: ipdbPath ?? this.ipdbPath,
      port: port ?? this.port,
      tls: tls ?? this.tls,
      publicIp: publicIp ?? this.publicIp,
      cert: cert ?? this.cert,
      key: key ?? this.key,
    );
  }

  static String _asString(dynamic v, {String fallback = ''}) {
    if (v is String) return v;
    if (v == null) return fallback;
    return '$v';
  }

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is String) return v == 'true' || v == '1';
    if (v is num) return v != 0;
    return false;
  }

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static List<String> _asStringList(dynamic v) {
    if (v is List) {
      return v.map((e) => '$e').where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }
}
