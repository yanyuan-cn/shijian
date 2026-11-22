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
                      if (it.type == ST.book) ...[
                        const SizedBox(height: 18),
                        _bookProgress(it),
                      ],
                      if (it.type == ST.movie) ...[
                        const SizedBox(height: 18),
                        _movieProgress(context, it),
                      ],
                      if (it.type == ST.tv) ...[
                        const SizedBox(height: 18),
                        _tvProgress(context, it),
                      ],
                      if (it.type == ST.link) ...[
                        const SizedBox(height: 18),
                        _linkBlock(it),
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

  /// 书：阅读进度（只读展示，改它要在阅读器里翻页）。
  Widget _bookProgress(Item it) {
    final p = it.progress.clamp(0, 100);
    return _bar(
      label: '阅读进度',
      trailing: '$p%',
      value: p / 100,
    );
  }

  /// 电影：观看进度，可手动改（很多人是分几次看完的）。
  Widget _movieProgress(BuildContext context, Item it) {
    final p = it.progress.clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bar(label: '观看进度', trailing: '$p%', value: p / 100),
        const SizedBox(height: 8),
        Row(
          children: [
            _miniBtn(Icons.remove, () => _setProg(it, p - 10)),
            const SizedBox(width: 8),
            _miniBtn(Icons.add, () => _setProg(it, p + 10)),
            const Spacer(),
            TextButton(
              onPressed: () => _editProg(context, it),
              child: const Text('设置进度', style: TextStyle(fontSize: 12)),
            ),
            TextButton(
              onPressed: () => _setProg(it, 100),
              child: const Text('看完', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  /// 剧集：按「已看集数 / 总集数」记进度，集数可以手动输入。
  Widget _tvProgress(BuildContext context, Item it) {
    final total = it.totalEps;
    final seen = it.seenEps.clamp(0, total > 0 ? total : 9999);
    final pct = it.epPercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bar(
          label: total > 0 ? '已看 $seen / $total 集' : '已看 $seen 集',
          trailing: '$pct%',
          value: pct / 100,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _miniBtn(Icons.remove, () => _setSeen(it, seen - 1)),
            const SizedBox(width: 8),
            _miniBtn(Icons.add, () => _setSeen(it, seen + 1)),
            const Spacer(),
            TextButton(
              onPressed: () => _editSeen(context, it),
              child: const Text('设置集数', style: TextStyle(fontSize: 12)),
            ),
            if (total > 0)
              TextButton(
                onPressed: () => _setSeen(it, total),
                child: const Text('看完', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _bar({
    required String label,
    required String trailing,
    required double value,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: T.small),
              const Spacer(),
              Text(trailing, style: T.small.copyWith(color: C.accent2)),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: C.panel2,
              valueColor: const AlwaysStoppedAnimation(C.accent),
            ),
          ),
        ],
      );

  /// 链接：把完整地址摆出来（可选中复制），再给一个显眼的打开按钮。
  Widget _linkBlock(Item it) {
    final raw = it.sourceUrl?.trim();
    final url = (raw != null && raw.isNotEmpty)
        ? raw
        : (it.creator != null && it.creator!.isNotEmpty
            ? 'https://${it.creator}'
            : '');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: C.panel2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('链接地址', style: T.small.copyWith(fontSize: 10.5)),
          const SizedBox(height: 6),
          if (url.isEmpty)
            Text('还没填地址，点下面「编辑」补上',
                style: T.bodyDim.copyWith(fontSize: 12.5))
          else
            SelectableText(
              url,
              style: T.bodyDim.copyWith(fontSize: 12.5, height: 1.45),
            ),
        ],
      ),
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

  Future<void> _setProg(Item it, int value) async {
    final v = value.clamp(0, 100);
    final next = it
        .withMeta({'prog': v})
        .copyWith(
            updatedAt: DateTime.now().millisecondsSinceEpoch, rev: it.rev + 1);
    await App.I.repo.upsert(next);
    await App.I.reload();
  }

  Future<void> _setSeen(Item it, int value) async {
    final total = it.totalEps;
    final v = value.clamp(0, total > 0 ? total : 9999);
    final patch = <String, dynamic>{'seen': v};
    // 顺带把百分比也算出来，方便列表/侧边栏在不看总集数时也能显示
    if (total > 0) patch['prog'] = (v * 100 / total).round();
    final next = it.withMeta(patch).copyWith(
        updatedAt: DateTime.now().millisecondsSinceEpoch, rev: it.rev + 1);
    await App.I.repo.upsert(next);
    await App.I.reload();
  }

  Future<void> _editProg(BuildContext context, Item it) async {
    final ctl = TextEditingController(text: '${it.progress}');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('观看进度'),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(suffixText: '%', hintText: '0 – 100'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, int.tryParse(ctl.text.trim()) ?? 0),
              child: const Text('确定')),
        ],
      ),
    );
    if (v != null) await _setProg(it, v);
  }

  Future<void> _editSeen(BuildContext context, Item it) async {
    final ctl = TextEditingController(text: '${it.seenEps}');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('已看集数'),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: it.totalEps > 0 ? '0 – ${it.totalEps}' : '已看到第几集',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, int.tryParse(ctl.text.trim()) ?? 0),
              child: const Text('确定')),
        ],
      ),
    );
    if (v != null) await _setSeen(it, v);
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
    // tags 在 meta 里是逗号分隔的字符串（旧数据可能存成数组），两种都要认。
    final rawTags = it.meta['tags'];
    final tags = <String>[
      if (rawTags is List)
        ...rawTags.whereType<String>()
      else if (rawTags is String)
        ...rawTags.split(RegExp(r'[,，;；、\s]+')).where((e) => e.isNotEmpty),
    ];
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
