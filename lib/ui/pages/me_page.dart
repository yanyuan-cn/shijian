/// 「我的」：统计、数据源、备份、更新、关于。
///
/// 这一页是唯一允许堆功能入口的地方 —— 别把设置散到各个板块里。
library;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/model.dart';
import '../../data/app_state.dart';
import '../../data/settings.dart';
import '../../data/zip_io.dart';
import '../../platform/updater.dart';
import 'update_page.dart';
import '../kit.dart';
import '../theme.dart';
import 'sources_page.dart';
import 'html_page.dart';

class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  String _ver = '';
  String _usage = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) {
      if (mounted) setState(() => _ver = '${p.version} (${p.buildNumber})');
    });
    _loadUsage();
  }

  /// 存储占用：走一次目录统计，算完再 setState。
  /// 以前用了个 static 变量 + 无通知的刷新，结果永远停在「计算中…」。
  Future<void> _loadUsage() async {
    try {
      final bytes = await App.I.blobs.usage();
      if (mounted) setState(() => _usage = fmtBytes(bytes));
    } catch (_) {
      if (mounted) setState(() => _usage = '—');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.I,
      builder: (context, _) {
        final all = App.I.all;
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _stats(all),
            const SizedBox(height: 18),
            _group('数据', [
              _tile('导入 / 导出', '打包成 zip，可以换机、备份', Icons.swap_vert,
                  () => showIoSheet(context)),
              _tile(
                  '上次备份',
                  Settings.lastBackupAt == 0
                      ? '还没备份过 —— 建议现在做一次'
                      : fmtDateFull(Settings.lastBackupAt),
                  Icons.shield_outlined,
                  () => showIoSheet(context)),
            ]),
            const SizedBox(height: 18),
            _group('数据源', [
              _tile('数据源与网络', 'TMDB / 豆瓣式匹配、HTTP 代理', Icons.cloud_outlined,
                  () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SourcesPage()));
              }),
            ]),
            const SizedBox(height: 18),
            _group('关于', [
              _tile(
                  '版本与更新',
                  _ver.isEmpty ? '更新日志 · 检查更新' : '$_ver · 更新日志与检查更新',
                  Icons.system_update_outlined, () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const UpdatePage()));
              }),
              _tile('存储', _usage.isEmpty ? '计算中…' : _usage,
                  Icons.folder_outlined, _loadUsage),
              _tile('说明', '本地优先：不联也能用，数据只在这台手机上',
                  Icons.lock_outline, null),
              _tile('HTML 对照预览', '用 WebView 跑旧版单文件，看原版长什么样',
                  Icons.code_outlined, () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HtmlPage()));
              }),
            ]),
            const SizedBox(height: 22),
            Center(
              child: Text('拾间 · 收藏在，就找得到', style: T.small),
            ),
          ],
        );
      },
    );
  }

  Widget _stats(List<Item> all) {
    final counts = <String, int>{
      ST.book: 0,
      ST.movie: 0,
      ST.tv: 0,
      ST.pic: 0,
      ST.link: 0,
    };
    for (final e in all) {
      counts[e.type] = (counts[e.type] ?? 0) + 1;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2230), Color(0xFF141922)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('共 ${all.length} 件收藏', style: T.sectionTitle),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final e in const [
                (ST.book, '书'),
                (ST.movie, '电影'),
                (ST.tv, '剧集'),
                (ST.pic, '图'),
                (ST.link, '链接'),
              ])
                Expanded(
                  child: Column(
                    children: [
                      Text('${counts[e.$1] ?? 0}',
                          style: const TextStyle(
                              fontFamily: T.serif,
                              fontSize: 19,
                              color: C.text)),
                      const SizedBox(height: 3),
                      Text(e.$2, style: T.small),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _group(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title, style: T.kicker),
          ),
          Container(
            decoration: BoxDecoration(
              color: C.panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: C.line),
            ),
            child: Column(children: children),
          ),
        ],
      );

  Widget _tile(String title, String sub, IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 19, color: C.text2),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 14, color: C.text)),
                  const SizedBox(height: 3),
                  Text(sub, style: T.small),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, size: 18, color: C.text3),
          ],
        ),
      ),
    );
  }
}
