/// 剧集：扇形牌堆 + 进度环。
///
/// 用 PageView 拿吸附惯性，省掉一套自己写的手势物理 —— 原型里最卡的地方
/// 就是「拖拽跟手 + 松手吸附」手写实现，这里交给 Flutter 的 ScrollPhysics。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/model.dart';
import '../../data/app_state.dart';
import '../detail_sheet.dart';
import '../kit.dart';
import '../theme.dart';

class TvPage extends StatefulWidget {
  const TvPage({super.key});

  @override
  State<TvPage> createState() => _TvPageState();
}

class _TvPageState extends State<TvPage> with AutomaticKeepAliveClientMixin {
  final _pc = PageController(viewportFraction: 0.68);
  double _page = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pc.addListener(() {
      if (_pc.hasClients && _pc.position.haveDimensions) {
        setState(() => _page = _pc.page ?? 0);
      }
    });
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: App.I,
      builder: (context, _) {
        final items = App.I.of(ST.tv);
        if (items.isEmpty) {
          return const EmptyHint(
            icon: Icons.live_tv_outlined,
            title: '还没有剧集',
            sub: '右上角 + 添加',
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                children: [
                  Text('剧集 · ${items.length} 部', style: T.kicker),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final cardH = math.min(c.maxHeight - 64, 392.0);
                final cardW = cardH * 2 / 3;
                return PageView.builder(
                  controller: _pc,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final d = (i - _page).clamp(-2.2, 2.2);
                    final angle = d * 0.085;
                    final dy = d.abs() * 16;
                    return Center(
                      child: Transform.translate(
                        offset: Offset(0, dy),
                        child: Transform.rotate(
                          angle: angle,
                          child: SizedBox(
                            width: cardW,
                            height: cardH,
                            child: _Card(
                              item: items[i],
                              onTap: () => showItemSheet(context, items[i]),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 2),
              child: Text('左右滑动挑选 · 点卡片看详情', style: T.small),
            ),
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.item, required this.onTap});
  final Item item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final seen = (item.seen ?? 0).clamp(0, 100);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x80000000), blurRadius: 22, offset: Offset(0, 12))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              BlobImage(item.cover, cacheWidth: 600),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xE6000000)],
                    stops: [0.45, 1],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: T.serif,
                          fontSize: 17,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            [item.year, item.metaStr('genre')]
                                .whereType<String>()
                                .join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white60),
                          ),
                        ),
                        Text('$seen%',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFA7C4FF),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _Ring(progress: seen / 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: progress.clamp(0, 1),
          minHeight: 5,
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation(C.accent2),
        ),
      ),
    );
  }
}
