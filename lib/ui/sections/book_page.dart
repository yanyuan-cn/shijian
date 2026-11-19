/// 书架：3D 弧形书架。
///
/// 视觉照搬旧版：书脊立在一个深色台面上，按到中心的距离绕 Y 轴旋转，
/// 拖拽跟手、松手吸附到最近一本；点最中间那本「抽出来」。
///
/// 性能注意：所有书脊只依赖一个连续的 _pos，拖动时只重建 Transform，
/// 不做重新布局；离开这个 tab 时 TickerMode 会把动画停掉。
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
  late final AnimationController _snap = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 460));
  double _pos = 0;
  double _from = 0;
  double _to = 0;
  double _dragStart = 0;
  bool _dragging = false;
  int _pullIndex = -1;
  bool _entered = false;

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
    _dragging = true;
    _dragStart = _pos;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final width = MediaQuery.of(context).size.width;
    final gap = math.max(78.0, width / 4.05);
    setState(() => _pos = (_dragStart - d.primaryDelta! / gap)
        .clamp(-0.6, App.I.of(ST.book).length - 0.4));
  }

  void _onDragEnd(DragEndDetails d) {
    _dragging = false;
    final v = d.velocity.pixelsPerSecond.dx;
    var target = _pos;
    if (v.abs() > 260) {
      target = v > 0 ? _pos.floorToDouble() : _pos.ceilToDouble();
    } else {
      target = _pos.roundToDouble();
    }
    _animateTo(target);
  }

  Future<void> _open(int i) async {
    final books = App.I.of(ST.book);
    if (i < 0 || i >= books.length) return;
    setState(() => _pullIndex = i);
    await Future<void>.delayed(const Duration(milliseconds: 170));
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
        return Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -1.05),
              radius: 1.1,
              colors: [Color(0xFF1B2230), Color(0xFF12161F), Color(0xFF0B0F15)],
              stops: [0, 0.55, 1],
            ),
          ),
          child: Stack(
            children: [
              if (books.isEmpty)
                _empty()
              else ...[
                Positioned(
                  left: 22,
                  top: 16,
                  child: Text('书架 · ${books.length} 本', style: T.kicker),
                ),
                Center(
                  child: AnimatedOpacity(
                    opacity: _entered ? 1 : 0,
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    child: AnimatedSlide(
                      offset: _entered ? Offset.zero : const Offset(0, 0.16),
                      duration: const Duration(milliseconds: 950),
                      curve: Curves.easeOutCubic,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: _onDragStart,
                        onHorizontalDragUpdate: _onDragUpdate,
                        onHorizontalDragEnd: _onDragEnd,
                        onTapUp: (d) {
                          final i = _pos.round();
                          final books = App.I.of(ST.book);
                          if (i >= 0 && i < books.length) _open(i);
                        },
                        child: SizedBox(
                          height: 420,
                          width: double.infinity,
                          child: AnimatedBuilder(
                            animation: _snap,
                            builder: (context, _) => _shelf(books),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (books.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 18,
                    child: Center(
                      child: Text('左右滑动挑选 · 点中间抽出', style: T.kicker),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _shelf(List<Item> books) {
    final w = MediaQuery.of(context).size.width;
    final gap = math.max(78.0, w / 4.05);
    const spineW = 46.0;
    const spineH = 296.0;

    final children = <Widget>[];
    for (var i = 0; i < books.length; i++) {
      final d = i - _pos;
      if (d.abs() > 3.4) continue;
      final angle = (-d * 0.52).clamp(-1.15, 1.15);
      final dx = d * gap;
      final dz = -d.abs() * 26.0;
      final pulled = _pullIndex == i;
      final m = Matrix4.identity()
        ..setEntry(3, 2, 0.0011)
        ..translate(dx, pulled ? -14 : 0, pulled ? 70 : dz)
        ..rotateY(angle);
      final opacity =
          (1 - ((d.abs() - 2.0).clamp(0.0, 1.0)) * 0.55).clamp(0.0, 1.0);
      children.add(Positioned(
        left: w / 2 - spineW / 2,
        top: 64,
        child: Transform(
          alignment: Alignment.center,
          transform: m,
          child: Opacity(
            opacity: opacity,
            child: _Spine(
              item: books[i],
              index: i,
              width: spineW,
              height: spineH,
            ),
          ),
        ),
      ));
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 台面
        Positioned(
          left: -20,
          right: -20,
          top: 64 + 296 - 6,
          height: 110,
          child: const _ShelfTop(),
        ),
        ...children,
        // 地平线光
        Positioned(
          left: -20,
          right: -20,
          top: 64 + 296 - 8,
          height: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.14),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ],
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

class _ShelfTop extends StatelessWidget {
  const _ShelfTop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2C3954), Color(0xFF18202E), Color(0xFF0D1219)],
          stops: [0, 0.35, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: CustomPaint(painter: _GrainPainter()),
    );
  }
}

/// 台面的木纹 / 石纹暗纹：几十条极淡的横线，成本几乎为零。
class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..strokeWidth = 1;
    for (var i = 0; i < 26; i++) {
      final y = size.height * (i / 26.0) + 2;
      p.color = Colors.white.withValues(alpha: 0.012 + (i % 3) * 0.006);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Spine extends StatelessWidget {
  const _Spine({
    required this.item,
    required this.index,
    required this.width,
    required this.height,
  });

  final Item item;
  final int index;
  final double width;
  final double height;

  static const _palette = [
    (Color(0xFF2A3B58), Color(0xFF131B29)),
    (Color(0xFF1F4B41), Color(0xFF0E2A24)),
    (Color(0xFF7A4A22), Color(0xFF3D2410)),
    (Color(0xFF24402C), Color(0xFF101F16)),
    (Color(0xFF5B2540), Color(0xFF2A0F1D)),
  ];

  @override
  Widget build(BuildContext context) {
    final c1 = _color(item.metaStr('c1'), _palette[index % _palette.length].$1);
    final c2 = _color(item.metaStr('c2'), _palette[index % _palette.length].$2);
    return SizedBox(
      width: width + 6,
      height: height,
      child: Stack(
        children: [
          // 书脊正面
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [c1, Color.lerp(c1, c2, 0.45)!, c2],
                stops: const [0, 0.55, 1],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(2),
                topRight: Radius.circular(2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Stack(
              children: [
                // 顶部两道烫印线
                Positioned(
                  top: 14,
                  left: 10,
                  right: 10,
                  child: Column(
                    children: [
                      Container(height: 1.4, color: Colors.white.withValues(alpha: 0.22)),
                      const SizedBox(height: 4),
                      Container(height: 1, color: Colors.white.withValues(alpha: 0.14)),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 18,
                  left: 10,
                  right: 10,
                  child: Container(
                      height: 1, color: Colors.black.withValues(alpha: 0.35)),
                ),
                // 竖排书名 + 作者
                Positioned.fill(
                  top: 34,
                  bottom: 28,
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
                            style: const TextStyle(
                              fontFamily: T.serif,
                              fontSize: 19,
                              height: 1.05,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFF2F5FA),
                              shadows: [
                                Shadow(
                                    color: Color(0x66000000),
                                    blurRadius: 3,
                                    offset: Offset(0, 1)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (item.creator != null) ...[
                        const SizedBox(height: 10),
                        RotatedBox(
                          quarterTurns: 1,
                          child: Text(
                            item.creator!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.05,
                              color: Colors.white.withValues(alpha: 0.62),
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
          // 右侧书页的厚度感
          Positioned(
            left: width - 1,
            top: 2,
            bottom: 2,
            width: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.lerp(c2, Colors.white, 0.18)!,
                    Color.lerp(c2, Colors.black, 0.35)!,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(2),
                  bottomRight: Radius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _color(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final v = hex.replaceFirst('#', '');
    final n = int.tryParse(v, radix: 16);
    if (n == null) return fallback;
    return Color(0xFF000000 | n);
  }
}
