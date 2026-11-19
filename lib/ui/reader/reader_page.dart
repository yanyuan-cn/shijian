/// 阅读器：只要四件事 —— 进度、字体、翻页方式、深浅色。
///
/// 进度存 locator（字符偏移），不存页码：换字号就重排，页码一定错位。
library;

import 'dart:async';
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

  bool _sizeDiff(Size s) =>
      (_lastSize.width - s.width).abs() > 1 ||
      (_lastSize.height - s.height).abs() > 1;
  late PageController _pc;
  Timer? _saveTimer;
  int _restoreLoc = -1;

  @override
  void initState() {
    super.initState();
    _pc = PageController();
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _flushProgress();
    _pc.dispose();
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

  TextStyle get _textStyle => TextStyle(
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

  void _paginate(Size size) {
    final text = _doc?.text ?? '';
    if (text.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(text: text, style: _textStyle),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: size.width);
    final lines = tp.computeLineMetrics();
    final starts = <int>[0];
    var acc = 0.0;
    for (final l in lines) {
      if (acc + l.height > size.height && acc > 0) {
        final y = l.baseline - l.ascent + 1;
        final pos = tp.getPositionForOffset(Offset(0, y));
        final off = pos.offset;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pc.hasClients) {
        _pc.jumpToPage(_page);
      }
    });
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
    final next = it
        .withMeta({'prog': pct, 'loc': loc})
        .copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch, rev: it.rev + 1);
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
    Settings.readerTurn = t;
    final loc = _starts.isEmpty ? 0 : _starts[_page.clamp(0, _starts.length - 2)];
    Settings.readerTurn = t;
    setState(() {
      _turn = t;
      _measured = false;
      _restoreLoc = loc;
    });
  }

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
                final size = Size(
                    c.maxWidth - 44, c.maxHeight - 44);
                if (!_measured ||
                    _sizeDiff(size) ||
                    _lastSize.height != size.height) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    if (!_measured ||
                        _sizeDiff(size) ||
                        _lastSize.height != size.height) {
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
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _menu = !_menu),
                  child: PageView.builder(
                    controller: _pc,
                    scrollDirection:
                        _turn == 'scroll' ? Axis.vertical : Axis.horizontal,
                    itemCount: _starts.length - 1,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            doc.text.substring(_starts[i], _starts[i + 1]),
                            style: _textStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            if (_menu) _menuOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _menuOverlay() {
    final doc = _doc;
    final pct = doc == null
        ? 0
        : ((_starts.isEmpty ? 0 : _starts[_page.clamp(0, _starts.length - 2)]) /
                (doc.text.isEmpty ? 1 : doc.text.length) *
                100)
            .round();
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
                    style: TextStyle(fontSize: 13, color: _fg.withValues(alpha: 0.7)),
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
          if (doc != null && doc.chapters.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextButton.icon(
                onPressed: _showToc,
                icon: Icon(Icons.list, size: 18, color: _fg.withValues(alpha: 0.7)),
                label: Text('目录',
                    style: TextStyle(
                        fontSize: 13, color: _fg.withValues(alpha: 0.7))),
              ),
            ),
          Container(
            color: _bg,
            padding: EdgeInsets.fromLTRB(
                16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('字号',
                        style: TextStyle(
                            fontSize: 12, color: _fg.withValues(alpha: 0.55))),
                    IconButton(
                      onPressed: _fontSize > 13 ? () => _setFont(_fontSize - 1) : null,
                      icon: Icon(Icons.text_decrease, color: _fg, size: 20),
                    ),
                    Text('${_fontSize.toInt()}',
                        style: TextStyle(fontSize: 13, color: _fg)),
                    IconButton(
                      onPressed: _fontSize < 30 ? () => _setFont(_fontSize + 1) : null,
                      icon: Icon(Icons.text_increase, color: _fg, size: 20),
                    ),
                    const Spacer(),
                    _themeDot('sepia', const Color(0xFFF2EADA)),
                    _themeDot('light', const Color(0xFFFAFAF7)),
                    _themeDot('dark', const Color(0xFF0F1318)),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () =>
                          _setTurn(_turn == 'page' ? 'scroll' : 'page'),
                      style: TextButton.styleFrom(
                          foregroundColor: _fg.withValues(alpha: 0.7)),
                      child: Text(_turn == 'page' ? '左右翻页' : '上下翻页',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ],
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
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(
              color: _theme == key
                  ? C.accent
                  : _fg.withValues(alpha: 0.25),
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
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: doc.chapters.length,
            itemBuilder: (_, i) {
              final ch = doc.chapters[i];
              final on = cur >= ch.offset &&
                  (i == doc.chapters.length - 1 ||
                      cur < doc.chapters[i + 1].offset);
              return ListTile(
                dense: true,
                title: Text(ch.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        color: on ? C.accent2 : C.text2)),
              );
            },
          ),
        ),
      ),
    );
  }
}
