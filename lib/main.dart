import 'package:flutter/material.dart';

import 'data/app_state.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 不 await：先把第一帧画出来（深色背景 + 转圈），再去开库。
  // 首次启动要建数据库、写种子数据，await 在这里会让用户盯着白屏。
  App.I.init();
  runApp(const ShijianApp());
}

class ShijianApp extends StatelessWidget {
  const ShijianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '拾间',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const Shell(),
    );
  }
}
