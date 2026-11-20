import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme.dart';

/// 对照用：把旧版单文件 HTML 直接跑在 WebView 里。
/// 目的只是看「一模一样」长什么样，以及测一下动效流畅度。
class HtmlPage extends StatefulWidget {
  const HtmlPage({super.key});

  @override
  State<HtmlPage> createState() => _HtmlPageState();
}

class _HtmlPageState extends State<HtmlPage> {
  late final WebViewController _c;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(C.bg)
      ..loadFlutterAsset('assets/www/index.html');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        top: false,
        child: WebViewWidget(controller: _c),
      ),
    );
  }
}
