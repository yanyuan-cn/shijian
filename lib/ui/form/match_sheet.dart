/// 匹配结果选择器。选中后把封面下载进 blob 仓库，再把其余字段交回表单。
library;

import 'package:flutter/material.dart';

import '../../core/model.dart';
import '../../net/meta.dart';
import '../kit.dart';
import '../theme.dart';

class MatchSheet extends StatefulWidget {
  const MatchSheet({super.key, required this.type, required this.query});

  final String type;
  final String query;

  static Future<MatchResult?> show(BuildContext context,
      {required String type, required String query}) {
    return showModalBottomSheet<MatchResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MatchSheet(type: type, query: query),
    );
  }

  @override
  State<MatchSheet> createState() => _MatchSheetState();
}

class _MatchSheetState extends State<MatchSheet> {
  late final TextEditingController _q =
      TextEditingController(text: widget.query);
  List<MetaCandidate>? _list;
  bool _loading = false;
  String? _err;
  int _loadingIdx = -1;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _err = null;
      _list = null;
    });
    try {
      final r = await MetaService.search(widget.type, _q.text.trim());
      if (!mounted) return;
      setState(() {
        _list = r;
        _loading = false;
        if (r.isEmpty) _err = '没搜到。可以换个关键词，或者直接手工填。';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = '搜索失败：$e';
      });
    }
  }

  Future<void> _pick(MetaCandidate c, int i) async {
    setState(() => _loadingIdx = i);
    final bytes = await MetaService.fetchCover(c.coverUrl);
    if (!mounted) return;
    Navigator.pop(
      context,
      MatchResult(
        title: c.title,
        creator: c.creator,
        year: c.year,
        rating: c.rating,
        note: c.note,
        coverBytes: bytes,
        sourceUrl: c.sourceUrl,
        meta: {
          if (c.creator != null && widget.type != ST.book) 'dir': c.creator,
          if (c.creator != null && widget.type == ST.book) 'a': c.creator,
          'provider': c.provider,
          'external_id': c.id,
        },
        external: c,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Container(
      height: h * 0.82,
      decoration: const BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
                color: C.text3.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
            child: Row(
              children: [
                const Text('匹配数据源',
                    style: TextStyle(
                        fontFamily: T.serif,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20, color: C.text2),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _run(),
                    decoration: const InputDecoration(
                        hintText: '书名 / 片名 / ISBN'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _run,
                  style: FilledButton.styleFrom(
                    backgroundColor: C.panel2,
                    foregroundColor: C.text,
                    minimumSize: const Size(64, 44),
                  ),
                  child: const Text('搜索', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_err != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
              child: Column(
                children: [
                  Text(_err!,
                      textAlign: TextAlign.center, style: T.bodyDim),
                  const SizedBox(height: 10),
                  Text(
                    '提示：在「我的 › 数据源」里填 TMDB Key、开 HTTP 代理，成功率会高很多。',
                    textAlign: TextAlign.center,
                    style: T.small,
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                itemCount: _list?.length ?? 0,
                separatorBuilder: (_, __) =>
                    const Divider(height: 18, color: C.line),
                itemBuilder: (_, i) {
                  final c = _list![i];
                  return InkWell(
                    onTap: _loadingIdx >= 0 ? null : () => _pick(c, i),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 56,
                            height: 78,
                            child: c.coverUrl == null
                                ? Container(color: C.panel2)
                                : Image.network(
                                    c.coverUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Container(color: C.panel2),
                                    loadingBuilder: (_, w, p) =>
                                        p == null ? w : Container(color: C.panel2),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (c.year != null && c.year!.isNotEmpty)
                                    c.year!,
                                  if (c.creator != null) c.creator!,
                                  c.provider,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: T.small,
                              ),
                              if (c.note != null && c.note!.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(c.note!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: T.small),
                              ],
                            ],
                          ),
                        ),
                        if (_loadingIdx == i)
                          const Padding(
                            padding: EdgeInsets.only(left: 8, top: 24),
                            child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
