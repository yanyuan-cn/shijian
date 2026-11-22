/// 左侧抽屉：当前板块的条目索引（原版 renderDrawer）。
///
/// 不是「板块导航菜单」——原版的抽屉是「这一屏里有什么」的缩略图列表，
/// 点一行就跳到那一条。板块导航靠底部 5 个 tab。
library;

import 'package:flutter/material.dart';

import '../core/model.dart';
import '../data/app_state.dart';
import '../data/settings.dart';
import 'kit.dart';
import 'sections/book_page.dart' show bookColors;
import 'theme.dart';

class SideDrawer extends StatelessWidget {
  const SideDrawer({
    super.key,
    required this.type,
    required this.onTapItem,
    required this.onTapSection,
  });

  /// ST.* 之一；传 'me' 时显示五个板块的入口。
  final String type;
  final ValueChanged<Item> onTapItem;
  final ValueChanged<String> onTapSection;

  static const _sections = <(String, String, String, String, Color)>[
    (ST.book, '书架', '书', '本', Color(0xFF1B2530)),
    (ST.movie, '电影', '影', '部', Color(0xFF2B1216)),
    (ST.tv, '剧集', '剧', '部', Color(0xFF12242C)),
    (ST.pic, '图集', '图', '张', Color(0xFF241E2C)),
    (ST.link, '链接', '链', '条', Color(0xFF18221D)),
  ];

  @override
  Widget build(BuildContext context) {
    final isMe = type == 'me';
    final items = isMe
        ? const <Item>[]
        : (List<Item>.from(App.I.of(type))
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt)));

    final title = isMe ? '拾间' : ST.labels[type]!;
    final count = isMe ? '' : '${items.length} ${_unit(type)}';

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: 340,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF161C26), Color(0xFF0F141B)],
          ),
          border: Border(right: BorderSide(color: Color(0x14FFFFFF))),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('拾间',
                              style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 2.2,
                                  color: C.text3)),
                          const SizedBox(height: 7),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(title,
                                  style: TextStyle(
                                      fontFamily: T.serif,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                      color: C.text)),
                              if (count.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(count,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        letterSpacing: 0.9,
                                        color: C.text3)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close, size: 18, color: C.text3),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
                  children: isMe
                      ? [
                          for (final s in _sections)
                            _letterRow(context, s.$1, s.$2, s.$3, s.$4,
                                App.I.of(s.$1).length, s.$5),
                        ]
                      : type == ST.pic
                          ? _picGroups(context, items)
                          : [for (final it in items) _itemRow(context, it)],
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                    20, 12, 20, 16 + MediaQuery.of(context).padding.bottom),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0x12FFFFFF))),
                ),
                child: Text(
                  isMe
                      ? '点一行进入对应版块'
                      : '共 ${items.length} ${_unit(type)} · 点条目定位',
                  style: const TextStyle(
                      fontSize: 10.5, letterSpacing: 1.2, color: C.text3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _unit(String t) => switch (t) {
        ST.book => '本',
        ST.pic => '张',
        ST.link => '条',
        _ => '部',
      };

  Widget _letterRow(BuildContext context, String type, String name, String ch,
      String unit, int n, Color bg) {
    return _row(
      onTap: () {
        Navigator.pop(context);
        onTapSection(type);
      },
      thumb: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(color: Color(0x1AFFFFFF), spreadRadius: 0.6),
          ],
        ),
        alignment: Alignment.center,
        child: Text(ch,
            style: TextStyle(
                fontFamily: T.serif,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.9))),
      ),
      title: name,
      sub: '$n $unit',
    );
  }

  /// 图集：按分类分组列出，末尾给一个「新建分类」。
  List<Widget> _picGroups(BuildContext context, List<Item> items) {
    const none = '未分类';
    final saved = Settings.picCats;
    final groups = <String, List<Item>>{};
    for (final it in items) {
      final c = (it.metaStr('cat') ?? '').trim();
      groups.putIfAbsent(c.isEmpty ? none : c, () => []).add(it);
    }
    final order = <String>[
      ...saved.where((c) => c.isNotEmpty),
      ...groups.keys.where((c) => !saved.contains(c) && c != none),
      if (groups.containsKey(none)) none,
    ];

    final out = <Widget>[];
    for (final cat in order) {
      final list = groups[cat] ?? const <Item>[];
      out.add(Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Row(
          children: [
            Text(cat,
                style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                    color: C.text2)),
            const SizedBox(width: 6),
            Text('${list.length}',
                style: const TextStyle(fontSize: 10, color: C.text3)),
          ],
        ),
      ));
      if (list.isEmpty) {
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
          child: Text('空', style: TextStyle(fontSize: 11, color: C.text3)),
        ));
      }
      for (final it in list) {
        out.add(_itemRow(context, it));
      }
    }
    out.add(Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _newCategory(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: C.line),
          ),
          child: Row(
            children: [
              const Icon(Icons.add, size: 15, color: C.accent2),
              const SizedBox(width: 8),
              Text('新建分类',
                  style: TextStyle(fontSize: 12.5, color: C.accent2)),
            ],
          ),
        ),
      ),
    ));
    return out;
  }

  Future<void> _newCategory(BuildContext context) async {
    final ctl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建分类'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例如：壁纸 / 截图 / 灵感'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
              child: const Text('确定')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final list = Settings.picCats;
    if (!list.contains(name)) {
      list.add(name);
      await Settings.setPicCats(list);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Widget _itemRow(BuildContext context, Item it) {
    final (sub, meta) = _subMeta(it);
    final isLink = it.type == ST.link;
    return _row(
      onTap: () {
        Navigator.pop(context);
        onTapItem(it);
      },
      thumb: isLink
          ? Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _linkColor(it),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                it.title.isEmpty ? '·' : it.title.characters.first,
                style: TextStyle(
                    fontFamily: T.serif,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.9)),
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 32,
                height: 42,
                child: _thumb(it),
              ),
            ),
      title: it.title,
      sub: sub,
      meta: meta,
    );
  }

  (String, String) _subMeta(Item it) {
    switch (it.type) {
      case ST.book:
        final p = it.progress;
        return (
          [
            if ((it.creator ?? '').isNotEmpty) it.creator!,
            if ((it.status ?? '').isNotEmpty) it.status!
          ].join(' · '),
          p <= 0 ? '' : '$p%',
        );
      case ST.movie:
        return (it.year ?? '', '');
      case ST.tv:
        final total = it.totalEps;
        final seen = it.seenEps;
        return (
          it.year ?? '',
          total > 0 ? '$seen/$total' : (seen <= 0 ? '未看' : '$seen 集')
        );
      case ST.pic:
        return (it.metaStr('cat') ?? '未分类', '');
      default:
        return (it.creator ?? '', '');
    }
  }

  Color _linkColor(Item it) {
    final c = it.metaStr('c');
    if (c != null && c.startsWith('#') && c.length == 7) {
      final v = int.tryParse(c.substring(1), radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    return const Color(0xFF2A3342);
  }

  /// 缩略图：有封面用封面，没有就用条目自己的配色渐变（原版就是纯色块）。
  Widget _thumb(Item it) {
    final h = it.cover;
    if (h != null && h.isNotEmpty) {
      return BlobImage(h, cacheWidth: 96, fit: BoxFit.cover);
    }
    final List<Color> pair;
    if (it.type == ST.book) {
      final c = bookColors(it, 0);
      pair = [c.sp0, c.sp1];
    } else {
      pair = _duo[(it.id.hashCode & 0x7fffffff) % _duo.length];
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pair,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x1AFFFFFF), spreadRadius: 0.6),
        ],
      ),
    );
  }

  static const _duo = <List<Color>>[
    [Color(0xFF2A3B58), Color(0xFF121A28)],
    [Color(0xFF1F4B41), Color(0xFF0C211C)],
    [Color(0xFF7A4A22), Color(0xFF301B0C)],
    [Color(0xFF5B2540), Color(0xFF250D18)],
    [Color(0xFF3D4A66), Color(0xFF171E2B)],
    [Color(0xFF2F4A44), Color(0xFF111E1B)],
    [Color(0xFF4A3D66), Color(0xFF1B1526)],
  ];

  Widget _row({
    required VoidCallback onTap,
    required Widget thumb,
    required String title,
    required String sub,
    String? meta,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            thumb,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, height: 1.2, color: C.text)),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, height: 1.2, color: C.text3)),
                  ],
                ],
              ),
            ),
            if (meta != null && meta.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(meta,
                  style: const TextStyle(
                      fontSize: 10, letterSpacing: 0.4, color: C.text3)),
            ],
          ],
        ),
      ),
    );
  }
}
