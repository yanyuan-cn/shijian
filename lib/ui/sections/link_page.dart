/// 链接：竖向时间轴 + 点开即展开（布局数值照原版 .tl-* 抄）。
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/model.dart';
import '../../data/app_state.dart';
import '../detail_sheet.dart';
import '../form/item_form.dart';
import '../kit.dart';
import '../theme.dart';

class LinkPage extends StatefulWidget {
  const LinkPage({super.key});

  @override
  State<LinkPage> createState() => _LinkPageState();
}

class _LinkPageState extends State<LinkPage> with AutomaticKeepAliveClientMixin {
  final _open = <String>{};

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: App.I,
      builder: (context, _) {
        final items = [...App.I.of(ST.link)]
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
        if (items.isEmpty) {
          return const EmptyHint(
            icon: Icons.link,
            title: '还没有链接',
            sub: '右上角 + 添加一个网址',
          );
        }
        var lastMonth = '';
        final rows = <Widget>[];
        for (var i = 0; i < items.length; i++) {
          final it = items[i];
          final d = DateTime.fromMillisecondsSinceEpoch(it.addedAt);
          final month = '${d.year}.${d.month.toString().padLeft(2, '0')}';
          final showDate = month != lastMonth;
          lastMonth = month;
          rows.add(_Entry(
            item: it,
            index: i,
            isLast: i == items.length - 1,
            dateLabel: showDate ? month : null,
            isOpen: _open.contains(it.id),
            onTap: () => setState(() {
              if (!_open.remove(it.id)) _open.add(it.id);
            }),
          ));
        }
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: rows,
        );
      },
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.item,
    required this.index,
    required this.isLast,
    required this.dateLabel,
    required this.isOpen,
    required this.onTap,
  });

  final Item item;
  final int index;
  final bool isLast;
  final String? dateLabel;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dotColor = index.isEven ? C.accent : const Color(0xFF7A8B6F);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧：日期 + 圆点 + 竖线
          SizedBox(
            width: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dateLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 6),
                    child: Text(
                      dateLabel!,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: C.text3,
                        letterSpacing: 0.95,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.only(left: 12),
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Color(0xFF10151D), spreadRadius: 4),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(left: 16),
                    width: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isLast
                            ? const [
                                Color(0x29FFFFFF),
                                Colors.transparent,
                              ]
                            : const [
                                Color(0x29FFFFFF),
                                Color(0x29FFFFFF),
                              ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161C26),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x0FFFFFFF)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4D000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _Tile(item: item, color: dotColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.14,
                                    height: 1.3,
                                    color: C.text,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.creator ?? item.sourceUrl ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: C.text3,
                                    letterSpacing: 0.44,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: isOpen
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if ((item.metaStr('desc') ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 13),
                                    Text(
                                      item.metaStr('desc')!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.8,
                                        color: Color(0xFFAEB8C7),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _btn('打开', () => _openUrl(context)),
                                      const SizedBox(width: 8),
                                      _btn('详情',
                                          () => showItemSheet(context, item)),
                                      const SizedBox(width: 8),
                                      _btn('编辑', () {
                                        ItemForm.show(context,
                                            type: item.type, item: item);
                                      }),
                                    ],
                                  ),
                                ],
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(BuildContext context) async {
    var u = (item.sourceUrl ?? '').trim();
    if (u.isEmpty) {
      toast(context, '这个条目没有网址');
      return;
    }
    if (!u.contains('://')) u = 'https://$u';
    final uri = Uri.tryParse(u);
    if (uri == null) {
      toast(context, '网址不对');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) toast(context, '打不开这个链接');
  }

  Widget _btn(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1B2331),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: C.accent2)),
        ),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item, required this.color});

  final Item item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final initial =
        item.title.isEmpty ? '?' : item.title.characters.first.toUpperCase();
    final tint = item.metaStr('c');
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint != null ? _parse(tint) ?? color : color,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: T.serif,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0B0F16),
        ),
      ),
    );
  }

  Color? _parse(String hex) {
    final s = hex.replaceAll('#', '');
    if (s.length != 6) return null;
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }
}
