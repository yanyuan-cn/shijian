/// 声明式表单：字段由 SectionSpec 提供，这里只负责渲染、校验、落库。
///
/// 加板块不用碰这个文件；加字段只改 core/section.dart。
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/model.dart';
import '../../core/section.dart';
import '../../data/app_state.dart';
import '../../data/settings.dart';
import '../kit.dart';
import '../theme.dart';
import 'match_sheet.dart';

class ItemForm extends StatefulWidget {
  const ItemForm({super.key, required this.type, this.item});

  final String type;
  final Item? item;

  static Future<void> show(BuildContext context,
      {required String type, Item? item}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemForm(type: type, item: item),
    );
  }

  @override
  State<ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<ItemForm> {
  late final SectionSpec _spec = SectionSpec.of(widget.type);
  final _title = TextEditingController();
  final Map<String, TextEditingController> _ctl = {};
  final Map<String, dynamic> _meta = {};
  String? _cover;
  Uint8List? _pendingBytes;
  String? _pendingName;
  bool _busy = false;
  String _status = '';

  bool get _isEdit => widget.item != null;
  bool get _isPic => widget.type == ST.pic;
  bool get _isLink => widget.type == ST.link;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _title.text = it?.title ?? '';
    final fields = _spec.fields;
    for (final f in fields) {
      final text = f.isMeta
          ? (it?.meta[f.bareKey]?.toString() ?? '')
          : switch (f.key) {
              'creator' => it?.creator ?? '',
              'year' => it?.year ?? '',
              'rating' => it?.rating ?? '',
              'status' => it?.status ?? '',
              'note' => it?.note ?? '',
              'source_url' => it?.sourceUrl ?? '',
              _ => '',
            };
      _ctl[f.key] = TextEditingController(text: text);
      if (f.isMeta) {
        final v = it?.meta[f.bareKey];
        if (v != null) _meta[f.bareKey] = v;
      }
    }
    if (it != null) {
      _status = it.status ?? '';
      _cover = it.cover;
    }
    if (_isLink) _ctl['source_url']?.addListener(_syncDomain);
  }

  void _syncDomain() {
    final u = _ctl['source_url']?.text ?? '';
    final host = _hostOf(u);
    if (host.isNotEmpty) {
      setState(() => _meta['cat'] = _meta['cat'] ?? host);
    }
  }

  static String _hostOf(String url) {
    try {
      final u = Uri.parse(url.trim());
      var h = u.host;
      if (h.isEmpty) return '';
      if (h.startsWith('www.')) h = h.substring(4);
      return h;
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCover() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 92,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      setState(() {
        _pendingBytes = bytes;
        _pendingName = x.name;
        if (_isPic) _meta['ar'] = _pendingAspect;
      });
      if (_isPic && _title.text.trim().isEmpty) {
        final n = x.name;
        final dot = n.lastIndexOf('.');
        _title.text = dot > 0 ? n.substring(0, dot) : n;
      }
      await _fillAspect(bytes);
    } catch (e) {
      if (mounted) toast(context, '选图失败：$e');
    }
  }

  double _pendingAspect = 1.2;

  Future<void> _fillAspect(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width.toDouble();
      final h = frame.image.height.toDouble();
      frame.image.dispose();
      if (h > 0) {
        setState(() {
          _pendingAspect = w / h;
          _meta['ar'] = _pendingAspect;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickFromFiles() async {
    try {
      final list = await FilePicker.pickFiles(
        type: FileType.image,
      );
      final f = list.firstOrNull;
      if (f == null) return;
      final bytes = await f.readAsBytes();
      setState(() {
        _pendingBytes = bytes;
        _pendingName = f.name;
      });
      if (_isPic && _title.text.trim().isEmpty) {
        final n = f.name;
        final dot = n.lastIndexOf('.');
        _title.text = dot > 0 ? n.substring(0, dot) : n;
      }
      await _fillAspect(bytes);
    } catch (e) {
      if (mounted) toast(context, '选图失败：$e');
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final title = _title.text.trim();
    if (title.isEmpty && !_isPic) {
      toast(context, '请填写${_spec.titleLabel}');
      return;
    }
    if (_isPic && _cover == null && _pendingBytes == null) {
      toast(context, '请先选择一张图片');
      return;
    }
    if (_isLink && (_ctl['source_url']?.text.trim() ?? '').isEmpty) {
      toast(context, '请填写网址');
      return;
    }
    setState(() => _busy = true);
    try {
      String? coverHash = _cover;
      if (_pendingBytes != null) {
        coverHash = await App.I.putCover(_pendingBytes!);
      }
      final meta = Map<String, dynamic>.from(_meta);
      for (final f in _spec.fields) {
        if (f.isMeta) {
          final v = _ctl[f.key]?.text.trim() ?? '';
          if (v.isEmpty) {
            meta.remove(f.bareKey);
          } else if (f.kind == FieldKind.number) {
            meta[f.bareKey] = int.tryParse(v) ?? v;
          } else {
            meta[f.bareKey] = v;
          }
        }
      }
      final values = <String, dynamic>{
        'title': title.isEmpty ? (widget.item?.title ?? '未命名') : title,
        'creator': _ctl['creator']?.text,
        'year': _ctl['year']?.text,
        'rating': _ctl['rating']?.text,
        'status': _status.isEmpty ? _ctl['status']?.text : _status,
        'note': _ctl['note']?.text,
        'source_url': _ctl['source_url']?.text,
        'meta': meta,
      };
      if (_isLink) {
        values['creator'] = _hostOf(_ctl['source_url']?.text ?? '');
      }
      if (_isEdit) {
        await App.I.save(widget.item!, values,
            coverHash: coverHash,
            clearCover: coverHash == null && _cover == null);
        if (!mounted) return;
        toast(context, '已保存');
      } else {
        await App.I.create(
            type: widget.type, values: values, coverHash: coverHash);
        if (!mounted) return;
        toast(context, '已收藏');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, '保存失败：$e');
      }
    }
  }

  Future<void> _delete() async {
    final it = widget.item!;
    final ok = await confirm(context,
        title: '删除「${it.title}」？',
        message: '会从所有列表里移除，导出备份里也不会再有它。',
        ok: '删除',
        danger: true);
    if (!ok) return;
    await App.I.delete(it.id);
    if (mounted) {
      Navigator.pop(context);
      toast(context, '已删除');
    }
  }

  Future<void> _openMatch() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      toast(context, '先填个${_spec.titleLabel}，匹配要用它搜');
      return;
    }
    final res = await MatchSheet.show(context,
        type: widget.type, query: title);
    if (res == null) return;
    setState(() {
      if (res.title.isNotEmpty) _title.text = res.title;
      if (res.creator != null) _ctl['creator']?.text = res.creator!;
      if (res.year != null) _ctl['year']?.text = res.year!;
      if (res.rating != null) _ctl['rating']?.text = res.rating!;
      if (res.note != null && (_ctl['note']?.text.trim().isEmpty ?? true)) {
        _ctl['note']?.text = res.note!;
      }
      if (res.coverBytes != null) {
        _pendingBytes = Uint8List.fromList(res.coverBytes!);
        _pendingName = 'cover.jpg';
      }
      res.meta.forEach((k, v) => _meta[k] = v);
      res.meta.forEach((k, v) {
        _ctl['m:$k']?.text = v.toString();
      });
      if (res.sourceUrl != null) _ctl['source_url']?.text = res.sourceUrl!;
    });
    if (mounted) toast(context, '已填入，记得检查后保存');
  }

  bool get _canMatch =>
      widget.type == ST.book ||
      widget.type == ST.movie ||
      widget.type == ST.tv;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        height: h * 0.9,
        decoration: const BoxDecoration(
          color: C.panel,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _handle(),
            _topBar(),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                children: [
                  if (widget.type != ST.link) _coverRow(),
                  const SizedBox(height: 14),
                  _label(_spec.titleLabel, required: !_isPic),
                  TextField(
                    controller: _title,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(hintText: _spec.titleHint),
                  ),
                  const SizedBox(height: 14),
                  ..._buildFields(),
                ],
              ),
            ),
            _saveBar(),
          ],
        ),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: C.text3.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 10, 10),
        child: Row(
          children: [
            Text(
              _isEdit ? '编辑${_spec.label}' : '添加到${_spec.label}',
              style: const TextStyle(
                  fontFamily: T.serif,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: C.text),
            ),
            const Spacer(),
            if (_canMatch && Settings.autoMatch)
              TextButton.icon(
                onPressed: _openMatch,
                icon: const Icon(Icons.auto_awesome, size: 15),
                label: const Text('匹配', style: TextStyle(fontSize: 12.5)),
                style: TextButton.styleFrom(foregroundColor: C.accent2),
              ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 20, color: C.text2),
              splashRadius: 18,
            ),
          ],
        ),
      );

  Widget _coverRow() {
    final pending = _pendingBytes;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _pickCover,
          onLongPress: _pickFromFiles,
          child: Container(
            width: _isPic ? 96 : 74,
            height: _isPic ? 96 : 104,
            decoration: BoxDecoration(
              color: C.panel2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: pending != null
                ? Image.memory(pending, fit: BoxFit.cover)
                : (_cover != null
                    ? BlobImage(_cover, fit: BoxFit.cover)
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 22, color: C.text3),
                          SizedBox(height: 6),
                          Text('选择图片',
                              style: TextStyle(fontSize: 10.5, color: C.text3)),
                        ],
                      )),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_spec.coverLabel ?? '封面', style: T.bodyDim),
              const SizedBox(height: 4),
              Text(
                _isPic
                    ? '原图会完整保存，看的时候不压缩'
                    : '可以留空；匹配到海报会自动下载到本地',
                style: T.small,
              ),
              if (pending != null || _cover != null)
                TextButton(
                  onPressed: () => setState(() {
                    _pendingBytes = null;
                    _cover = null;
                  }),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                      foregroundColor: C.text3),
                  child: const Text('移除', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFields() {
    final out = <Widget>[];
    final fields = _spec.fields;
    // 两列成对排布：half=true 的连续字段两两并排。
    var i = 0;
    while (i < fields.length) {
      final f = fields[i];
      if (f.half && i + 1 < fields.length && fields[i + 1].half) {
        out.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _fieldWidget(f)),
            const SizedBox(width: 12),
            Expanded(child: _fieldWidget(fields[i + 1])),
          ],
        ));
        i += 2;
      } else {
        out.add(_fieldWidget(f));
        i++;
      }
      out.add(const SizedBox(height: 14));
    }
    return out;
  }

  Widget _fieldWidget(FieldSpec f) {
    switch (f.kind) {
      case FieldKind.choice:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(f.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final o in f.options)
                  _chip(o, _status == o, () => setState(() => _status = o)),
              ],
            ),
          ],
        );
      case FieldKind.multiline:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(f.label),
            TextField(
              controller: _ctl[f.key],
              minLines: 3,
              maxLines: 6,
              style: const TextStyle(fontSize: 14, height: 1.6),
              decoration: InputDecoration(hintText: f.hint ?? '写点什么'),
            ),
          ],
        );
      case FieldKind.tags:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(f.label),
            TextField(
              controller: _ctl[f.key],
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(hintText: '用逗号分隔，例如：工具, 画图'),
            ),
          ],
        );
      case FieldKind.number:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(f.label),
            TextField(
              controller: _ctl[f.key],
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(hintText: f.hint),
            ),
          ],
        );
      case FieldKind.image:
      case FieldKind.color:
      case FieldKind.text:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(f.label, required: f.required),
            TextField(
              controller: _ctl[f.key],
              style: const TextStyle(fontSize: 14),
              keyboardType: f.key == 'source_url'
                  ? TextInputType.url
                  : TextInputType.text,
              decoration: InputDecoration(hintText: f.hint),
            ),
          ],
        );
    }
  }

  Widget _chip(String text, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? C.accent.withValues(alpha: 0.16) : C.panel2,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: on ? C.accent.withValues(alpha: 0.5) : C.line),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 12.5, color: on ? C.accent2 : C.text2)),
      ),
    );
  }

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            Text(text, style: T.kicker),
            if (required)
              const Text(' *',
                  style: TextStyle(fontSize: 12, color: C.danger)),
          ],
        ),
      );

  Widget _saveBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 10, 18, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: C.line)),
      ),
      child: Row(
        children: [
          if (_isEdit)
            TextButton(
              onPressed: _busy ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: C.danger),
              child: const Text('删除'),
            ),
          const Spacer(),
          SizedBox(
            height: 44,
            width: 128,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: C.accent,
                foregroundColor: const Color(0xFF0B1220),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF0B1220)))
                  : Text(_isEdit ? '保存' : '收藏',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
