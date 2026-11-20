/// 书架：3D 实心书架。
///
/// 几何与配色逐条照抄旧版 CSS（收藏库-方案一-B-侧边栏.html）：
///   #s-book     radial-gradient(130% 90% at 50% -10%, #1B2230, #12161F 55%, #0B0F15)
///   --lift      clamp(70px, 13vh, 150px)
///   .rig        bottom: calc(98px + var(--lift)); 整体 rotateY(-26deg)
///   .book       --bkT 44 / --bkH 288 / --bkW 198，相邻 gap 62，bottom:-8px
///   .shelf-top  bottom: lift+44, height:56
///   .shelf-face bottom: lift, height:44
///   .stage      perspective:1500px
/// 每本书是一个三维盒子：书脊在 z=+bkW/2，封面在 x=+bkT/2。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/model.dart';
import '../../data/app_state.dart';
import '../form/item_form.dart';
import '../kit.dart';
import '../theme.dart';
import 'book_detail.dart';

class BookPage extends StatefulWidget {
  const BookPage({super.key});

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage>
    with SingleTickerProviderStateMixin {
  // ---- 旧版 stageMetrics() 窄屏档 ----
  static const double bkT = 44;
  static const double bkH = 288;
  static const double bkW = 198;
  static const double gap = 78;
  static const double out = 86;
  static const double _tilt = -26 * math.pi / 180;
  static const double _sinT = 0.4383711467890774; // sin 26°
  static const double _cosT = 0.898794046299167; // cos 26°

  late final AnimationController _snap = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520));
  double _pos = 0;
  double _from = 0;
  double _to = 0;
  double _dragStart = 0;
  int _pullIndex = -1;
  bool _entered = false;
  bool _centered = false;

  @override
  void initState() {
    super.initState();
    _snap.addListener(() {
      final t = Curves.easeOutCubic.transform(_snap.value);
      setState(() => _pos = _from + (_to - _from) * t);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _entered = true);
    });
  }

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    final n = App.I.of(ST.book).length;
    if (n == 0) return;
    _to = target.clamp(0, (n - 1).toDouble());
    _from = _pos;
    _snap
      ..reset()
      ..forward();
  }

  void _onDragStart(DragStartDetails d) {
    _snap.stop();
    _dragStart = _pos;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final n = App.I.of(ST.book).length;
    if (n == 0) return;
    setState(() => _pos =
        (_dragStart - d.primaryDelta! / (gap * _cosT)).clamp(-0.4, n - 0.6));
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dx;
    final target = v.abs() > 260
        ? (v > 0 ? _pos.floorToDouble() : _pos.ceilToDouble())
        : _pos.roundToDouble();
    _animateTo(target);
  }

  Future<void> _open(int i) async {
    final books = App.I.of(ST.book);
    if (i < 0 || i >= books.length) return;
    setState(() => _pullIndex = i);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _pullIndex = -1);
    final changed = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, a, __) =>
            FadeTransition(opacity: a, child: BookDetailPage(item: books[i])),
      ),
    );
    if (changed == true && mounted) {
      final n = App.I.of(ST.book).length;
      if (_pos > n - 1) setState(() => _pos = math.max(0, n - 1).toDouble());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.I,
      builder: (context, _) {
        final books = App.I.of(ST.book);
        if (!_centered && books.isNotEmpty) {
          _centered = true;
          _pos = (books.length - 1) / 2;
        }
        return Container(
          decoration: const BoxDecoration(
            // #s-book 背景
            gradient: RadialGradient(
              center: Alignment(0, -1.15),
              radius: 1.30,
              colors: [Color(0xFF1B2230), Color(0xFF12161F), Color(0xFF0B0F15)],
              stops: [0, 0.55, 1],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, cons) {
              if (books.isEmpty) return _empty();
              final h = cons.maxHeight;
              final lift = (h * 0.13).clamp(70.0, 150.0);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _onDragStart,
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                onTapUp: (_) {
                  final i = _pos.round();
                  final list = App.I.of(ST.book);
                  if (i >= 0 && i < list.length) _open(i);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // .stage::before 环境光
                    const Positioned.fill(
                      child: IgnorePointer(child: _Spotlight()),
                    ),
                    // 地面（--lift 那一段）
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: lift,
                      child: const _Ground(),
                    ),
                    // 书列（含入场上浮）
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 98 + lift - 8,
                      height: bkH,
                      child: AnimatedBuilder(
                        animation: _snap,
                        builder: (context, child) => AnimatedSlide(
                          offset: _entered ? Offset.zero : const Offset(0, 0.075),
                          duration: const Duration(milliseconds: 950),
                          curve: const Cubic(0.22, 0.9, 0.24, 1),
                          child: AnimatedOpacity(
                            opacity: _entered ? 1 : 0,
                            duration: const Duration(milliseconds: 700),
                            child: child,
                          ),
                        ),
                        child: _rigLayer(books, lift),
                      ),
                    ),
                    // 台面顶面（书坐在这上面）
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: lift + 44,
                      height: 56,
                      child: const IgnorePointer(child: _ShelfTop()),
                    ),
                    // 台面前沿
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: lift,
                      height: 44,
                      child: const IgnorePointer(child: _ShelfFace()),
                    ),
                    // 书底的接触阴影
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: lift + 44,
                      height: 16,
                      child: const IgnorePointer(child: _ContactShadow()),
                    ),
                    // 左右压暗（#s-book::after）
                    const Positioned.fill(
                      child: IgnorePointer(child: _SideVignette()),
                    ),
                    // 顶栏字样
                    Positioned(
                      left: 24,
                      top: 20,
                      child: IgnorePointer(
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: '书架',
                              style: TextStyle(color: C.text.withValues(alpha: 0.92)),
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
                    // 底部提示
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
      },
    );
  }

  /// 整排书：共用一套 3D 坐标系（整体平移 + 整体倾斜）。
  Widget _rigLayer(List<Item> books, double lift) {
    final off = (bkW / 2) * _sinT;
    final pull = out * _sinT;
    final slide = _pos * gap * _cosT;
    final rig = Matrix4.identity()
      ..setEntry(3, 2, -1 / 1500) // perspective:1500px
      ..translate(off + pull - slide, 0.0, 0.0)
      ..rotateY(_tilt);

    final spines = <Widget>[];
    final covers = <Widget>[];
    for (var i = 0; i < books.length; i++) {
      final d = i - _pos;
      if (d.abs() > 3.4) continue;
      final k0 = (1 - d.abs() / 1.12).clamp(0.0, 1.0);
      var k = k0 * k0 * (3 - 2 * k0);
      if (_pullIndex == i) k = 1.12;
      final base = Matrix4.identity()
        // 书在局部 x 轴上按 i*gap 一本挨一本排（整体位移由 rig 负责）
        ..translate(i * gap, -k * 7, k * out);
      // 书脊全部先画，封面后画：Flutter 按 widget 顺序绘制，
      // 否则后一本的书脊会盖掉前一本的封面（CSS 里由 preserve-3d 的深度排序处理）。
      spines.add(Transform(
        alignment: Alignment.center,
        transform: Matrix4.copy(base)..translate(0.0, 0.0, bkW / 2),
        child: SizedBox(
          width: bkT,
          height: bkH,
          child: _Spine(item: books[i], index: i, centered: d.abs() < 0.5),
        ),
      ));
      covers.add(Transform(
        alignment: Alignment.center,
        transform: Matrix4.copy(base)
          ..rotateY(math.pi / 2)
          ..translate(0.0, 0.0, bkT / 2),
        child: SizedBox(
          width: bkW,
          height: bkH,
          child: _CoverFace(item: books[i], index: i),
        ),
      ));
    }

    return Transform(
      alignment: Alignment.center,
      transform: rig,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [...covers, ...spines],
      ),
    );
  }

  /// 一本书 = 书脊（正面）+ 封面（右侧面）。
  Widget _bookBox(Item item, int i, {bool centered = false}) {
    return SizedBox(
      width: bkT,
      height: bkH,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.translationValues(0.0, 0.0, bkW / 2),
            child: SizedBox(
              width: bkT,
              height: bkH,
              child: _Spine(item: item, index: i, centered: centered),
            ),
          ),
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..rotateY(math.pi / 2)
              ..translate(0.0, 0.0, bkT / 2),
            child: SizedBox(
              width: bkW,
              height: bkH,
              child: _CoverFace(item: item, index: i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_stories_outlined, size: 40, color: C.text3),
            const SizedBox(height: 14),
            const Text('书架还空着', style: T.bodyDim),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ItemForm.show(context, type: ST.book),
              style: FilledButton.styleFrom(
                backgroundColor: C.accent.withValues(alpha: 0.18),
                foregroundColor: C.accent2,
              ),
              child: const Text('放第一本书上去'),
            ),
          ],
        ),
      );
}

/// 书脊 / 封面配色：种子数据里 c1/c2 是书脊渐变，封面用同色系提亮。
({Color sp0, Color sp1, Color cv0, Color cv1}) bookColors(Item item, int index) {
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
    cv0: Color.lerp(sp0, Colors.white, 0.10)!,
    cv1: Color.lerp(sp1, Colors.black, 0.10)!,
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
  const _Spine({required this.item, required this.index, this.centered = false});

  final Item item;
  final int index;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final c = bookColors(item, index);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.sp0, c.sp1],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(2),
          topRight: Radius.circular(3),
          bottomRight: Radius.circular(3),
          bottomLeft: Radius.circular(2),
        ),
        boxShadow: [
          // inset 0 0 0 1px rgba(255,255,255,.07)
          BoxShadow(
            color: const Color(0xFFA7C4FF).withValues(alpha: centered ? 0.32 : 0.07),
            spreadRadius: -1,
          ),
          // inset -7px 0 14px rgba(0,0,0,.52) → 右缘暗部
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.52),
            offset: const Offset(9, 0),
            blurRadius: 14,
            spreadRadius: -4,
          ),
          // -13px 0 22px -10px rgba(0,0,0,.75)
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
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(2),
          topRight: Radius.circular(3),
          bottomRight: Radius.circular(3),
          bottomLeft: Radius.circular(2),
        ),
        child: Stack(
          children: [
            // 底部内阴影 inset 0 -12px 16px rgba(0,0,0,.4)
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
            // 右侧反光 inset 3px 0 5px rgba(255,255,255,.05)
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
            // 中缝 .crease
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
            // 竖排书名 + 作者
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: RotatedBox(
                      quarterTurns: 1,
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: T.serif,
                          fontSize: 15,
                          height: 1.05,
                          letterSpacing: 3.6, // .24em
                          fontWeight: FontWeight.w600,
                          color: centered
                              ? Colors.white
                              : const Color(0xFFEDF1F7),
                          shadows: const [
                            Shadow(
                                color: Color(0x73000000),
                                blurRadius: 5,
                                offset: Offset(0, 1)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if ((item.creator ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    RotatedBox(
                      quarterTurns: 1,
                      child: Text(
                        item.creator!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          height: 1.05,
                          letterSpacing: 1.26, // .14em
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
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

/// 封面（盒子右侧面）：有图用图，没图用配色渐变 + 书名。
class _CoverFace extends StatelessWidget {
  const _CoverFace({required this.item, required this.index});

  final Item item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = bookColors(item, index);
    final hasCover = item.cover != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: hasCover
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.cv0, c.cv1, Colors.black.withValues(alpha: 0.30)],
                stops: const [0, 0.8, 1],
              ),
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
            else ...[
              // inset 0 0 70px rgba(0,0,0,.34) 四边压暗
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.95,
                    colors: [Color(0x00000000), Color(0x57000000)],
                    stops: [0.55, 1],
                  ),
                ),
              ),
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
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.20)),
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
          center: Alignment(0, -0.32), // 50% 34%
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
          colors: [Color(0xFF18202E), Color(0xFF2C3954), Color(0xFF435377)],
          stops: [0, 0.58, 1],
        ),
        boxShadow: [
          BoxShadow(color: Color(0x24000000), offset: Offset(0, 14), blurRadius: 22),
        ],
      ),
      child: Stack(
        children: [
          // radial-gradient(58% 230% at 50% 106%, rgba(146,174,230,.5), transparent 72%)
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
          // 顶面后缘棱线
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
