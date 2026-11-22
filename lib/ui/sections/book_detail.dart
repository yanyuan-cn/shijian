/// 书籍详情：抽出来之后看到的一页。
library;

import 'package:flutter/material.dart';

import '../../core/model.dart';
import '../../data/app_state.dart';
import '../form/item_form.dart';
import '../kit.dart';
import '../reader/reader_page.dart';
import '../reader/pdf_page.dart';
import '../theme.dart';
import 'shelf_view.dart' show BookCoverArt;

class BookDetailPage extends StatefulWidget {
  const BookDetailPage({super.key, required this.item, this.flightFrom});

  final Item item;

  /// 从书架上点进来时那本书书脊的屏幕矩形。给了它就做「从书脊展开」的飞行。
  final Rect? flightFrom;

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  bool _changed = false;
  late Item _item = widget.item;

  /// 封面卡最终位置的全局矩形（布局完成后量一次）。
  final GlobalKey _coverKey = GlobalKey();
  Rect? _coverRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureCover());
  }

  void _measureCover() {
    if (!mounted) return;
    final box = _coverKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final r = box.localToGlobal(Offset.zero) & box.size;
    if (_coverRect == r) return;
    setState(() => _coverRect = r);
  }

  Item get _live => App.I.byId(_item.id) ?? _item;

  Future<void> _edit() async {
    await ItemForm.show(context, type: ST.book, item: _live);
    final next = App.I.byId(_item.id);
    if (next == null) {
      if (mounted) {
        Navigator.pop(context, true);
      }
      return;
    }
    setState(() {
      _item = next;
      _changed = true;
    });
  }

  Future<void> _read() async {
    final assets = await App.I.repo.assetsOf(_live.id);
    final book = assets.where((a) => a.role == 'ebook').toList();
    if (book.isEmpty) {
      toast(context, '还没有导入电子书，点「编辑」里的「选择文件」');
      return;
    }
    final mime = (book.first.mime ?? '').toLowerCase();
    final name = (book.first.name ?? '').toLowerCase();
    final isPdf = mime.contains('pdf') || name.endsWith('.pdf');
    final unreadable = mime.contains('mobipocket') ||
        mime.contains('amazon') ||
        name.endsWith('.mobi') ||
        name.endsWith('.azw3');
    if (unreadable) {
      if (!mounted) return;
      toast(context, '这个格式只做了归档，暂时读不了正文（支持 txt / epub / pdf）');
      return;
    }
    if (isPdf) {
      // PDF 不做重排，按原样一页一页显示。
      final f = App.I.blobs.fileOf(book.first.hash);
      if (!f.existsSync()) {
        toast(context, '这个 PDF 读不出来，可能文件丢了');
        return;
      }
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      await PdfReaderPage.open(context, _live, bytes);
      if (mounted) setState(() => _changed = true);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReaderPage(item: _live, asset: book.first),
    ));
    if (mounted) setState(() => _changed = true);
  }

  @override
  Widget build(BuildContext context) {
    final it = _live;
    final c1 = _hex(it.metaStr('c1'), const Color(0xFF2A3B58));
    final c2 = _hex(it.metaStr('c2'), const Color(0xFF131B29));
    final prog = it.progress;
    final tags = (it.metaStr('tags') ?? '')
        .split(RegExp(r'[,，;；、\s]+'))
        .where((e) => e.isNotEmpty)
        .toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Stack(
        children: [
          _body(it, c1, c2, prog, tags),
          if (widget.flightFrom != null) _flight(it),
        ],
      ),
    );
  }

  /// 「从书脊展开 / 收回书脊」的飞行卡：起止矩形都是我们自己算的，
  /// 不依赖 Hero 在透视变换下的测量（那正是之前「落到别处再跳一下」的原因）。
  Widget _flight(Item it) {
    final anim = ModalRoute.of(context)?.animation;
    final from = widget.flightFrom;
    if (anim == null || from == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: anim,
          builder: (_, __) {
            final v = anim.value;
            // 动画结束时卡片和真封面完全重合，直接不画，省一层重绘。
            if (v > 0.995) return const SizedBox.shrink();
            final t = const Cubic(0.22, 0.61, 0.36, 1).transform(v);
            final target = _coverRect ?? from;
            final r = Rect.lerp(from, target, t)!;
            return Stack(
              children: [
                Positioned(
                  left: r.left,
                  top: r.top,
                  width: r.width,
                  height: r.height,
                  child: BookCoverArt(item: it),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(Item it, Color c1, Color c2, int prog, List<String> tags) {
    return Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context, _changed),
                      icon: const Icon(Icons.arrow_back, size: 21),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _edit,
                      style: TextButton.styleFrom(foregroundColor: C.text2),
                      child: const Text('编辑', style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: SizedBox(
                          key: _coverKey,
                          width: 152,
                          height: 214,
                          child: BookCoverArt(item: it),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(it.title,
                          style: const TextStyle(
                            fontFamily: T.serif,
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          )),
                      const SizedBox(height: 8),
                      Text(
                        [it.creator, it.year]
                            .where((e) => e != null && e.isNotEmpty)
                            .join(' · '),
                        style: T.bodyDim,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (it.status != null) _chip(it.status!, C.accent2),
                          if (it.rating != null)
                            _chip('★ ${it.rating}', const Color(0xFFE8C07D)),
                          for (final t in tags) _chip('#$t', C.text2),
                        ],
                      ),
                      if (prog > 0) ...[
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Text('已读 $prog%', style: T.kicker),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: prog / 100,
                                  minHeight: 3,
                                  backgroundColor: C.panel2,
                                  valueColor: const AlwaysStoppedAnimation(
                                      C.accent),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (it.note != null && it.note!.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        const Text('简介', style: T.kicker),
                        const SizedBox(height: 10),
                        Text(it.note!,
                            style: const TextStyle(
                                fontSize: 14, height: 1.85, color: C.text2)),
                      ],
                    ],
                  ),
                ),
              ),
              _bottom(it),
            ],
          ),
        ),
    );
  }

  /// 没有真实封面时的「排版封面」：横排书名压在上半部，作者在底部。
  Widget _spineTitle(Item it) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 1.5, color: Colors.white.withValues(alpha: 0.22)),
            const SizedBox(height: 14),
            Text(
              it.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: T.serif,
                fontSize: 19,
                height: 1.38,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF4F7FC),
              ),
            ),
            const Spacer(),
            Container(
              height: 1,
              width: 26,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 8),
            Text(
              [it.creator, it.year].where((e) => e != null && e.isNotEmpty).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 0.6,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      );

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(text, style: TextStyle(fontSize: 11.5, color: color)),
      );

  Widget _bottom(Item it) => Container(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 12 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: C.line)),
        ),
        child: SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _read,
            style: FilledButton.styleFrom(
              backgroundColor: C.accent,
              foregroundColor: const Color(0xFF0B1220),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            ),
            child: Text(it.progress > 0 && it.progress < 100 ? '继续阅读' : '开始阅读',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      );

  Color _hex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final n = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    if (n == null) return fallback;
    return Color(0xFF000000 | n);
  }
}
