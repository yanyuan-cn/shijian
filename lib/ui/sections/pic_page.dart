/// 图集：两列瀑布流 + 宝丽来纸片质感。
///
/// 瀑布流用「两列各自堆叠」而不是 SliverGrid：列宽固定，高度按 ar 预先算好，
/// 滚动时没有任何逐帧计算，低端机也稳。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/model.dart';
import '../../data/app_state.dart';
import '../../platform/image_out.dart';
import '../detail_sheet.dart';
import '../kit.dart';
import '../theme.dart';

class PicPage extends StatefulWidget {
  const PicPage({super.key});

  @override
  State<PicPage> createState() => _PicPageState();
}

class _PicPageState extends State<PicPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: App.I,
      builder: (context, _) {
        final items = App.I.of(ST.pic);
        if (items.isEmpty) {
          return const EmptyHint(
            icon: Icons.photo_library_outlined,
            title: '还没有图片',
            sub: '右上角 + 上传，长按可保存、分享、设为壁纸',
          );
        }
        return LayoutBuilder(builder: (context, c) {
          const pad = 16.0;
          const gap = 12.0;
          final colW = (c.maxWidth - pad * 2 - gap) / 2;
          final left = <int>[];
          final right = <int>[];
          var hl = 0.0, hr = 0.0;
          for (var i = 0; i < items.length; i++) {
            final ar = items[i].aspect.clamp(0.4, 2.6);
            final h = colW / ar + 34;
            if (hl <= hr) {
              left.add(i);
              hl += h + gap;
            } else {
              right.add(i);
              hr += h + gap;
            }
          }
          Widget col(List<int> idx) => Column(
                children: [
                  for (final i in idx)
                    Padding(
                      padding: const EdgeInsets.only(bottom: gap),
                      child: _Polaroid(
                        item: items[i],
                        width: colW,
                        onTap: () => showImageViewer(context, items, i),
                        onLongPress: () => showItemSheet(context, items[i]),
                      ),
                    ),
                ],
              );
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(pad, 14, pad, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: col(left)),
                const SizedBox(width: gap),
                Expanded(child: col(right)),
              ],
            ),
          );
        });
      },
    );
  }
}

class _Polaroid extends StatelessWidget {
  const _Polaroid({
    required this.item,
    required this.width,
    required this.onTap,
    required this.onLongPress,
  });

  final Item item;
  final double width;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final ar = item.aspect.clamp(0.4, 2.6);
    // 用 hash 派生一个稳定的倾角，重新构建时不会跳
    final seed = (item.id.hashCode & 0x7fffffff) % 7;
    final angle = (seed - 3) * 0.006;
    return Transform.rotate(
      angle: angle,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.fromLTRB(7, 7, 7, 9),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE7DB),
            borderRadius: BorderRadius.circular(3),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 10,
                  offset: Offset(0, 5))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  width: width,
                  height: math.max(60, width / ar),
                  child: CoverArt(item: item, cacheWidth: 700),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.2,
                    color: Color(0xFF3A332A),
                    fontFamily: T.serif),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
