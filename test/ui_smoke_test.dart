/// UI 冒烟测试：在测试环境里真跑一遍各板块页面，确认没有布局溢出、
/// 空指针、初始化异常。真机验证仍然必须做，但这一层能在几秒内挡掉大多数
/// 「点进去就白屏 / 崩」的问题。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:shijian/data/app_state.dart';
import 'package:shijian/data/db.dart';
import 'package:shijian/data/settings.dart';
import 'package:shijian/ui/pages/me_page.dart';
import 'package:shijian/ui/pages/search_page.dart';
import 'package:shijian/ui/sections/book_page.dart';
import 'package:shijian/ui/sections/link_page.dart';
import 'package:shijian/ui/sections/movie_page.dart';
import 'package:shijian/ui/sections/pic_page.dart';
import 'package:shijian/ui/sections/tv_page.dart';
import 'package:shijian/ui/theme.dart';

void main() {
  late Directory tmp;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tmp = await Directory.systemTemp.createTemp('shijian_ui_');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Settings.init();
    await App.I.init(baseDir: tmp);
    expect(App.I.ready, isTrue);
    expect(App.I.error, isNull);
  });

  tearDownAll(() async {
    await Db.close();
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(body: child),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));
  }

  testWidgets('书架渲染且可拖动', (tester) async {
    await pump(tester, const BookPage());
    expect(tester.takeException(), isNull);
    expect(find.text('三体'), findsWidgets);
    await tester.drag(find.byType(BookPage), const Offset(-120, 0));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('电影海报墙渲染并可滚动', (tester) async {
    await pump(tester, const MoviePage());
    expect(tester.takeException(), isNull);
    expect(find.text('海上钢琴师'), findsWidgets);
    await tester.drag(find.byType(MoviePage), const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('剧集扇形渲染并可横扫', (tester) async {
    await pump(tester, const TvPage());
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(TvPage), const Offset(-200, 0));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('图片瀑布流渲染', (tester) async {
    await pump(tester, const PicPage());
    expect(tester.takeException(), isNull);
  });

  testWidgets('链接时间轴渲染并可展开', (tester) async {
    await pump(tester, const LinkPage());
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(LinkPage), const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('我的页渲染', (tester) async {
    await pump(tester, const MePage());
    // 版本号来自 package_info，测试环境可能拿不到，这里只要求不崩。
    expect(tester.takeException(), isNull);
  });

  testWidgets('搜索页渲染并出结果', (tester) async {
    await pump(tester, const SearchPage());
    await tester.enterText(find.byType(TextField), '三体');
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('三体'), findsWidgets);
  });

  testWidgets('窄屏不溢出（320 宽）', (tester) async {
    for (final page in <Widget>[
      const BookPage(),
      const MoviePage(),
      const PicPage(),
      const LinkPage(),
    ]) {
      await pump(tester, page, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
    }
  });
}
