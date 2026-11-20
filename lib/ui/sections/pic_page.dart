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
          const pad = 20.0;
          const gap = 16.0;
          final colW = (c.maxWidth - pad * 2 - gap) / 2;
          final left = <int>[];
          final right = <int>[];
          var hl = 0.0, hr = 0.0;
          for (var i = 0; i < items.length; i++) {
            final ar = items[i].aspect.clamp(0.4, 2.6);
            final h = colW / ar;
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
            padding: const EdgeInsets.fromLTRB(pad, 16, pad, 32),
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
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: width,
        height: math.max(60, width / ar),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x12FFFFFF)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x66000000),
                blurRadius: 30,
                offset: Offset(0, 10))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CoverArt(item: item, cacheWidth: 700, showTitle: false),
              // 原版 .pic .img::after：上白下黑的一层薄纱
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x0AFFFFFF), Color(0x47000000)],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(13, 26, 13, 11),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x99000000)],
                    ),
                  ),
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.48,
                      color: C.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
