/// 通用详情面板：六个板块共用一套骨架，只有「动作」按类型增删。
///
/// 这就是 SectionSpec 里 actions 的具体样子 —— 加板块时不需要动这里。
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/model.dart';
import '../data/app_state.dart';
import '../platform/image_out.dart';
import 'form/item_form.dart';
import 'kit.dart';
import 'reader/reader_page.dart';
import 'sections/book_detail.dart';
import 'theme.dart';

Future<void> showItemSheet(BuildContext context, Item item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ItemSheet(id: item.id),
  );
}

class _ItemSheet extends StatelessWidget {
  const _ItemSheet({required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.I,
      builder: (context, _) {
        final it = App.I.byId(id);
        if (it == null) {
          // 条目被删掉了，面板自动收起
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          });
          return const SizedBox.shrink();
        }
        final spec = SectionSpecView.of(it);
        final maxH = MediaQuery.of(context).size.height * 0.86;
        return Container(
          constraints: BoxConstraints(maxHeight: maxH),
          decoration: const BoxDecoration(
            color: C.panel,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: C.text3.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _head(context, it, spec),
                      if (it.note != null) ...[
                        const SizedBox(height: 16),
                        Text(it.note!, style: T.bodyDim),
                      ],
                      if (spec.rows.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        for (final r in spec.rows) _kv(r.$1, r.$2),
                      ],
                      if (it.progress != null) ...[
                        const SizedBox(height: 18),
                        _progress(it),
                      ],
                      if (it.type == ST.tv) ...[
                        const SizedBox(height: 14),
                        _tvProgress(context, it),
                      ],
                      const SizedBox(height: 20),
                      _actions(context, it),
                    ],
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
            ],
          ),
        );
      },
    );
  }

  Widget _head(BuildContext context, Item it, SectionSpecView spec) {
    final wide = it.type == ST.book || it.type == ST.movie || it.type == ST.tv;
    final coverH = it.type == ST.pic ? 180.0 : 148.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (it.cover != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: wide ? 100 : 148,
              height: coverH,
              child: BlobImage(it.cover, cacheWidth: 400),
            ),
          )
        else
          Container(
            width: wide ? 100 : 148,
            height: coverH,
            decoration: BoxDecoration(
              color: C.panel2,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              it.title.isEmpty ? '?' : it.title.characters.first,
              style: TextStyle(
                fontFamily: T.serif,
                fontSize: 34,
                color: C.text3,
              ),
            ),
          ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(it.title,
                  style: const TextStyle(
                      fontFamily: T.serif,
                      fontSize: 19,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: C.text)),
              if (spec.sub != null) ...[
                const SizedBox(height: 6),
                Text(spec.sub!, style: T.small.copyWith(fontSize: 12.5)),
              ],
              if (spec.chips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in spec.chips)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: C.panel2,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(c, style: T.small.copyWith(color: C.text2)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 62, child: Text(k, style: T.small)),
            Expanded(
                child: Text(v, style: T.bodyDim.copyWith(fontSize: 12.5))),
          ],
        ),
      );

  Widget _progress(Item it) {
    final p = (it.progress ?? 0) / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('阅读进度', style: T.small),
            const Spacer(),
            Text('${it.progress}%', style: T.small.copyWith(color: C.accent2)),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: p.clamp(0, 1),
            minHeight: 4,
            backgroundColor: C.panel2,
            valueColor: const AlwaysStoppedAnimation(C.accent),
          ),
        ),
      ],
    );
  }

  Widget _tvProgress(BuildContext context, Item it) {
    final seen = it.seen ?? 0;
    return Row(
      children: [
        Text('已看 $seen%', style: T.small),
        const Spacer(),
        _miniBtn(Icons.remove, () => _bump(it, -10)),
        const SizedBox(width: 8),
        _miniBtn(Icons.add, () => _bump(it, 10)),
        const SizedBox(width: 10),
        TextButton(
          onPressed: () => _bump(it, 100 - seen),
          child: const Text('看完', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _miniBtn(IconData ic, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: C.panel2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(ic, size: 17, color: C.text2),
        ),
      );

  Future<void> _bump(Item it, int delta) async {
    final v = ((it.seen ?? 0) + delta).clamp(0, 100);
    final next = it
        .withMeta({'seen': v})
        .copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch, rev: it.rev + 1);
    await App.I.repo.upsert(next);
    await App.I.reload();
  }

  Widget _actions(BuildContext context, Item it) {
    final btns = <Widget>[];
    if (it.type == ST.book) {
      btns.add(_primary('阅读', () async {
        final assets = await App.I.repo.assetsOf(it.id);
        Asset? eb;
        for (final a in assets) {
          if (a.role == 'ebook') eb = a;
        }
        if (!context.mounted) return;
        if (eb == null) {
          toast(context, '还没有正文，去「编辑」里导入 txt / epub');
          return;
        }
        Navigator.pop(context);
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ReaderPage(item: it, asset: eb!)));
      }));
    }
    if (it.type == ST.link && it.sourceUrl != null) {
      btns.add(_primary('打开链接', () => _open(context, it.sourceUrl!)));
    }
    if (it.type == ST.pic) {
      btns.add(_primary('原图', () => showImageViewer(context, [it], 0)));
      btns.add(_ghost('保存', () => saveImageToGallery(context, it)));
      btns.add(_ghost('分享', () => shareImage(context, it)));
      btns.add(_ghost('壁纸', () => setAsWallpaper(context, it)));
    }
    if (it.type == ST.book) {
      btns.add(_ghost('详情', () {
        Navigator.pop(context);
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BookDetailPage(item: it)));
      }));
    }
    btns.add(_ghost('编辑', () {
      Navigator.pop(context);
      ItemForm.show(context, type: it.type, item: it);
    }));
    btns.add(_ghost('删除', () async {
      final ok = await confirm(context,
          title: '删除《${it.title}》？', message: '删掉就找不回来了。', ok: '删除', danger: true);
      if (!ok || !context.mounted) return;
      Navigator.pop(context);
      await App.I.delete(it.id);
    }));
    return Wrap(spacing: 9, runSpacing: 9, children: btns);
  }

  Future<void> _open(BuildContext context, String url) async {
    var u = url.trim();
    if (!u.contains('://')) u = 'https://$u';
    final uri = Uri.tryParse(u);
    if (uri == null) {
      toast(context, '网址不对');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) toast(context, '打不开这个链接');
  }

  Widget _primary(String label, VoidCallback onTap) => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: C.accent,
          foregroundColor: const Color(0xFF0B1220),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          textStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      );

  Widget _ghost(String label, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: C.text2,
          side: const BorderSide(color: C.line),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          textStyle: const TextStyle(fontSize: 13),
        ),
        child: Text(label),
      );
}

/// 把 Item 摊平成「副标题 / chips / 键值行」，免得每个板块各写一遍详情。
class SectionSpecView {
  SectionSpecView._(this.sub, this.chips, this.rows);

  final String? sub;
  final List<String> chips;
  final List<(String, String)> rows;

  static SectionSpecView of(Item it) {
    final sub = <String>[];
    if (it.creator != null) sub.add(it.creator!);
    if (it.year != null) sub.add(it.year!);
    final chips = <String>[];
    if (it.rating != null) chips.add('★ ${it.rating}');
    if (it.status != null) chips.add(it.status!);
    final tags = (it.meta['tags'] as List?)?.whereType<String>() ?? const [];
    chips.addAll(tags);

    final rows = <(String, String)>[];
    void add(String k, Object? v) {
      if (v == null) return;
      final s = v.toString().trim();
      if (s.isEmpty) return;
      rows.add((k, s));
    }

    switch (it.type) {
      case ST.movie:
        add('片长', it.metaStr('dur'));
        add('类型', it.metaStr('genre'));
        add('导演', it.metaStr('dir'));
        add('主演', it.metaStr('cast'));
      case ST.tv:
        add('类型', it.metaStr('genre'));
        add('集数', it.metaStr('ep'));
      case ST.pic:
        add('分类', it.metaStr('cat'));
        add('尺寸', it.metaStr('wh'));
      case ST.link:
        add('域名', it.creator);
        add('备注', it.metaStr('desc'));
        add('添加', fmtDate(it.addedAt));
      case ST.book:
        add('分类', it.metaStr('cat'));
    }
    return SectionSpecView._(
      sub.isEmpty ? null : sub.join(' · '),
      chips,
      rows,
    );
  }
}
