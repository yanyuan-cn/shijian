/// 全局搜索：一次搜六类，结果按板块分组。
///
/// 这是整个软件的主轴 —— 收藏库的存在理由就是「想找的时候找得到」。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/model.dart';
import '../../data/app_state.dart';
import '../detail_sheet.dart';
import '../kit.dart';
import '../sections/book_detail.dart';
import '../theme.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctl = TextEditingController();
  final _focus = FocusNode();
  List<Item> _res = const [];
  bool _busy = false;
  Timer? _t;
  String _q = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _t?.cancel();
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onType(String v) {
    _t?.cancel();
    _q = v.trim();
    if (_q.isEmpty) {
      setState(() => _res = const []);
      return;
    }
    setState(() => _busy = true);
    _t = Timer(const Duration(milliseconds: 160), () async {
      final r = await App.I.repo.search(_q);
      if (!mounted) return;
      setState(() {
        _res = r;
        _busy = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // 按板块分组，顺序固定，不随命中数乱跳
    final grouped = <String, List<Item>>{};
    for (final t in ST.all) {
      final list = _res.where((e) => e.type == t).toList();
      if (list.isNotEmpty) grouped[t] = list;
    }
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, size: 21, color: C.text2),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctl,
                      focusNode: _focus,
                      onChanged: _onType,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(fontSize: 15, color: C.text),
                      decoration: const InputDecoration(
                        hintText: '搜标题、作者、备注、域名…',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_ctl.text.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        _ctl.clear();
                        _onType('');
                      },
                      icon: const Icon(Icons.close, size: 18, color: C.text3),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _q.isEmpty
                  ? const EmptyHint(
                      icon: Icons.search,
                      title: '搜点什么',
                      sub: '书名、导演、备注、网址里的任何一个词都行')
                  : _busy
                      ? const Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2)))
                      : _res.isEmpty
                          ? EmptyHint(
                              icon: Icons.search_off,
                              title: '没有「$_q」',
                              sub: '试试少打几个字')
                          : ListView(
                              physics: const BouncingScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              children: [
                                for (final e in grouped.entries) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 6, bottom: 8, left: 2),
                                    child: Text(
                                        '${ST.labels[e.key]} · ${e.value.length}',
                                        style: T.kicker),
                                  ),
                                  for (final it in e.value) _row(it),
                                  const SizedBox(height: 12),
                                ],
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(Item it) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (it.type == ST.book) {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BookDetailPage(item: it)));
        } else {
          showItemSheet(context, it);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: C.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.line),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 40,
                height: 40,
                child: BlobImage(it.cover, cacheWidth: 120),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: C.text)),
                  if (it.creator != null || it.note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        it.creator ?? it.note ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.small,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
