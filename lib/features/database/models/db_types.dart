/// 数据库类型常量与展示辅助。
/// 类型取值与源码 `internal/biz/database.go` 的 `DatabaseType` 一致。
library;

import 'dart:math';

/// 可添加的数据库服务器类型
/// （`request.DatabaseServerCreate` 的 `in:` 校验列表）。
const List<String> kDatabaseServerTypes = [
  'mysql',
  'postgresql',
  'clickhouse',
  'mongodb',
  'sqlite',
  'elasticsearch',
  'redis',
];

/// 「数据库列表」页可筛选的类型（redis / elasticsearch 有独立管理页，
/// 与 Web 前端 IndexView 的标签页划分一致）。
const List<String> kDatabaseListTypes = [
  'mysql',
  'postgresql',
  'clickhouse',
  'mongodb',
  'sqlite',
];

/// 支持用户管理的数据库类型（与 Web 前端 CreateUserModal 保持一致）。
const List<String> kUserSupportedTypes = ['mysql', 'postgresql', 'clickhouse'];

/// 类型显示名。
String dbTypeLabel(String type) {
  switch (type) {
    case 'mysql':
      return 'MySQL';
    case 'postgresql':
      return 'PostgreSQL';
    case 'redis':
      return 'Redis';
    case 'clickhouse':
      return 'ClickHouse';
    case 'mongodb':
      return 'MongoDB';
    case 'sqlite':
      return 'SQLite';
    case 'elasticsearch':
      return 'Elasticsearch';
    default:
      return type.isEmpty ? '未知' : type;
  }
}

/// 各类型的默认端口（与 Web 前端 CreateServerModal 的 defaultPort 一致）。
int dbTypeDefaultPort(String type) {
  switch (type) {
    case 'postgresql':
      return 5432;
    case 'redis':
      return 6379;
    case 'clickhouse':
      return 8123;
    case 'mongodb':
      return 27017;
    case 'sqlite':
      return 0;
    case 'elasticsearch':
      return 9200;
    default:
      return 3306;
  }
}

/// 该类型是否需要用户名（redis / sqlite 不需要，与 Web 前端一致）。
bool dbTypeNeedsUsername(String type) => type != 'redis' && type != 'sqlite';

/// 该类型是否需要密码（sqlite 不需要，与 Web 前端一致）。
bool dbTypeNeedsPassword(String type) => type != 'sqlite';

/// 该类型是否支持用户管理（创建 / 授权 / 改密）。
bool dbTypeSupportsUser(String type) => kUserSupportedTypes.contains(type);

/// 该类型是否使用 Host 字段（仅 MySQL，见 `biz.DatabaseUser.Host` 注释）。
bool dbTypeUsesHost(String type) => type == 'mysql';

/// 该类型是否支持数据库注释（仅 PostgreSQL，见 `DatabaseUsecase.Comment`）。
bool dbTypeSupportsComment(String type) => type == 'postgresql';

/// 该类型是否支持同步用户
/// （redis / mongodb / sqlite / elasticsearch 不支持，见 `DatabaseServerUsecase.Sync`）。
bool dbTypeSupportsSync(String type) =>
    const ['mysql', 'postgresql', 'clickhouse'].contains(type);

/// MySQL 主机选项（与 Web 前端 hostTypeOptions 一致）。
/// `specific` 为「指定主机」的占位值，提交时应替换为用户输入的地址。
const List<(String, String)> kMysqlHostOptions = [
  ('localhost', '本机（localhost）'),
  ('%', '所有主机（%）'),
  ('specific', '指定主机'),
];

/// Redis 键类型（`request.DatabaseRedisKeySet` 的 `in:` 校验列表）。
const List<String> kRedisKeyTypes = ['string', 'list', 'set', 'zset', 'hash'];

// 字节数展示统一用 `core/utils/format.dart` 的 formatBytes（同为 1024 进制循环
// 除法，另外覆盖 NaN / 负数 / PB / EB），本文件不再维护副本。

const String _kPasswordChars =
    'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// 生成随机密码（默认 16 位，已去掉易混淆字符）。
String generatePassword([int length = 16]) {
  final random = Random.secure();
  return List<String>.generate(
    length,
    (_) => _kPasswordChars[random.nextInt(_kPasswordChars.length)],
  ).join();
}
