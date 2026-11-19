/// ULID 生成：26 字符，前 10 位时间有序，后 16 位随机。
/// 用途：所有条目的稳定主键。时间前缀让「按创建时间排序」不必额外建索引，
/// 也让导出/同步时的对象名天然按时间聚集。
library;

import 'dart:math';

const _crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

class Ids {
  Ids._();

  static final Random _rnd = Random.secure();

  /// 生成 ULID。[at] 仅供测试注入。
  static String ulid([DateTime? at]) {
    final ms = (at ?? DateTime.now()).millisecondsSinceEpoch;
    final sb = StringBuffer();
    for (var i = 9; i >= 0; i--) {
      sb.write(_crockford[(ms >> (i * 5)) & 31]);
    }
    for (var i = 0; i < 16; i++) {
      sb.write(_crockford[_rnd.nextInt(32)]);
    }
    return sb.toString();
  }

  /// 设备标识：首次启动生成一次，写进设置。同步时用它对 LWW 的平局做仲裁。
  static String deviceId() => ulid().substring(10, 20).toLowerCase();
}
