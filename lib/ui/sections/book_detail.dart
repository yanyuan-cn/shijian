/// 书籍详情：抽出来之后看到的一页。
library;

import 'package:flutter/material.dart';

import '../../core/model.dart';
import '../../data/app_state.dart';
import '../form/item_form.dart';
import '../kit.dart';
import '../reader/reader_page.dart';
import '../theme.dart';

class BookDetailPage extends StatefulWidget {
  const BookDetailPage({super.key, required this.item});

  final Item item;

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  bool _changed = false;
  late Item _item = widget.item;

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
      toast(context, '还没有导入电子书，点「编辑」里的导入');
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
      child: Scaffold(
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
                        child: Container(
                          width: 148,
                          height: 208,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [c1, c2],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.55),
                                blurRadius: 26,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: it.cover != null
                              ? BlobImage(it.cover, fit: BoxFit.cover)
                              : _spineTitle(it),
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
      ),
    );
  }

  Widget _spineTitle(Item it) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
        child: Column(
          children: [
            Container(height: 1.5, color: Colors.white24),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: RotatedBox(
                  quarterTurns: 1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(it.title,
                          style: const TextStyle(
                              fontFamily: T.serif,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFF2F5FA))),
                      const SizedBox(height: 8),
                      Text(it.creator ?? '', style: T.small),
                    ],
                  ),
                ),
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
