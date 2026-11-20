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
        return LayoutBuilder(builder: (context, c) {
          const pad = 16.0;
          const gap = 10.0;
          final tileW = (c.maxWidth - pad * 2 - gap * 2) / 3;
          final tileH = tileW * 1.5;
          final vh = c.maxHeight;
          return CustomScrollView(
            controller: _sc,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(pad, 12, pad, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                    childAspectRatio: 2 / 3,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final it = items[i];
                      final row = i ~/ 3;
                      final centerY = 12 + row * (tileH + gap) + tileH / 2;
                      return AnimatedBuilder(
                        animation: _off,
                        builder: (context, child) {
                          final vc = _off.value + vh / 2;
                          final k =
                              math.min((centerY - vc).abs() / (vh * 0.62), 1.0);
                          return Opacity(
                            opacity: 1 - 0.42 * k,
                            child: Transform.scale(scale: 1 - 0.1 * k, child: child),
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
        });
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverArt(item: item, cacheWidth: 360),
            // 底部压一层渐变，保证白字永远读得清
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                  stops: [0.55, 1],
                ),
              ),
            ),
            Positioned(
              left: 7,
              right: 7,
              bottom: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  if (item.year != null)
                    Text(item.year!,
                        style: const TextStyle(
                            fontSize: 9.5, color: Colors.white60)),
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
    );
  }
}
