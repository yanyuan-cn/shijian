import 'package:flutter_test/flutter_test.dart';
import 'package:shijian/core/ids.dart';
import 'package:shijian/core/model.dart';
import 'package:shijian/core/section.dart';

void main() {
  test('ULID 是 26 字符且单调', () {
    final a = Ids.ulid();
    final b = Ids.ulid();
    expect(a.length, 26);
    expect(a.compareTo(b) <= 0, isTrue);
  });

  test('Item 往返不丢字段', () {
    final it = Item(
      id: Ids.ulid(),
      type: ST.book,
      title: '三体',
      creator: '刘慈欣',
      year: '2008',
      meta: {'prog': 42, 'ar': 0.42, 'tags': ['科幻']},
      addedAt: 1000,
      updatedAt: 2000,
      deviceId: 'dev',
    );
    final back = Item.fromRow(it.toRow());
    expect(back.title, '三体');
    expect(back.type, ST.book);
    expect(back.progress, 42);
    expect(back.aspect, closeTo(0.42, 1e-9));
    expect(back.metaStr('tags'), isNotNull);
  });

  test('每个板块都有字段表和标题', () {
    for (final t in ST.all) {
      final s = SectionSpec.of(t);
      expect(s.fields, isNotEmpty);
      expect(s.titleLabel, isNotEmpty);
    }
  });
}
