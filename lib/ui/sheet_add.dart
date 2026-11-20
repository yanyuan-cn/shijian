/// 「添加到拾间」第一步：选版块。
///
/// 原版是全局一个 + 号，点开先问「放进哪个版块」，再进对应表单。
/// 之前我给每个板块各做了一个 +，点下去只能加当前板块，不符合原版。
library;

import 'package:flutter/material.dart';

import '../core/model.dart';
import '../data/app_state.dart';
import 'form/item_form.dart';
import 'theme.dart';

class AddSheet extends StatelessWidget {
  const AddSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const AddSheet(),
    );
  }

  static const _types = <(String, String, String, String, bool, IconData)>[
    (ST.book, '书', '本', '书脊会插进书架', true, Icons.menu_book_outlined),
    (ST.movie, '电影', '部', '加进海报墙', false, Icons.local_movies_outlined),
    (ST.tv, '剧集', '部', '加进扇形牌堆', false, Icons.tv_outlined),
    (ST.pic, '图集', '张', '可归到分类', false, Icons.photo_library_outlined),
    (ST.link, '链接', '条', '记在时间轴', false, Icons.link),
  ];

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[];
    for (final t in _types) {
      cards.add(_card(context, t));
    }
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF151A22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
      ),
      padding: EdgeInsets.fromLTRB(
          18, 16, 18, 18 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(width: 2),
              const Expanded(
                child: Text('添加到拾间',
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: C.text)),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 20, color: C.text3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('放进哪个版块',
              style: TextStyle(
                  fontSize: 12, letterSpacing: 0.7, color: C.text3)),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 11) / 2;
            return Wrap(
              spacing: 11,
              runSpacing: 11,
              children: [
                for (var i = 0; i < cards.length; i++)
                  SizedBox(width: i == 0 ? c.maxWidth : w, child: cards[i]),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context,
    (String, String, String, String, bool, IconData) t,
  ) {
    final (type, name, unit, desc, wide, icon) = t;
    final n = App.I.of(type).length;
    final ico = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF7DA7FF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 19, color: C.accent2),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name,
            style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: C.text)),
        const SizedBox(height: 4),
        Text(desc,
            style: const TextStyle(fontSize: 11, color: C.text3)),
      ],
    );
    final cnt = Text('$n $unit',
        style: const TextStyle(fontSize: 10.5, color: C.text3));

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        ItemForm.show(context, type: type);
      },
      child: Container(
        padding: wide
            ? const EdgeInsets.symmetric(horizontal: 18, vertical: 16)
            : const EdgeInsets.fromLTRB(16, 16, 16, 15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: wide
            ? Row(
                children: [
                  ico,
                  const SizedBox(width: 16),
                  text,
                  const Spacer(),
                  cnt,
                ],
              )
            : Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [ico, const SizedBox(height: 12), text],
                  ),
                  Positioned(top: -4, right: -2, child: cnt),
                ],
              ),
      ),
    );
  }
}
