// 离线渲染书架，用来跟旧版 HTML 截图逐像素比对（不需要装模拟器）。
//
// 用法（只在需要迭代视觉时用）：
//   cd D:\shijian\app
//   flutter test test/render_shelf_test.dart --update-goldens
// 产物：test/goldens/shelf-390x844.png
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shijian/core/model.dart';
import 'package:shijian/ui/sections/shelf_view.dart';

Future<void> _load(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(bytes.buffer.asByteData()));
  await loader.load();
}

Item _book(String title, String creator, String c1, String c2, int i) => Item(
      id: 'book-$i',
      type: ST.book,
      title: title,
      creator: creator,
      year: '2020',
      meta: {'c1': c1, 'c2': c2},
      addedAt: 1767225600000 + i * 1000,
      updatedAt: 1767225600000 + i * 1000,
      deviceId: 'test',
    );

void main() {
  testWidgets('shelf render 390x844', (tester) async {
    await _load('serif', r'C:\Windows\Fonts\NotoSerifSC-VF.ttf');
    await _load('sans', r'C:\Windows\Fonts\NotoSansSC-VF.ttf');

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final books = [
      _book('百年孤独', '加西亚·马尔克斯', '#2A3B58', '#131B29', 0),
      _book('夜晚的潜水艇', '陈春成', '#1F4B41', '#0E2A24', 1),
      _book('三体', '刘慈欣', '#2A3B58', '#131B29', 2),
      _book('长安的荔枝', '马伯庸', '#7A4A22', '#3D2410', 3),
      _book('额尔古纳河右岸', '迟子建', '#24402C', '#101F16', 4),
      _book('漫长的告别', '雷蒙德·钱德勒', '#5B2540', '#2A0F1D', 5),
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'sans',
          scaffoldBackgroundColor: const Color(0xFF0E1116),
        ),
        home: const SizedBox.shrink(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'sans',
          scaffoldBackgroundColor: const Color(0xFF0E1116),
        ),
        home: Scaffold(
          body: ShelfView(
            books: books,
            onOpen: (_) {},
            animateIn: false,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 1200));

    await expectLater(
      find.byType(ShelfView),
      matchesGoldenFile('goldens/shelf-390x844.png'),
    );
  });
}
