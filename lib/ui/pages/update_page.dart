import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../platform/updater.dart';
import '../kit.dart';
import '../theme.dart';

/// 「版本与更新」：当前版本 + 检查更新 + 更新日志，合成一个入口。
class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key});

  static const String current = '1.16.0';

  /// 更新日志：新的在最上面。
  static const List<(String, List<String>)> log = [
    (
      '1.16.0',
      [
        '书架固定显示九本：中间那本永远是正中推出的那本，左右各四本',
        '去掉了「到第一本往左推 / 到最后一本往右推」的逻辑，每屏位置都一样',
        '间距略微放宽（36 → 40），九本铺满一屏',
      ],
    ),
    (
      '1.15.0',
      [
        '书架：不再从屏幕中间开始——书多时第一本贴左边距、最后一本贴右边距，两边留白一致',
        '书架：书少到一屏放得下时，整排居中，左右留白相等',
      ],
    ),
    (
      '1.14.0',
      [
        '书架改成只画书脊：书脊加厚、间距收紧，一屏能多看到好几本',
        '不再有侧面封面，所以不会出现角度问题；想看封面点开那本，详情页是大图',
      ],
    ),
    (
      '1.13.0',
      [
        '书架：封面不再歪着——去掉错切和透视，改成竖直的侧封面，靠「越往外越暗」表达受光衰减',
        '书架：封面比书脊略矮一点（上下各缩 5px），看起来是往后收进去的一面，不再像两块并排的书脊',
        '书架：上沿加了一条受光线，和书脊顶部的切面对齐',
      ],
    ),
    (
      '1.12.0',
      [
        '书架：封面和书脊的接缝补齐了（右上角不再露缝）',
        '书架：封面收窄了一点，不再拉得太开，整排更紧凑',
        '书架：推出来的那本往左让半个身位，右侧完整露出封面，并且压在最上层不被邻书切掉',
        '图集：修好「给了相册权限还说没权限」——现在按「完全访问/部分访问」都算有权限',
      ],
    ),
    (
      '1.11.0',
      [
        '书架：书变薄了（书脊变窄、封面露出更宽的一块），整排更像真书架上密排的书',
        '书架：封面改成压在书脊前面的一层斜切面，不再是「竖着嵌进去的一条」',
        '书架：整排最后一本也有完整的封面（之前只有书脊）',
        '图集：上传时「分类」改成从已有分类里选，也可以「＋ 新建」',
        '图集：选图用自建的相册选择器，可多选一次导入多张',
        '图集：勾选「导入后从相册删除原图」，导入后手机相册里不再留重复文件（会弹一次系统确认）',
      ],
    ),
    (
      '1.10.0',
      [
        '书架：封面不再被压成一条窄缝，按斜视角铺开，边缘那本也能看到完整的封面',
        '书架：封面与书脊的上下边对齐，不再有错位的顶边',
        '影视：卡片角落显示「想看 / 在看 / 看完」，一眼看出进度',
        '影视：「类型」从手输改成多选（剧情、科幻、悬疑…），选中即用',
      ],
    ),
    (
      '1.9.0',
      [
        '每段恢复首行缩进两个字（epub 那条解析路径把缩进写在块外面，切片时被切掉了）',
        'PDF 现在能直接看了：不重排，按原样一页页显示，可双指放大、会记进度',
        'epub 里以引号开头的段落也统一缩进，不再出现「一段有缩进一段没有」',
      ],
    ),
    (
      '1.8.0',
      [
        '正文不再挤成一整段：段落重排改用「典型行长」判断段尾，短行才另起一段',
        '章标题放大到 1.45 倍、加粗、整行居中（以前只能靠左）',
        '新增「行距」设置：1.40 – 2.40 可调，和字号并排',
        '翻页方式改成三选一：仿真 / 平滑 / 上下，随时切换',
        '修复：阅读器翻页时上一页的字会从当前页字缝里透出来',
      ],
    ),
    (
      '1.7.0',
      [
        '阅读器解析层重写：txt 的硬换行会被重排成真正的段落，不再一句一行',
        '目录页识别：原书里那串「1. / 2. / 3. …」的目录页不再被当正文，而是拿来生成目录',
        '章节识别支持多种写法：第X章、第X节、数字编号、一二三、序言/后记/尾声/楔子',
        '排版有层级了：章标题加大加粗并单独成段，正文首行缩进两格、两端对齐',
        '图注（作者·年份·材质·馆藏）自动识别成小号灰字',
        'epub 用自带的 nav/NCX 目录，章节名就是出版方写的那个',
        '「目录」按钮挪到底部控制条，和字号、主题、翻页放在一起',
        '新增仿真翻页：左右翻页时可以拖着书页走，松手按力度翻或弹回',
        '修复：书架最后一本书的封面会整块露出来',
      ],
    ),
    (
      '1.6.0',
      [
        '书籍：添加/编辑里新增「电子书文件」入口，支持 txt / epub（可直接阅读）与 pdf / mobi / azw3 / fb2（先归档）',
        '图集：侧边栏改成按分类分组，底部可以「＋ 新建分类」；主界面卡片右下角显示所属分类',
        '链接：详情不再是白屏，能看到完整地址并复制',
        '影视：电影显示「观看进度」可加减或直接设置；剧集改成手输「已看第几集」，进度按集数算',
        '自动匹配改为多源并行 + 10 分钟缓存，不再一个接一个等，明显变快',
        '清掉了各版块顶部、底部的提示文案（「左右滑动挑选」这类）',
        '移除了影视板块的示例数据，新装不再自带电影/剧集',
      ],
    ),
    (
      '1.5.0',
      [
        '书架：放回动画不再「先飘到别处再跳回来」——起止位置改成按几何算准，收回就是收回',
        '书架：书与书之间加了接触阴影，书顶加了受光切面，整排不再是并排的卡片',
        '书架：中心那本抽出更明显，两侧的书会被压暗一点，层次更像真书架',
        '书籍匹配新增 NeoDB 数据源（放在第一位）：中文书 ISBN 命中率高，出版社是中文原名，封面无防盗链',
        '数据源自检新增 NeoDB 与 ISBN 两条，能直接看出哪一档在生效',
        '移除 Hero 自动测量（透视变换下它量不准，正是「跳一下」的根因）',
      ],
    ),
    (
      '1.4.0',
      [
        '书架：聚焦的那本真正落在屏幕正中（去掉了旧的补偿位移）',
        '书架：点旁边那本只会滑过去把它推起来，再点一次才展开',
        '打开/放回时封面不再有文字，飞行过程只是一次缩放，标题不再跳',
        '更新下载默认走加速镜像，不再卡在几 KB/s',
        '数据源新增 Google Books Key（可选）：填了才能查书，Open Library 作兜底',
      ],
    ),
    (
      '1.3.0',
      [
        '书架：进软件时回到上次停留的那一本，不再每次都从中间开始',
        '书架：书的模型加厚加大（56×272），不再细长，比例更接近真书',
        '书架：点开/放回同一本书，位置纹丝不动，不再先跳到第一本',
        '书架：抽出用封面形飞行卡 + 直线插值，书名不再横竖乱跳',
        '书籍表单新增 ISBN 输入，「按码匹配」直接查封面/作者/年份/简介',
        '书本数据源改走 Open Library 的 ISBN 接口，中文书命中率明显提高',
        '首次安装自动填好中转地址，国内打开就能用匹配',
      ],
    ),
    (
      '1.2.0',
      [
        '书架：整排共用一套透视（-26° 倾斜），聚焦那本精确落在正中',
        '书架：手指走多远整排就走多远，1:1 跟手，不再有阻尼延迟',
        '书架：松手用弹簧吸附，会滑过去、轻微过冲再回弹',
        '书架：书脊三段渐变 + 右侧棱线高光 + 左侧暗边，不再是一块纯色',
        '点击书脊 → 从书架位置抽出并展开成详情页（共享元素转场）',
        '侧边栏点某一本 → 书架自动滑到那本并高亮',
        '详情页封面改成横排排版封面，配简介与进度',
      ],
    ),
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
