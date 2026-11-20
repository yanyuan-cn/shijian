/// 电影：三列海报墙 + 滚动景深。
///
/// 景深只做 scale/opacity，**不做 blur** —— 原型的 blur 是低端机掉帧的头号原因，
/// 而人眼在这个暗色背景上根本分不出有没有模糊。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/model.dart';
import '../../data/app_state.dart';
import '../detail_sheet.dart';
import '../kit.dart';
import '../theme.dart';

class MoviePage extends StatefulWidget {
  const MoviePage({super.key});

  @override
  State<MoviePage> createState() => _MoviePageState();
}

class _MoviePageState extends State<MoviePage>
    with AutomaticKeepAliveClientMixin {
  final _off = ValueNotifier<double>(0);
  final _sc = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _sc.addListener(() => _off.value = _sc.offset);
  }

  @override
  void dispose() {
    _sc.dispose();
    _off.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: App.I,
      builder: (context, _) {
        final items = App.I.of(ST.movie);
        if (items.isEmpty) {
          return const EmptyHint(
            icon: Icons.movie_outlined,
            title: '还没有电影',
            sub: '右上角 + 添加，或从数据源匹配',
          );
        }
        return Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.1),
              radius: 1.0,
              colors: [Color(0x00000000), Color(0xB8000000)],
              stops: [0.1, 1],
            ),
          ),
          child: LayoutBuilder(builder: (context, c) {
            const pad = 16.0;
            const gapX = 12.0;
            const gapY = 20.0;
            final tileW = (c.maxWidth - pad * 2 - gapX * 2) / 3;
            final tileH = tileW * 1.5;
            final vh = c.maxHeight;
            return CustomScrollView(
              controller: _sc,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(pad, 16, pad, 28),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: gapY,
                      crossAxisSpacing: gapX,
                      childAspectRatio: 2 / 3,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final it = items[i];
                        final row = i ~/ 3;
                        final centerY =
                            16 + row * (tileH + gapY) + tileH / 2;
                        return AnimatedBuilder(
                          animation: _off,
                          builder: (context, child) {
                            final vc = _off.value + vh / 2;
                            final k = math.min(
                                (centerY - vc).abs() / (vh * 0.62), 1.0);
                            return Opacity(
                              opacity: 1 - 0.42 * k,
                              child: Transform.scale(
                                  scale: 1 - 0.1 * k, child: child),
                            );
                          },
                          child: _Poster(item: it),
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                ),
              ],
            );
          }),
        );
      },
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final rating = item.rating;
    return GestureDetector(
      onTap: () => showItemSheet(context, item),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0x0DFFFFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 40,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CoverArt(item: item, cacheWidth: 360),
              // 原版 .poster::after：上白下黑的薄纱，保证底部白字读得清
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x0DFFFFFF), Color(0x99000000)],
                  ),
                ),
              ),
              Positioned(
                left: 11,
                right: 11,
                bottom: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: T.serif,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (item.year != null) ...[
                      const SizedBox(height: 3),
                      Text(item.year!,
                          style: const TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 0.76,
                            color: Color(0x8CFFFFFF),
                          )),
                    ],
                  ],
                ),
              ),
              if (rating != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(rating,
                        style: const TextStyle(
                            fontSize: 9.5,
                            color: Color(0xFFFFD479),
                            fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
