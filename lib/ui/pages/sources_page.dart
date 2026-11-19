/// 数据源与网络设置。
///
/// 这里决定「能不能匹配到封面/简介」—— 但匹配永远是锦上添花，
/// 手工填写必须一切正常（接口全挂也不能挡住保存）。
library;

import 'package:flutter/material.dart';

import '../../data/settings.dart';
import '../../net/meta.dart';
import '../kit.dart';
import '../theme.dart';

class SourcesPage extends StatefulWidget {
  const SourcesPage({super.key});

  @override
  State<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends State<SourcesPage> {
  final _tmdb = TextEditingController(text: Settings.tmdbKey ?? '');
  final _omdb = TextEditingController(text: Settings.omdbKey ?? '');
  final _proxy = TextEditingController(text: Settings.proxy ?? '');
  bool _auto = Settings.autoMatch;
  bool _proxyMetaOnly = Settings.proxyOnlyMeta;
  String _testing = '';

  @override
  void dispose() {
    _tmdb.dispose();
    _omdb.dispose();
    _proxy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bar,
        title: const Text('数据源与网络', style: TextStyle(fontSize: 16)),
        elevation: 0,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _label('匹配'),
          _field('TMDB API Key', _tmdb, '电影/剧集海报与简介（themoviedb.org 免费申请）'),
          _field('OMDb Key（可选）', _omdb, '补充评分与简介'),
          _switchTile('添加时自动匹配', _auto, (v) {
            setState(() => _auto = v);
            Settings.autoMatch = v;
          }),
          const SizedBox(height: 6),
          _hint('关掉之后，添加时只显示「匹配数据源」按钮，不会自动发请求 —— 国内网络不稳时建议关。'),
          const SizedBox(height: 22),
          _label('网络'),
          _field('HTTP 代理', _proxy, 'host:port，例如 127.0.0.1:7890'),
          _switchTile('只让匹配请求走代理', _proxyMetaOnly, (v) {
            setState(() => _proxyMetaOnly = v);
            Settings.proxyOnlyMeta = v;
          }),
          const SizedBox(height: 10),
          Row(
            children: [
              _btn('保存', () {
                Settings.tmdbKey = _tmdb.text.trim();
                Settings.omdbKey = _omdb.text.trim();
                Settings.proxy = _proxy.text.trim();
                toast(context, '已保存');
              }),
              const SizedBox(width: 10),
              _btn('测试连接', _test),
            ],
          ),
          if (_testing.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(_testing, style: T.small.copyWith(color: C.accent2)),
          ],
          const SizedBox(height: 26),
          _label('说明'),
          _hint('· 匹配只是省事，所有字段都能手填，随时能在编辑里改。\n'
              '· 匹配到的封面会下载到本地，之后断网也看得到。\n'
              '· 数据源在国内常被墙，配好代理或自己搭个转发就行。'),
        ],
      ),
    );
  }

  Future<void> _test() async {
    Settings.tmdbKey = _tmdb.text.trim();
    Settings.proxy = _proxy.text.trim();
    setState(() => _testing = '测试中…');
    final lines = <String>[];
    for (final src in const ['Google Books', 'Open Library', 'TMDB', 'Bangumi']) {
      final t = DateTime.now();
      String r;
      try {
        final list = await MetaService.probe(src);
        r = list >= 0 ? '通（$list 条）' : '不可用';
      } catch (e) {
        r = '失败';
      }
      final ms = DateTime.now().difference(t).inMilliseconds;
      lines.add('$src：$r · $ms ms');
    }
    if (mounted) setState(() => _testing = lines.join('\n'));
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(s, style: T.kicker),
      );

  Widget _hint(String s) => Padding(
        padding: const EdgeInsets.only(left: 4, top: 6),
        child: Text(s, style: T.small.copyWith(height: 1.7)),
      );

  Widget _field(String label, TextEditingController c, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: T.bodyDim.copyWith(fontSize: 12.5)),
            const SizedBox(height: 6),
            TextField(
              controller: c,
              style: const TextStyle(fontSize: 13.5, color: C.text),
              decoration: InputDecoration(hintText: hint),
            ),
          ],
        ),
      );

  Widget _switchTile(String title, bool v, ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 14, color: C.text))),
            Switch(value: v, onChanged: onChanged),
          ],
        ),
      );

  Widget _btn(String label, VoidCallback onTap) => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: C.panel2,
          foregroundColor: C.text,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          textStyle: const TextStyle(fontSize: 13),
        ),
        child: Text(label),
      );
}
