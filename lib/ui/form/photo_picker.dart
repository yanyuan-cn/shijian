import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../theme.dart';

/// 选中的一张相册图片：既带原始字节，也带相册里的 asset id（用于导入后删除原件）。
class PickedPhoto {
  PickedPhoto(this.id, this.bytes, this.name);

  final String id;
  final Uint8List bytes;
  final String name;
}

class PhotoPickerResult {
  PhotoPickerResult(this.photos, this.deleteAfter);

  final List<PickedPhoto> photos;

  /// 用户勾了「导入后从相册删除原图」。
  final bool deleteAfter;
}

/// 自建相册选择器（系统选图器给的是缓存副本，删不了原件）。
///
/// - 首次进来请求相册权限（Android 13+ 是「照片和视频」）。
/// - 网格选图，可多选；底部有「导入后删除相册原图」开关。
Future<PhotoPickerResult?> showPhotoPicker(BuildContext context) {
  return Navigator.of(context).push<PhotoPickerResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const _PhotoPickerPage(),
    ),
  );
}

/// 导入完成后调用：把选中的相册原图删掉（Android 10+ 会弹系统确认框）。
Future<bool> deleteFromGallery(List<String> ids) async {
  if (ids.isEmpty) return false;
  try {
    await PhotoManager.editor.deleteWithIds(ids);
    return true;
  } catch (_) {
    return false;
  }
}

class _PhotoPickerPage extends StatefulWidget {
  const _PhotoPickerPage();

  @override
  State<_PhotoPickerPage> createState() => _PhotoPickerPageState();
}

class _PhotoPickerPageState extends State<_PhotoPickerPage> {
  bool _loading = true;
  String? _error;
  List<AssetEntity> _assets = const [];
  final Set<String> _selected = <String>{};
  bool _deleteAfter = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final perm = await PhotoManager.requestPermissionExtend();
      if (!perm.isAuth) {
        setState(() {
          _loading = false;
          _error = '没有相册权限。到「设置 → 应用 → 拾间 → 权限」里允许访问照片后再试。';
        });
        return;
      }
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
        filterOption: FilterOptionGroup(
          orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
        ),
      );
      if (paths.isEmpty) {
        setState(() {
          _loading = false;
          _error = '相册里还没有图片。';
        });
        return;
      }
      final list = await paths.first.getAssetListRange(start: 0, end: 300);
      setState(() {
        _assets = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '读相册失败：$e';
      });
    }
  }

  Future<void> _confirm() async {
    if (_selected.isEmpty) return;
    final out = <PickedPhoto>[];
    for (final a in _assets) {
      if (!_selected.contains(a.id)) continue;
      final file = await a.file;
      if (file == null) continue;
      final bytes = await file.readAsBytes();
      out.add(PickedPhoto(a.id, bytes, a.title ?? 'image.jpg'));
    }
    if (!mounted) return;
    Navigator.of(context).pop(PhotoPickerResult(out, _deleteAfter));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bar,
        title: const Text('选择图片'),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty ? null : _confirm,
            child: Text(
              _selected.isEmpty ? '导入' : '导入 ${_selected.length} 张',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: _body(),
      bottomNavigationBar: Container(
        color: C.panel,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 8 + MediaQuery.of(context).padding.bottom,
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _deleteAfter = !_deleteAfter),
                child: Row(
                  children: [
                    Checkbox(
                      value: _deleteAfter,
                      onChanged: (v) => setState(() => _deleteAfter = v ?? false),
                    ),
                    const Expanded(
                      child: Text(
                        '导入后从相册删除原图（避免手机里存两份）',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(_error!, textAlign: TextAlign.center, style: T.bodyDim),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: _assets.length,
      itemBuilder: (ctx, i) {
        final a = _assets[i];
        final on = _selected.contains(a.id);
        return GestureDetector(
          onTap: () => setState(() {
            if (on) {
              _selected.remove(a.id);
            } else {
              _selected.add(a.id);
            }
          }),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<Uint8List?>(
                future: a.thumbnailDataWithSize(const ThumbnailSize(300, 300)),
                builder: (ctx, s) {
                  final b = s.data;
                  if (b == null) return Container(color: C.panel2);
                  return Image.memory(b, fit: BoxFit.cover);
                },
              ),
              if (on)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: C.accent, width: 3),
                    color: C.accent.withValues(alpha: 0.18),
                  ),
                ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? C.accent : Colors.black.withValues(alpha: 0.35),
                    border: Border.all(color: Colors.white70, width: 1.4),
                  ),
                  child: on
                      ? const Icon(Icons.check, size: 15, color: Color(0xFF0B0F16))
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
