/// 阅读器：进度、字体、翻页方式、深浅色 —— 就这四件。
///
/// 进度存 locator（字符偏移），不存页码：换字号就重排，页码一定错位。
/// 排版交给 `EbookDoc.blocks`：标题、正文段、图注、引用各有样式，
/// 仿真翻页用「页面向左立起来」的 3D 变换 + 阴影，比左右滑动更像翻书。
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/model.dart';
import '../../data/app_state.dart';
import '../../data/ebook.dart';
import '../../data/settings.dart';
import '../theme.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.item, required this.asset});

  final Item item;
  final Asset asset;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  EbookDoc? _doc;
  String? _err;
  List<int> _starts = const [];
  int _page = 0;
  double _fontSize = Settings.readerFontSize;
  String _theme = Settings.readerTheme;
  String _turn = Settings.readerTurn;
  bool _menu = false;
  bool _measured = false;
  Size _lastSize = Size.zero;
  Timer? _saveTimer;
  int _restoreLoc = -1;

  bool _sizeDiff(Size s) =>
      (_lastSize.width - s.width).abs() > 1 ||
      (_lastSize.height - s.height).abs() > 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _flushProgress();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final f = App.I.blobs.fileOf(widget.asset.hash);
      if (!await f.exists()) {
        setState(() => _err = '原文件丢了（可能被系统清理）');
        return;
      }
      final bytes = Uint8List.fromList(await f.readAsBytes());
      final doc = await parseEbook(bytes, name: widget.asset.name ?? '');
      if (!mounted) return;
      _restoreLoc = widget.item.metaInt('loc', -1);
      setState(() {
        _doc = doc;
        if (doc.text.trim().isEmpty) _err = '这本书里没有正文';
      });
    } catch (e) {
      if (mounted) setState(() => _err = '打不开：$e');
    }
  }

  // ─────────────────── 排版 ───────────────────

  TextStyle get _base => TextStyle(
        fontFamily: T.serif,
        fontSize: _fontSize,
        height: 1.75,
        color: _fg,
        letterSpacing: 0.2,
      );

  (Color bg, Color fg) get _colors => switch (_theme) {
        'light' => (const Color(0xFFFAFAF7), const Color(0xFF23262B)),
        'dark' => (const Color(0xFF0F1318), const Color(0xFFC4CDDA)),
        _ => (const Color(0xFFF2EADA), const Color(0xFF3B3226)),
      };

  Color get _bg => _colors.$1;
  Color get _fg => _colors.$2;

  TextStyle _styleFor(BlockKind k, int level) {
    switch (k) {
      case BlockKind.heading:
        return _base.copyWith(
          fontSize: _fontSize * (level >= 2 ? 1.12 : 1.3),
          fontWeight: level >= 2 ? FontWeight.w600 : FontWeight.w700,
          height: 1.55,
          letterSpacing: 0.6,
        );
      case BlockKind.caption:
        return _base.copyWith(
          fontSize: _fontSize * 0.8,
          height: 1.6,
          color: _fg.withValues(alpha: 0.55),
          letterSpacing: 0.1,
        );
      case BlockKind.quote:
        return _base.copyWith(
          fontSize: _fontSize * 0.96,
          height: 1.7,
          color: _fg.withValues(alpha: 0.86),
        );
      case BlockKind.para:
        return _base;
    }
  }

  /// 只取 [s, e) 这一段，按块切给不同样式。
  TextSpan _spanFor(int s, int e) {
    final doc = _doc;
    if (doc == null) return const TextSpan(text: '');
    final children = <TextSpan>[];
    for (final b in doc.blocks) {
      if (b.end <= s) continue;
      if (b.offset >= e) break;
      final from = b.offset < s ? s : b.offset;
      final to = b.end > e ? e : b.end;
      if (to <= from) continue;
      children.add(TextSpan(
        text: doc.text.substring(from, to),
        style: _styleFor(b.kind, b.level),
      ));
    }
    if (children.isEmpty) {
      return TextSpan(text: doc.text.substring(s, e), style: _base);
    }
    return TextSpan(children: children);
  }

  TextSpan _fullSpan() {
    final doc = _doc;
    if (doc == null) return const TextSpan(text: '');
    return TextSpan(children: [
      for (final b in doc.blocks)
        TextSpan(
          text: doc.text.substring(b.offset, b.end),
          style: _styleFor(b.kind, b.level),
        ),
    ]);
  }

  void _paginate(Size size) {
    final doc = _doc;
    final text = doc?.text ?? '';
    if (text.isEmpty) return;
    final tp = TextPainter(
      text: _fullSpan(),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: size.width);
    final lines = tp.computeLineMetrics();
    final starts = <int>[0];
    var acc = 0.0;
    for (final l in lines) {
      if (acc + l.height > size.height && acc > 0) {
        final y = l.baseline - l.ascent + 1;
        final off = tp.getPositionForOffset(Offset(0, y)).offset;
        if (off > starts.last) starts.add(off);
        acc = 0;
      }
      acc += l.height;
    }
    tp.dispose();
    starts.add(text.length);
    _starts = starts;

    var p = 0;
    if (_restoreLoc > 0) {
      for (var i = 0; i < starts.length - 1; i++) {
        if (starts[i] <= _restoreLoc) {
          p = i;
        } else {
          break;
        }
      }
      _restoreLoc = -1;
    } else if (_page > 0) {
      p = _page.clamp(0, starts.length - 2);
    }
    _page = p;
    _measured = true;
    _lastSize = size;
  }

  void _onPageChanged(int i) {
    setState(() => _page = i);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _flushProgress);
  }

  void _flushProgress() {
    final doc = _doc;
    if (doc == null || _starts.isEmpty) return;
    final i = _page.clamp(0, _starts.length - 2);
    final loc = _starts[i];
    final pct = doc.text.isEmpty
        ? 0
        : ((loc / doc.text.length) * 100).round().clamp(0, 100);
    final it = App.I.byId(widget.item.id);
    if (it == null) return;
    if (it.metaInt('prog') == pct && it.metaInt('loc', -1) == loc) return;
    final next = it.withMeta({'prog': pct, 'loc': loc}).copyWith(
        updatedAt: DateTime.now().millisecondsSinceEpoch, rev: it.rev + 1);
    App.I.repo.upsert(next).then((_) => App.I.reload());
  }

  void _setFont(double v) {
    Settings.readerFontSize = v;
    setState(() {
      _fontSize = v;
      _measured = false;
    });
  }

  void _setTheme(String t) {
    Settings.readerTheme = t;
    setState(() => _theme = t);
  }

  void _setTurn(String t) {
    final loc = _starts.isEmpty ? 0 : _starts[_page.clamp(0, _starts.length - 2)];
    Settings.readerTurn = t;
    setState(() {
      _turn = t;
      _measured = false;
      _restoreLoc = loc;
    });
  }

  void _jumpTo(int loc) {
    final starts = _starts;
    if (starts.isEmpty) return;
    var p = 0;
    for (var i = 0; i < starts.length - 1; i++) {
      if (starts[i] <= loc) {
        p = i;
      } else {
        break;
      }
    }
    setState(() {
      _page = p;
      _measured = false;
      _restoreLoc = loc;
    });
  }

  // ─────────────────── 界面 ───────────────────

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            if (_err != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(_err!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _fg.withValues(alpha: 0.7))),
                ),
              )
            else if (doc == null)
              const Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2)))
            else
              LayoutBuilder(builder: (context, c) {
                final size = Size(c.maxWidth - 44, c.maxHeight - 44);
                if (!_measured || _sizeDiff(size)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    if (!_measured || _sizeDiff(size)) {
                      setState(() => _paginate(size));
                    }
                  });
                }
                if (_starts.length < 2) {
                  return const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)));
                }
                final count = _starts.length - 1;
                if (_turn == 'scroll') {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _menu = !_menu),
                    child: PageView.builder(
                      controller: PageController(initialPage: _page),
                      scrollDirection: Axis.vertical,
                      itemCount: count,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (_, i) => _pageBody(i),
                    ),
                  );
                }
                return _FlipView(
                  key: ValueKey('flip-$count-${_fontSize.toStringAsFixed(0)}'),
                  count: count,
                  index: _page,
                  builder: _pageBody,
                  background: _bg,
                  onChanged: _onPageChanged,
                  onTapCenter: () => setState(() => _menu = !_menu),
                );
              }),
            if (_menu) _menuOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _pageBody(int i) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        child: ClipRect(
          child: Align(
            alignment: Alignment.topLeft,
            child: Text.rich(
              _spanFor(_starts[i], _starts[i + 1]),
              textAlign: TextAlign.justify,
            ),
          ),
        ),
      );

  Widget _menuOverlay() {
    final doc = _doc;
    final pct = doc == null
        ? 0
        : ((_starts.isEmpty ? 0 : _starts[_page.clamp(0, _starts.length - 2)]) /
                (doc.text.isEmpty ? 1 : doc.text.length) *
                100)
            .round();
    final hasToc = (doc?.chapters.length ?? 0) > 1;
    return Positioned.fill(
      child: Column(
        children: [
          Container(
            color: _bg,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back, color: _fg, size: 21),
                ),
                Expanded(
                  child: Text(
                    widget.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 13, color: _fg.withValues(alpha: 0.7)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text('$pct%',
                      style: TextStyle(
                          fontSize: 12, color: _fg.withValues(alpha: 0.5))),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            color: _bg,
            padding: EdgeInsets.fromLTRB(
                16, 8, 10, 8 + MediaQuery.of(context).padding.bottom),
            child: Row(
              children: [
                Text('字号',
                    style: TextStyle(
                        fontSize: 12, color: _fg.withValues(alpha: 0.55))),
                IconButton(
                  onPressed: _fontSize > 13 ? () => _setFont(_fontSize - 1) : null,
                  icon: Icon(Icons.text_decrease, color: _fg, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
                Text('${_fontSize.toInt()}',
                    style: TextStyle(fontSize: 13, color: _fg)),
                IconButton(
                  onPressed: _fontSize < 30 ? () => _setFont(_fontSize + 1) : null,
                  icon: Icon(Icons.text_increase, color: _fg, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                _themeDot('sepia', const Color(0xFFF2EADA)),
                _themeDot('light', const Color(0xFFFAFAF7)),
                _themeDot('dark', const Color(0xFF0F1318)),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () => _setTurn(_turn == 'page' ? 'scroll' : 'page'),
                  style: TextButton.styleFrom(
                      foregroundColor: _fg.withValues(alpha: 0.7),
                      padding: const EdgeInsets.symmetric(horizontal: 6)),
                  child: Text(_turn == 'page' ? '仿真翻页' : '上下翻页',
                      style: const TextStyle(fontSize: 11.5)),
                ),
                if (hasToc)
                  TextButton.icon(
                    onPressed: _showToc,
                    style: TextButton.styleFrom(
                        foregroundColor: _fg.withValues(alpha: 0.7),
                        padding: const EdgeInsets.symmetric(horizontal: 6)),
                    icon: Icon(Icons.list,
                        size: 16, color: _fg.withValues(alpha: 0.75)),
                    label: Text('目录', style: const TextStyle(fontSize: 11.5)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeDot(String key, Color c) => GestureDetector(
        onTap: () => _setTheme(key),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 21,
          height: 21,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(
              color: _theme == key ? C.accent : _fg.withValues(alpha: 0.25),
              width: _theme == key ? 2 : 1,
            ),
          ),
        ),
      );

  void _showToc() {
    final doc = _doc;
    if (doc == null) return;
    final cur = _starts.isEmpty ? 0 : _starts[_page.clamp(0, _starts.length - 2)];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.panel,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 12, 6),
                child: Row(
                  children: [
                    const Text('目录',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: C.text)),
                    const Spacer(),
                    Text('共 ${doc.chapters.length} 节',
                        style: const TextStyle(fontSize: 11.5, color: C.text3)),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, size: 18, color: C.text3),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0x14FFFFFF)),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: doc.chapters.length,
                  itemBuilder: (_, i) {
                    final ch = doc.chapters[i];
                    final on = cur >= ch.offset &&
                        (i == doc.chapters.length - 1 ||
                            cur < doc.chapters[i + 1].offset);
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      onTap: () {
                        Navigator.pop(ctx);
                        _jumpTo(ch.offset);
                      },
                      title: Text(
                        ch.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          color: on ? C.accent2 : C.text2,
                          fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 仿真翻页：当前页绕左边缘立起来，露出下一页，回来时反向。
///
/// 手感参数：拖动位移 / 宽 = 进度；超过 18% 或甩得够快就翻页。
class _FlipView extends StatefulWidget {
  const _FlipView({
    super.key,
    required this.count,
    required this.index,
    required this.builder,
    required this.background,
    required this.onChanged,
    required this.onTapCenter,
  });

  final int count;
  final int index;
  final Widget Function(int) builder;
  final Color background;
  final ValueChanged<int> onChanged;
  final VoidCallback onTapCenter;

  @override
  State<_FlipView> createState() => _FlipViewState();
}

class _FlipViewState extends State<_FlipView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320));
  double _t = 0; // 0 = 静止，1 = 完全翻过去
  bool _forward = true;
  double _dragStart = 0;
  bool _dragging = false;
  double _width = 1;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _settle(bool commit) {
    final target = commit ? 1.0 : 0.0;
    final from = _t;
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (260 * (1 - (from - target).abs())).round()),
    );
    final curved = CurvedAnimation(
        parent: controller, curve: Curves.easeOutCubic);
    void tick() {
      _t = from + (target - from) * curved.value;
      if (mounted) setState(() {});
    }

    controller.addListener(tick);
    controller.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        controller.dispose();
        if (mounted) {
          setState(() {
            _t = 0;
            if (commit) {
              widget.onChanged(
                  _forward ? widget.index + 1 : widget.index - 1);
            }
          });
        }
      }
    });
    controller.forward();
  }

  void _onDown(DragStartDetails d) {
    if (_t != 0) return;
    _dragging = true;
    _dragStart = d.localPosition.dx;
    _forward = true;
  }

  void _onUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    final dx = d.localPosition.dx - _dragStart;
    if (dx < 0) {
      // 向左拖 = 往后翻
      _forward = true;
      _t = (-dx / _width).clamp(0.0, 1.0);
    } else if (widget.index > 0) {
      // 向右拖 = 往前翻（当前页从右边折回来）
      _forward = false;
      _t = (dx / _width).clamp(0.0, 1.0);
    }
    setState(() {});
  }

  void _onUp(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    final v = d.velocity.pixelsPerSecond.dx;
    final fast = _forward ? v < -320 : v > 320;
    if (_t > 0.18 || fast) {
      if (_forward && widget.index >= widget.count - 1) {
        _settle(false);
      } else {
        _settle(true);
      }
    } else {
      _settle(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.index;
    final hasNext = i < widget.count - 1;
    return LayoutBuilder(builder: (ctx, c) {
      _width = c.maxWidth;
      final bg = widget.background;
      // 每页都要有不透明底色：页面是叠着画的，透过去就会看到下面那页的字。
      Widget opaque(Widget w) => ColoredBox(color: bg, child: w);
      final top = opaque(widget.builder(i));
      final under = opaque(hasNext ? widget.builder(i + 1) : top);
      final prev = opaque(i > 0 ? widget.builder(i - 1) : top);

      // 前翻：上一页从右边盖回来，当前页在下面
      if (!_forward) {
        final angle = -_t * math.pi / 2.2;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onDown,
          onHorizontalDragUpdate: _onUpdate,
          onHorizontalDragEnd: _onUp,
          onTapUp: (d) => _tapZone(d.localPosition.dx, c.maxWidth),
          child: Stack(children: [
            Positioned.fill(child: top),
            Positioned.fill(
              child: Transform(
                alignment: Alignment.centerRight,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0014)
                  ..translateByDouble(-_t * c.maxWidth * 0.5, 0, 0, 1)
                  ..rotateY(angle),
                child: Stack(children: [
                  Positioned.fill(child: prev),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.22 * _t),
                              Colors.black.withValues(alpha: 0.02 * _t),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        );
      }

      final angle = _t * math.pi / 2.2;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _onDown,
        onHorizontalDragUpdate: _onUpdate,
        onHorizontalDragEnd: _onUp,
        onTapUp: (d) => _tapZone(d.localPosition.dx, c.maxWidth),
        child: Stack(children: [
          Positioned.fill(child: under),
          Positioned.fill(
            child: Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0014)
                ..rotateY(-angle),
              child: Stack(children: [
                Positioned.fill(child: top),
                // 翻起来的那一面会变暗一点，像纸张背光
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.30 * _t),
                            Colors.black.withValues(alpha: 0.02 * _t),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // 折痕高光
                if (_t > 0.02)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16 * _t),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ]),
      );
    });
  }

  void _tapZone(double x, double w) {
    if (x < w * 0.28 && widget.index > 0) {
      _forward = false;
      _t = 0.001;
      setState(() {});
      _settle(true);
      return;
    }
    if (x > w * 0.72 && widget.index < widget.count - 1) {
      _forward = true;
      _t = 0.001;
      setState(() {});
      _settle(true);
      return;
    }
    widget.onTapCenter();
  }
}
