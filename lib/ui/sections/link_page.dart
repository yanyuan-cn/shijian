/// 链接：竖向时间轴 + 点开即展开。
///
/// 这一板块最简单，所以它是骨架的第一个试金石：列表、展开、动作、编辑、删除
/// 全在这里跑通，其它板块照抄结构换列表形态即可。
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
        final rows = <Widget>[];
        String lastMonth = '';
        for (var i = 0; i < items.length; i++) {
          final it = items[i];
          final d = DateTime.fromMillisecondsSinceEpoch(it.addedAt);
          final month = '${d.year} 年 ${d.month} 月';
          if (month != lastMonth) {
            lastMonth = month;
            rows.add(Padding(
              padding: EdgeInsets.only(top: rows.isEmpty ? 0 : 18, bottom: 8),
              child: Text(month, style: T.kicker),
            ));
          }
          rows.add(_Entry(
            item: it,
            isOpen: _open.contains(it.id),
            onTap: () => setState(() {
              if (!_open.remove(it.id)) _open.add(it.id);
            }),
          ));
        }
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: rows,
        );
      },
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.item, required this.isOpen, required this.onTap});

  final Item item;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = item.title.isEmpty ? '?' : item.title.characters.first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 时间轴：圆点 + 竖线
        SizedBox(
          width: 34,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 16),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2836),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: C.line),
                ),
                alignment: Alignment.center,
                child: Text(initial,
                    style: TextStyle(
                        fontFamily: T.serif,
                        fontSize: 13,
                        color: C.accent2)),
              ),
              Container(
                width: 1,
                height: 30,
                color: C.line,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: C.panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: C.text,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.public, size: 12, color: C.text3),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(item.creator ?? item.sourceUrl ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.small),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.topCenter,
                    child: isOpen
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.metaStr('desc') != null) ...[
                                const SizedBox(height: 8),
                                Text(item.metaStr('desc')!,
                                    style: T.bodyDim
                                        .copyWith(fontSize: 12.5)),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _btn('打开', () => _open(context)),
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
      ],
    );
  }

  Future<void> _open(BuildContext context) async {
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
            color: C.panel2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: C.accent2)),
        ),
      );
}
