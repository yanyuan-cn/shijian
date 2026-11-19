/// ULID 生成：26 字符，前 10 位时间有序，后 16 位随机（同毫秒内单调递增）。
/// 用途：所有条目的稳定主键。时间前缀让「按创建时间排序」不必额外建索引，
/// 也让导出/同步时的对象名天然按时间聚集。
library;

import 'dart:math';

const _crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

class Ids {
  Ids._();

  static final Random _rnd = Random.secure();
  static int _lastMs = 0;
  static final List<int> _lastRand = List<int>.filled(16, 0, growable: false);

  /// 生成 ULID。[at] 仅供测试注入。
  ///
  /// 同一毫秒内生成的 ULID 会把随机段当作 16 位 32 进制数加一，
  /// 保证后一个字符串一定大于前一个 —— 否则同一毫秒里连加两条，
  /// 排序会随机跳动（原型里没有 id，正是指望这个才不返工）。
  static String ulid([DateTime? at]) {
    final ms = (at ?? DateTime.now()).millisecondsSinceEpoch;
    if (ms == _lastMs) {
      _incrRandom();
    } else {
      _lastMs = ms;
      for (var i = 0; i < 16; i++) {
        _lastRand[i] = _rnd.nextInt(32);
      }
    }
    final sb = StringBuffer();
    for (var i = 9; i >= 0; i--) {
      sb.write(_crockford[(ms >> (i * 5)) & 31]);
    }
    for (var i = 0; i < 16; i++) {
      sb.write(_crockford[_lastRand[i]]);
    }
    return sb.toString();
  }

  static void _incrRandom() {
    for (var i = 15; i >= 0; i--) {
      if (_lastRand[i] < 31) {
        _lastRand[i]++;
        return;
      }
      _lastRand[i] = 0;
    }
    // 整个随机段溢出（概率 32^-16，可忽略）：退回重新随机。
    for (var i = 0; i < 16; i++) {
      _lastRand[i] = _rnd.nextInt(32);
    }
  }

  /// 设备标识：首次启动生成一次，写进设置。同步时用它对 LWW 的平局做仲裁。
  static String deviceId() => ulid().substring(10, 20).toLowerCase();
}
