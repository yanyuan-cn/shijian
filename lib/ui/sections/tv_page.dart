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
                // 旧版：卡片基准 230×330，按屏宽的 0.62 缩放
                final cardW = (c.maxWidth * 0.62).clamp(180.0, 300.0);
                final cardH = cardW * 330 / 230;
                return PageView.builder(
                  controller: _pc,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final off = (i - _page).clamp(-2.0, 2.0);
                    final a = off.abs().clamp(0.0, 1.0);
                    // 中心卡：上抬 26、放大 1.06；两侧卡：左移/下移/旋转/缩到 0.93
                    final dy = -26 * (1 - a) + 9 * a;
                    final dx = off * 34;
                    final angle = off * 7 * math.pi / 180;
                    final scale = 1.06 - 0.13 * a;
                    return Center(
                      child: Transform.translate(
                        offset: Offset(dx, dy),
                        child: Transform.rotate(
                          angle: angle,
                          child: Transform.scale(
                            scale: scale,
                            child: SizedBox(
                              width: cardW,
                              height: cardH,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _Card(
                                    item: items[i],
                                    onTap: () =>
                                        showItemSheet(context, items[i]),
                                  ),
                                  // 亮度 1 → 0.62
                                  if (a > 0.01)
                                    IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.38 * a),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
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
              CoverArt(item: item, cacheWidth: 600, showTitle: false),
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
