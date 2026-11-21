/// 书架：书脊朝外的 3D 书架。
///
/// 几何逐条照抄旧版 CSS（`收藏库-方案一-B-侧边栏.html`）：
///   #s-book     radial-gradient(130% 90% at 50% -10%, #1B2230, #12161F 55%, #0B0F15)
///   --lift      clamp(70px, 13vh, 150px)
///   .rig        bottom: calc(98px + var(--lift)); 整体 rotateY(-26deg)
///   .book       --bkT 44 / --bkH 288 / --bkW 198；stageMetrics(): w<560 → gap62/out76
///   .shelf-top  bottom: lift+44, height:56
///   .shelf-face bottom: lift, height:44
///   .stage      perspective:1500px
///
/// 每本书是一个三维盒子（宽=书厚 bkT、高=bkH、深=封面宽 bkW），可见三个面：
///   .spine  书脊，位于 z=+bkW/2（正对镜头）
///   .bcover 封面，位于 x=+bkT/2 并绕 Y 转 90°（盒子右侧面）
///   .btop   书顶，位于 y=-bkH/2（盒子顶面，本实现用封面顶端高光线近似）
/// 整排共用一套 3D 坐标系（rig 的 perspective + rotateY），这样各面的透视一致，
/// 不再是「贴着屏幕的平面卡片」。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/model.dart';
import '../kit.dart';
import '../theme.dart';

class ShelfView extends StatefulWidget {
  const ShelfView({
    super.key,
    required this.books,
    required this.onOpen,
    this.animateIn = true,
  });

  final List<Item> books;
  final void Function(int index) onOpen;
  final bool animateIn;

  @override
  State<ShelfView> createState() => _ShelfViewState();
}

class _ShelfViewState extends State<ShelfView>
    with SingleTickerProviderStateMixin {
  static const double _tilt = -26 * math.pi / 180;
  static final double _sinT = math.sin(26 * math.pi / 180);
  static final double _cosT = math.cos(26 * math.pi / 180);

  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  double _pos = 0;
  bool _didCenter = false;
  double _from = 0;
  double _to = 0;
  double _dragStart = 0;
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    _entered = !widget.animateIn;
    _snap.addListener(() {
      final t = Curves.easeOutCubic.transform(_snap.value);
      setState(() => _pos = _from + (_to - _from) * t);
    });
    if (widget.animateIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _entered = true);
      });
    }
  }

  @override
  void didUpdateWidget(ShelfView old) {
    super.didUpdateWidget(old);
    if (old.books.length != widget.books.length && !_snap.isAnimating) {
      final n = widget.books.length;
      if (n > 0) _pos = _pos.clamp(0, (n - 1).toDouble());
    }
  }

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  // ---- 旧版 stageMetrics() ----
  _Geo _geo(double w) {
    if (w < 560) {
      return const _Geo(gap: 62, out: 76, bkW: 198, t: 44, h: 288);
    }
    if (w < 980) {
      return const _Geo(gap: 78, out: 86, bkW: 198, t: 44, h: 288);
    }
    return const _Geo(gap: 98, out: 104, bkW: 262, t: 64, h: 392);
  }

  void _animateTo(double target) {
    final n = widget.books.length;
    if (n == 0) return;
    _to = target.clamp(0, (n - 1).toDouble());
    _from = _pos;
    _snap
      ..reset()
      ..forward();
  }

  void _snapToNearest({double velocity = 0}) {
    final target = velocity.abs() > 260
        ? (velocity > 0 ? _pos.floorToDouble() : _pos.ceilToDouble())
        : _pos.roundToDouble();
    _animateTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final books = widget.books;
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.15),
          radius: 1.30,
          colors: [Color(0xFF1B2230), Color(0xFF12161F), Color(0xFF0B0F15)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, cons) {
          final h = cons.maxHeight;
          final w = cons.maxWidth;
          final g = _geo(w);
          final lift = (h * 0.13).clamp(70.0, 150.0);
          if (!_didCenter && books.isNotEmpty) {
            // 首次布局就居中：对应 CSS 里 .book{left:50%} + translateX(i*gap)，
            // 否则第一本会顶在屏幕正中、整排向右溢出屏幕。
            _didCenter = true;
            _pos = (books.length - 1) / 2;
          }
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) {
              _snap.stop();
              _dragStart = _pos;
            },
            onHorizontalDragUpdate: (d) {
              if (books.isEmpty) return;
              setState(() {
                _pos = (_dragStart - d.primaryDelta! / (g.gap * _cosT))
                    .clamp(-0.4, books.length - 0.6);
              });
            },
            onHorizontalDragEnd: (d) =>
                _snapToNearest(velocity: d.velocity.pixelsPerSecond.dx),
            onTapUp: (d) {
              final i = _pos.round();
              if (i >= 0 && i < books.length) {
                _snapToNearest();
                widget.onOpen(i);
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(
                  child: IgnorePointer(child: _Spotlight()),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: lift,
                  child: const _Ground(),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 98 + lift - 8,
                  height: g.h,
                  child: AnimatedSlide(
                    offset: _entered ? Offset.zero : const Offset(0, 0.075),
                    duration: const Duration(milliseconds: 950),
                    curve: const Cubic(0.22, 0.9, 0.24, 1),
                    child: AnimatedOpacity(
                      opacity: _entered ? 1 : 0,
                      duration: const Duration(milliseconds: 700),
                      child: _rig(books, g),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: lift + 44,
                  height: 56,
                  child: const IgnorePointer(child: _ShelfTop()),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: lift,
                  height: 44,
                  child: const IgnorePointer(child: _ShelfFace()),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: lift + 44,
                  height: 16,
                  child: const IgnorePointer(child: _ContactShadow()),
                ),
                const Positioned.fill(
                  child: IgnorePointer(child: _SideVignette()),
                ),
                Positioned(
                  left: 24,
                  top: 20,
                  child: IgnorePointer(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: '书架',
                          style:
                              TextStyle(color: C.text.withValues(alpha: 0.92)),
                        ),
                        TextSpan(text: ' · ${books.length} 本'),
                      ]),
                      style: T.kicker.copyWith(
                        letterSpacing: 2.4,
                        color: C.text2,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16,
                  child: IgnorePointer(
                    child: Text(
                      '左右滑动挑选 · 点中间抽出',
                      textAlign: TextAlign.center,
                      style: T.kicker.copyWith(
                        fontSize: 11,
                        letterSpacing: 1.8,
                        color: C.text3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 整排书：共用一套 3D 坐标系（透视 + 整体倾斜 + 整体平移）。
  Widget _rig(List<Item> books, _Geo g) {
    final off = (g.bkW / 2) * _sinT;
    final pull = g.out * _sinT;
    final slide = _pos * g.gap * _cosT;
    final rig = Matrix4.identity()
      ..setEntry(3, 2, -1 / 1500) // perspective: 1500px
      ..translate(off + pull - slide, 0.0, 0.0)
      ..rotateY(_tilt);

    final widgets = <Widget>[];
    for (var i = 0; i < books.length; i++) {
      final d = i - _pos;
      if (d.abs() > 3.4) continue;
      final k0 = (1 - d.abs() / 1.12).clamp(0.0, 1.0);
      final k = k0 * k0 * (3 - 2 * k0); // smoothstep
      final centered = d.abs() < 0.5;
      // 书按 i*gap 绝对排布；整体位移只由 rig 负责。
      // 绘制顺序 = i 递增：右手的书在 -26° 旋转下 z 更大（更靠近镜头），后画即遮挡左侧。
      widgets.add(Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..translate(i * g.gap, -k * 7, k * g.out),
        child: _Book(
          item: books[i],
          index: i,
          geo: g,
          centered: centered,
        ),
      ));
    }

    return Transform(
      alignment: Alignment.center,
      transform: rig,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: widgets,
      ),
    );
  }
}

/// 一本书 = 三维盒子（封面 → 书顶高光 → 书脊，后者盖前者）。
class _Book extends StatelessWidget {
  const _Book({
    required this.item,
    required this.index,
    required this.geo,
    required this.centered,
  });

  final Item item;
  final int index;
  final _Geo geo;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: geo.t,
      height: geo.h,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 封面（盒子右侧面）：先绕 Y 转 -90° 把宽度方向变成深度方向，
          // 再平移到 x=+bkT/2。经 rig 的 -26° 旋转后，这块面投影到书脊左侧。
          // OverflowBox 是必须的：Stack 给的约束宽度只有 bkT，不放开的话
          // SizedBox(bkW) 会被夹成 bkT，封面就只剩一条 40px 的窄边。
          // 封面不绕 Y 转 90°：那样投影面积恰好为 0，Skia 会直接丢掉
          // （实测像素完全不变）。这里改成「预先横向压缩好的竖条」，
          // 宽度 = bkW·tan26° ≈ 0.488·bkW，正好等于该面在 -26° 下的投影宽度；
          // 而 rig 又会整体再压一次 cos26°，所以这里除回来 *1/cos26，
          // 即 tan26/cos26。竖条左端压进书脊 10px，右端被下一本书挡住。
          Positioned(
            left: geo.t - 10,
            top: 0,
            width: geo.bkW * 0.488 / 0.899,
            height: geo.h,
            child: _CoverFace(item: item, index: index),
          ),
          // 书脊（正面）：z=+bkW/2
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.translationValues(0.0, 0.0, geo.bkW / 2),
            child: RepaintBoundary(
              child: SizedBox(
                width: geo.t,
                height: geo.h,
                child: _Spine(item: item, index: index, centered: centered),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 书脊 / 封面配色：种子数据里 c1/c2 是书脊渐变，封面用同色系。
({Color sp0, Color sp1, Color cv0, Color cv1}) bookColors(
    Item item, int index) {
  const palette = [
    (Color(0xFF2A3B58), Color(0xFF131B29)),
    (Color(0xFF1F4B41), Color(0xFF0E2A24)),
    (Color(0xFF7A4A22), Color(0xFF3D2410)),
    (Color(0xFF24402C), Color(0xFF101F16)),
    (Color(0xFF5B2540), Color(0xFF2A0F1D)),
  ];
  final p = palette[index % palette.length];
  final sp0 = _hex(item.metaStr('c1'), p.$1);
  final sp1 = _hex(item.metaStr('c2'), p.$2);
  return (
    sp0: sp0,
    sp1: sp1,
    // 封面朝向书顶的灯：比书脊明显亮一档，否则整排书会糊成一片深色板
    cv0: Color.lerp(sp0, Colors.white, 0.05)!,
    cv1: Color.lerp(sp1, Colors.black, 0.58)!,
  );
}

Color _hex(String? s, Color fallback) {
  if (s == null || s.isEmpty) return fallback;
  final n = int.tryParse(s.replaceFirst('#', ''), radix: 16);
  if (n == null) return fallback;
  return Color(0xFF000000 | n);
}

/// 书脊：竖直渐变 + 中缝 + 上下压线 + 竖排书名/作者。
class _Spine extends StatelessWidget {
  const _Spine({
    required this.item,
    required this.index,
    this.centered = false,
  });

  final Item item;
  final int index;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final c = bookColors(item, index);
    const radius = BorderRadius.only(
      topLeft: Radius.circular(2),
      topRight: Radius.circular(3),
      bottomRight: Radius.circular(3),
      bottomLeft: Radius.circular(2),
    );
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(c.sp0, Colors.black, 0.06)!,
            Color.lerp(c.sp1, Colors.black, 0.18)!,
          ],
        ),
        borderRadius: radius,
        boxShadow: [
          // inset 0 0 0 1px rgba(255,255,255,.07)
          BoxShadow(
            color:
                const Color(0xFFA7C4FF).withValues(alpha: centered ? 0.32 : 0.07),
            spreadRadius: -1,
          ),
          // inset -7px 0 14px rgba(0,0,0,.52) → 右缘暗部
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.52),
            offset: const Offset(9, 0),
            blurRadius: 14,
            spreadRadius: -4,
          ),
          // -13px 0 22px -10px rgba(0,0,0,.75) → 与左邻书之间的投影
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75),
            offset: const Offset(-13, 0),
            blurRadius: 22,
            spreadRadius: -10,
          ),
          if (centered)
            BoxShadow(
              color: const Color(0xFF7DA7FF).withValues(alpha: 0.20),
              blurRadius: 26,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // inset 0 -12px 16px rgba(0,0,0,.4)：底部压暗
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 26,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.40),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // inset 3px 0 5px rgba(255,255,255,.05)：左侧高光
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // .crease 中缝
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.34),
                      Colors.black.withValues(alpha: 0.34),
                      Colors.white.withValues(alpha: 0.04),
                    ],
                    stops: const [0, 0.2, 0.8, 1],
                  ),
                ),
              ),
            ),
            // 顶部压线
            Positioned(
              top: 9,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 18,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // 底部压线
            Positioned(
              bottom: 11,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 14,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // 竖排书名 + 作者（等效 writing-mode:vertical-rl，字符保持直立）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _VText(
                    item.title,
                    gap: 3.6, // .24em
                    maxChars: 12,
                    style: TextStyle(
                      fontFamily: T.serif,
                      fontSize: 15,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                      color: centered ? Colors.white : const Color(0xFFEDF1F7),
                    ),
                  ),
                  if ((item.creator ?? '').isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _VText(
                      item.creator!,
                      gap: 1.26, // .14em
                      maxChars: 6,
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.05,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 直立竖排文字：把字符串拆成单个字符竖向堆叠，每个字符保持直立不旋转。
class _VText extends StatelessWidget {
  const _VText(this.text,
      {required this.gap, required this.maxChars, required this.style});

  final String text;
  final double gap;
  final int maxChars;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    var chars = text.runes.map(String.fromCharCode).toList();
    if (chars.length > maxChars) {
      chars = chars.sublist(0, maxChars);
      chars.add('…');
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < chars.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          Text(chars[i], maxLines: 1, style: style),
        ],
      ],
    );
  }
}

/// 封面（盒子右侧面）：有真图用图，否则用书脊同色系渐变 + 装饰。
class _CoverFace extends StatelessWidget {
  const _CoverFace({required this.item, required this.index});

  final Item item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = bookColors(item, index);
    final hasCover = item.cover != null;
    return DecoratedBox(
      // inset 0 0 0 1px rgba(255,255,255,.1)
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.10),
            spreadRadius: -1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasCover)
              BlobImage(item.cover!, fit: BoxFit.cover)
            else
              DecoratedBox(
                // linear-gradient(150deg, cv0 0%, cv1 80%, rgba(0,0,0,.3) 100%)
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c.cv0, c.cv1, Colors.black.withValues(alpha: 0.30)],
                    stops: const [0, 0.8, 1],
                  ),
                ),
              ),
            // 越往书脊（左）越亮、越往书口（右）越暗
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0x00000000), Color(0x3D000000)],
                  stops: [0.42, 1],
                ),
              ),
            ),
            // 书顶那条亮棱（.btop 在这个视角下只能看到一条亮线）
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 7,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x73FFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
            // 上沿高光（书顶那条亮边）/ 下沿压暗
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x38FFFFFF),
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0x55000000),
                  ],
                  stops: [0, 0.06, 0.86, 1],
                ),
              ),
            ),
            if (hasCover)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x1AFFFFFF), Color(0x00000000)],
                    stops: [0, 0.12],
                  ),
                ),
              )
            else ...[
              // 顶部装饰线
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              // 中央圆形装饰
              Center(
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.20),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// .stage::before 环境光
class _Spotlight extends StatelessWidget {
  const _Spotlight();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.32),
          radius: 0.62,
          colors: [Color(0x2178A0FF), Color(0x00000000)],
          stops: [0, 0.74],
        ),
      ),
    );
  }
}

/// #s-book::before 地面
class _Ground extends StatelessWidget {
  const _Ground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0E15), Color(0xFF070A0F), Color(0xFF04070B)],
          stops: [0, 0.55, 1],
        ),
        border: Border(top: BorderSide(color: Color(0x0BFFFFFF))),
      ),
    );
  }
}

/// .shelf-top 台面顶面
class _ShelfTop extends StatelessWidget {
  const _ShelfTop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF141A24), Color(0xFF1E2836), Color(0xFF2B3A52)],
          stops: [0, 0.58, 1],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, 1.12),
                  radius: 1.3,
                  colors: [Color(0x8092AEE6), Color(0x00000000)],
                  stops: [0, 0.72],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x47FFFFFF), Color(0x0DFFFFFF)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// .shelf-face 台面前沿
class _ShelfFace extends StatelessWidget {
  const _ShelfFace();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E151F), Color(0xFF070B11)],
        ),
        border: Border(top: BorderSide(color: Color(0x29FFFFFF))),
        boxShadow: [
          BoxShadow(
            color: Color(0x99000000),
            offset: Offset(0, -14),
            blurRadius: 34,
            spreadRadius: -6,
          ),
        ],
      ),
      child: CustomPaint(painter: _StripePainter()),
    );
  }
}

/// repeating-linear-gradient(90deg, rgba(255,255,255,.015) 0 2px, transparent 2px 6px)
class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x04FFFFFF);
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 2, size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// .shadows 书底接触阴影
class _ContactShadow extends StatelessWidget {
  const _ContactShadow();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xB8000000), Color(0x47000000), Color(0x00000000)],
          stops: [0, 0.58, 1],
        ),
      ),
    );
  }
}

/// #s-book::after 左右压暗
class _SideVignette extends StatelessWidget {
  const _SideVignette();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xEB0F141C),
            Color(0x000F141C),
            Color(0x000F141C),
            Color(0xEB0F141C),
          ],
          stops: [0, 0.16, 0.84, 1],
        ),
      ),
    );
  }
}

/// stageMetrics() + --bkT/--bkH
class _Geo {
  const _Geo({
    required this.gap,
    required this.out,
    required this.bkW,
    required this.t,
    required this.h,
  });

  final double gap;
  final double out;
  final double bkW;
  final double t;
  final double h;
}
