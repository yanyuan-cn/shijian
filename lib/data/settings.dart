/// 设备私有设置。存 shared_preferences，不进数据库、不同步。
///
/// 「不同步」是刻意的：字号、主题、翻页方式、代理地址只对这台设备有意义，
/// 推进同步会把手机的设置推给桌面端。
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../core/ids.dart';

class Settings {
  Settings._();

  static late SharedPreferences _p;
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    _p = await SharedPreferences.getInstance();
    if ((_p.getString('deviceId') ?? '').isEmpty) {
      await _p.setString('deviceId', Ids.deviceId());
    }
    _ready = true;
  }

  static String get deviceId => _p.getString('deviceId') ?? '';

  // ---------- 数据源 ----------
  static String get tmdbKey => _p.getString('tmdbKey') ?? '';
  static set tmdbKey(String v) => _p.setString('tmdbKey', v.trim());

  static String get omdbKey => _p.getString('omdbKey') ?? '';
  static set omdbKey(String v) => _p.setString('omdbKey', v.trim());

  /// 通用代理前缀。非空时所有数据源请求都走 `<proxy>/?url=<原始地址>`。
  /// 支持的写法：`https://xxx.workers.dev` 或含 `{url}` 占位的模板。
  static String get proxy => _p.getString('proxy') ?? '';
  static set proxy(String v) => _p.setString('proxy', v.trim());

  static bool get proxyOnlyMeta =>
      _p.getBool('proxyOnlyMeta') ?? false; // 只给数据源用，不代理图片下载
  static set proxyOnlyMeta(bool v) => _p.setBool('proxyOnlyMeta', v);

  static bool get autoMatch => _p.getBool('autoMatch') ?? true;
  static set autoMatch(bool v) => _p.setBool('autoMatch', v);

  // ---------- 阅读器（设备私有）----------
  static String get readerTheme => _p.getString('readerTheme') ?? 'sepia';
  static set readerTheme(String v) => _p.setString('readerTheme', v);

  static double get readerFontSize => _p.getDouble('readerFontSize') ?? 18;
  static set readerFontSize(double v) => _p.setDouble('readerFontSize', v);

  static double get readerLineHeight => _p.getDouble('readerLineHeight') ?? 1.75;
  static set readerLineHeight(double v) =>
      _p.setDouble('readerLineHeight', v);

  /// page = 左右翻页，scroll = 上下滚动
  static String get readerTurn => _p.getString('readerTurn') ?? 'page';
  static set readerTurn(String v) => _p.setString('readerTurn', v);

  // ---------- 更新 ----------
  /// GitHub 仓库 owner/name。应用内更新查的是它的 latest release。
  static String get updateRepo =>
      _p.getString('updateRepo') ?? 'yanyuan-cn/shijian';
  static set updateRepo(String v) => _p.setString('updateRepo', v.trim());

  static String get updateChannel =>
      _p.getString('updateChannel') ?? 'github'; // github / manifest
  static set updateChannel(String v) => _p.setString('updateChannel', v);

  static bool get checkUpdateOnStart =>
      _p.getBool('checkUpdateOnStart') ?? true;
  static set checkUpdateOnStart(bool v) =>
      _p.setBool('checkUpdateOnStart', v);

  static String get skippedVersion => _p.getString('skippedVersion') ?? '';
  static set skippedVersion(String v) => _p.setString('skippedVersion', v);

  static int get lastBackupAt => _p.getInt('lastBackupAt') ?? 0;
  static set lastBackupAt(int v) => _p.setInt('lastBackupAt', v);

  // ---------- 通用 ----------
  static String? getString(String k) => _p.getString(k);
  static Future<void> setString(String k, String v) => _p.setString(k, v);
  static bool? getBool(String k) => _p.getBool(k);
  static Future<void> setBool(String k, bool v) => _p.setBool(k, v);
  static Future<void> remove(String k) => _p.remove(k);
}
