/// 外壳：顶栏 + 内容 + 底部 5 个 tab + 左侧抽屉。
///
/// 为什么是底部 tab 而不是纯侧边栏：手机单手可达，切换最频繁的六个板块
/// 里五个放在拇指区；侧边栏留给低频的导入导出与设置。
library;

import 'package:flutter/material.dart';

import '../core/model.dart';
import '../data/app_state.dart';
import 'detail_sheet.dart';
import 'drawer_panel.dart';
import 'kit.dart';
import 'pages/me_page.dart';
import 'pages/search_page.dart';
import 'sections/book_detail.dart';
import 'sections/book_page.dart';
import 'sections/link_page.dart';
import 'sections/movie_page.dart';
import 'sections/pic_page.dart';
import 'sections/tv_page.dart';
import 'sheet_add.dart';
import 'theme.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  String _media = ST.movie;
  final _scaffold = GlobalKey<ScaffoldState>();

  static const _tabs = <(String, IconData, IconData)>[
    ('书', Icons.menu_book_outlined, Icons.menu_book),
    ('影视', Icons.movie_outlined, Icons.movie),
    ('图集', Icons.photo_library_outlined, Icons.photo_library),
    ('链接', Icons.link_outlined, Icons.link),
    ('我的', Icons.person_outline, Icons.person),
  ];

  String get _sub => switch (_tab) {
        0 => '书架',
        1 => _media == ST.movie ? '电影' : '剧集',
        2 => '图集',
        3 => '链接',
        _ => '我的',
      };

  String get _addType => switch (_tab) {
        0 => ST.book,
        1 => _media,
        2 => ST.pic,
        3 => ST.link,
        _ => ST.book,
      };

  /// 抽屉展示的板块：我的页显示五个入口，其余显示当前板块的条目。
  String get _drawerType => switch (_tab) {
        0 => ST.book,
        1 => _media,
        2 => ST.pic,
        3 => ST.link,
        _ => 'me',
      };

  void _openItem(Item it) {
    Future.delayed(const Duration(milliseconds: 130), () {
      if (!mounted) return;
      if (it.type == ST.book) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => BookDetailPage(item: it)));
      } else {
        showItemSheet(context, it);
      }
    });
  }

  void _goSection(String type) {
    setState(() {
      switch (type) {
        case ST.book:
          _tab = 0;
        case ST.movie:
          _tab = 1;
          _media = ST.movie;
        case ST.tv:
          _tab = 1;
          _media = ST.tv;
        case ST.pic:
          _tab = 2;
        case ST.link:
          _tab = 3;
      }
    });
  }

  void _openSearch() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, a, __) => FadeTransition(opacity: a, child: const SearchPage()),
      ),
    );
  }

  void _openAdd() {
    AddSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffold,
      backgroundColor: C.bg,
      drawer: SideDrawer(
        type: _drawerType,
        onTapItem: _openItem,
        onTapSection: _goSection,
      ),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: App.I,
          builder: (context, _) {
            if (!App.I.ready) {
              return const Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2)));
            }
            if (App.I.error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('启动失败\n${App.I.error}',
                      style: const TextStyle(color: C.danger, fontSize: 12)),
                ),
              );
            }
            return Column(
              children: [
                _Header(
                  sub: _sub,
                  onMenu: () => _scaffold.currentState?.openDrawer(),
                  onSearch: _openSearch,
                  onAdd: _openAdd,
                ),
                if (_tab == 1)
                  _Segment(
                    value: _media,
                    onChanged: (v) => setState(() => _media = v),
                  ),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      TickerMode(
                          enabled: _tab == 0, child: const BookPage()),
                      TickerMode(
                        enabled: _tab == 1,
                        child: _media == ST.movie
                            ? const MoviePage()
                            : const TvPage(),
                      ),
                      TickerMode(enabled: _tab == 2, child: const PicPage()),
                      TickerMode(enabled: _tab == 3, child: const LinkPage()),
                      TickerMode(enabled: _tab == 4, child: const MePage()),
                    ],
                  ),
                ),
                _BottomBar(
                  index: _tab,
                  tabs: _tabs,
                  onTap: (i) => setState(() => _tab = i),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.sub,
    required this.onMenu,
    required this.onSearch,
    required this.onAdd,
  });

  final String sub;
  final VoidCallback onMenu;
  final VoidCallback onSearch;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: C.bar,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenu,
            icon: const Icon(Icons.menu, size: 22, color: C.text2),
            splashRadius: 20,
          ),
          const SizedBox(width: 2),
          Text('拾间', style: T.logo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(sub,
                style: T.sub, overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
          IconButton(
            onPressed: onSearch,
            icon: const Icon(Icons.search, size: 22, color: C.text2),
            splashRadius: 20,
          ),
          IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 24, color: C.text2),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xE012161D),
        border: Border(bottom: BorderSide(color: C.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final e in const [(ST.movie, '电影'), (ST.tv, '剧集')]) ...[
            GestureDetector(
              onTap: () => onChanged(e.$1),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  color: value == e.$1 ? C.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(e.$2,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          value == e.$1 ? FontWeight.w600 : FontWeight.w400,
                      color: value == e.$1 ? const Color(0xFF0B0F16) : C.text2,
                    )),
              ),
            ),
            if (e.$1 == ST.movie) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar(
      {required this.index, required this.tabs, required this.onTap});

  final int index;
  final List<(String, IconData, IconData)> tabs;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 62 + bottom,
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: C.bar,
        border: Border(top: BorderSide(color: C.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      index == i ? tabs[i].$3 : tabs[i].$2,
                      size: 22,
                      color: index == i ? C.accent2 : C.text3,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tabs[i].$1,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1,
                        color: index == i ? C.accent2 : C.text3,
                        fontWeight:
                            index == i ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

