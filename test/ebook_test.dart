import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shijian/data/ebook.dart';

void main() {
  test('txt：目录页被剔除、硬换行被重排、编号标题成章', () async {
    const raw = '''
查拉图斯特拉如是说

目录

1. 三种变形
2. 道德的讲座
3. 来世论者
4. 蔑视肉体者
5. 快乐与热情
6. 苍白的罪犯

1. 三种变形

我要向你们讲说精神的三种变形。
精神如何变成骆驼，骆驼如何变成狮子，
最后狮子如何变成孩子。

这时候，他看见远处有一座塔，便走了过去。

安瑟尔姆·费尔巴哈 1875年 湿壁画 维也纳艺术学院天顶画

2. 道德的讲座

有人向查拉图斯特拉称赞一位智者。
''';
    final doc = await parseEbook(
        Uint8List.fromList(utf8.encode(raw)), name: '查拉图斯特拉如是说.txt');

    // 目录页的条目不该出现在正文里
    expect(doc.text.contains('5. 快乐与热情'), isFalse);
    // 硬换行被合并成一段
    expect(doc.text.contains('精神如何变成骆驼，骆驼如何变成狮子，最后狮子如何变成孩子。'), isTrue);
    // 章节：两个编号标题
    expect(doc.chapters.length, 2);
    expect(doc.chapters.first.title.contains('三种变形'), isTrue);
    // 图注被识别
    final caption = doc.blocks
        .where((b) => b.kind == BlockKind.caption)
        .map((b) => doc.text.substring(b.offset, b.end))
        .toList();
    expect(caption.any((t) => t.contains('湿壁画')), isTrue);
    // 正文段首有全角缩进
    final firstPara = doc.blocks
        .firstWhere((b) => b.kind == BlockKind.para);
    expect(doc.text.substring(firstPara.offset, firstPara.offset + 2), '\u3000\u3000');
  });

  test('txt：没有目录页时按「第X章」切章', () async {
    const raw = '''
第一章 起

他说了一句很长的话，
这话还没说完就停了。

第二章 承

后面还有很多内容。
''';
    final doc = await parseEbook(Uint8List.fromList(utf8.encode(raw)),
        name: 'test.txt');
    expect(doc.chapters.length, 2);
    expect(doc.text.contains('这话还没说完就停了。'), isTrue);
  });

  test('gbk 编码的 txt 能读出来', () async {
    final bytes = gbk.encode('第一章 测试\n\n正文内容。');
    final doc = await parseEbook(Uint8List.fromList(bytes), name: 'gbk.txt');
    expect(doc.text.isNotEmpty, isTrue);
    expect(doc.text.contains('正文内容'), isTrue);
  });
}
