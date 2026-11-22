import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../data/app_state.dart';
import '../../core/model.dart';
import '../theme.dart';

/// PDF 阅读：不做任何重排，原样按页渲染（用户明确要求「直接输出」）。
/// 只额外做两件事：记住进度、支持双指缩放。
class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({super.key, required this.item, required this.bytes});

  final Item item;
  final Uint8List bytes;

  static Future<void> open(BuildContext context, Item item,
      Uint8List bytes) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfReaderPage(item: item, bytes: bytes),
      ),
    );
  }

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  PdfControllerPinch? _ctrl;
  int _page = 0;
  int _pages = 0;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await PdfDocument.openData(widget.bytes);
      final start = (widget.item.progress / 100 * doc.pagesCount).floor();
      if (!mounted) return;
      setState(() {
        _pages = doc.pagesCount;
        _page = start.clamp(0, doc.pagesCount - 1);
        _ctrl = PdfControllerPinch(
          document: Future.value(doc),
          initialPage: _page,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '这个 PDF 打不开：$e');
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _saveProgress(int page) {
    if (_pages <= 0) return;
    final pct = ((page + 1) * 100 / _pages).round().clamp(0, 100);
    final next = widget.item
        .withMeta({'prog': pct})
        .copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch);
    // 直接用 repo 落库（App.save 会走表单逻辑，把字段覆盖成空）。
    App.I.repo.upsert(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bar,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
            if (_pages > 0)
              Text('第 ${_page + 1} / $_pages 页 · PDF 原样显示',
                  style: T.small.copyWith(fontSize: 10.5)),
          ],
        ),
      ),
      body: _err != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(_err!, textAlign: TextAlign.center, style: T.bodyDim),
              ),
            )
          : _ctrl == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : PdfViewPinch(
                  controller: _ctrl!,
                  backgroundDecoration: const BoxDecoration(color: C.bg),
                  onPageChanged: (p) {
                    final i = (p - 1).clamp(0, _pages - 1);
                    setState(() => _page = i);
                    _saveProgress(i);
                  },
                ),
    );
  }
}
