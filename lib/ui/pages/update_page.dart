import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../platform/updater.dart';
import '../kit.dart';
import '../theme.dart';

/// 「版本与更新」：当前版本 + 检查更新 + 更新日志，合成一个入口。
class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key});

  static const String current = '1.1.0';

  /// 更新日志：新的在最上面。
  static const List<(String, List<String>)> log = [
    (
      '1.1.0',
      [
        '书架重做成真三维盒子：书脊、封面、书顶高光分别按透视投影，不再是扁卡片',
        '书架间距、倾角、抽出位移全部对齐旧版 CSS 数值',
        '拖动书架的每一帧只重绘，不再重算阴影——跟手感明显变好',
        '书脊书名改为逐字直立的竖排（原来整行被转了 90°，字是躺着的）',
        '影视海报墙的列间距与景深、剧集卡片的三段式位移改回原版参数',
        '「我的」里把更新日志和检查更新合成一个入口',
        '换上新图标',
      ],
    ),
    (
      '1.0.14',
      [
        '中转地址填错时会提示「返回的不是预期的 JSON」，不再是看不懂的原始异常',
      ],
    ),
    (
      '1.0.13',
      [
        '代理栏升级成「代理 / 中转」二合一：带端口当代理，不带端口当中转',
        '支持 socks5:// 写法',
      ],
    ),
    (
      '1.0.12',
      [
        '书架拖动更流畅（书脊、封面各自独立重绘）',
        '书脊书名竖排',
        '数据源报错更具体（连接超时 / 握手失败 / HTTP 状态码）',
      ],
    ),
    (
      '1.0.9 – 1.0.11',
      [
        '应用内更新端到端可用：检测 → 下载（断点续传）→ 系统安装确认 → 覆盖安装',
        '按手机 CPU 架构自动挑对应的安装包',
        '更新失败会显示具体原因',
      ],
    ),
    (
      '1.0.3 – 1.0.8',
      [
        '书架居中、书脊配色、抽屉缩略图',
        '图片卡片、链接时间轴按原版重排',
      ],
    ),
    (
      '1.0.2',
      [
        '侧边栏改成「当前板块的条目索引」，点条目直接定位',
        '加号改成先选版块再填表',
        '影视分段改回原版的居中胶囊按钮',
      ],
    ),
    (
      '1.0.1',
      [
        '修复首次启动崩溃（插件版本问题）',
      ],
    ),
    (
      '1.0.0',
      [
        '首个版本：六板块浏览、统一添加编辑删除、全局搜索、阅读器、导入导出',
      ],
    ),
  ];

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  String _ver = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) {
      if (!mounted) return;
      setState(() => _ver = p.version);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bar,
        surfaceTintColor: Colors.transparent,
        title: const Text('版本与更新'),
        titleTextStyle: T.logo.copyWith(fontSize: 16),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2A3B58), Color(0xFF10151D)],
                        ),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: C.line),
                      ),
                      child: const Icon(Icons.auto_awesome,
                          size: 20, color: C.accent2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('拾间',
                              style: T.sectionTitle.copyWith(fontSize: 15)),
                          const SizedBox(height: 3),
                          Text(_ver.isEmpty ? '读取中…' : '当前版本 $_ver',
                              style: T.small),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () => Updater.check(context, manual: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: C.accent,
                        foregroundColor: const Color(0xFF0B0F16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      child: const Text('检查更新',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('更新检查走 GitHub Release，国内可能需要一点时间；'
                    '下载完会弹系统安装确认，装完数据不丢。',
                    style: T.small.copyWith(height: 1.6)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('更新日志', style: T.kicker.copyWith(letterSpacing: 1.6)),
          ),
          for (final e in UpdatePage.log) _entry(e.$1, e.$2),
        ],
      ),
    );
  }

  Widget _entry(String version, List<String> lines) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('v$version',
                  style: T.sectionTitle.copyWith(fontSize: 13.5)),
              const SizedBox(width: 8),
              if (version == UpdatePage.current)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: C.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('当前',
                      style: TextStyle(
                          fontSize: 10,
                          color: C.accent2,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: C.text3,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(l,
                        style: T.bodyDim.copyWith(fontSize: 12.5, height: 1.65)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
