/// 统一条目模型。
///
/// 设计要点：六个板块共用一张 item 表，板块专属字段全部塞进 [Item.meta] 的 JSON。
/// 这样「加第七个板块」不需要改表、不需要迁移，只需要注册一个 SectionSpec。
library;

import 'dart:convert';

/// 板块类型常量。'me'（我的）不是板块，是外壳页。
class ST {
  ST._();
  static const book = 'book';
  static const movie = 'movie';
  static const tv = 'tv';
  static const pic = 'pic';
  static const link = 'link';
  static const all = <String>[book, movie, tv, pic, link];
  static const labels = <String, String>{
    book: '书架',
    movie: '电影',
    tv: '剧集',
    pic: '图集',
    link: '链接',
  };
}

class Item {
  final String id;
  final String type;
  final String title;

  /// 书=作者，电影=导演，剧集=主创，图片=分类，链接=域名。
  final String? creator;

  /// 年份（字符串，允许「2023」「未知」）。
  final String? year;

  /// 封面/海报/原图的 blob 哈希（sha256），不是 URL。
  /// 匹配到的远程海报会先下载入库，避免源站挂掉后整片空白。
  final String? cover;

  final String? rating;
  final String? status;
  final String? note;
  final String? sourceUrl;

  /// 板块专属字段：书的书脊配色、图片的宽高比、剧集的进度……
  final Map<String, dynamic> meta;

  final int addedAt;
  final int updatedAt;
  final bool deleted;
  final String deviceId;
  final int rev;

  const Item({
    required this.id,
    required this.type,
    required this.title,
    this.creator,
    this.year,
    this.cover,
    this.rating,
    this.status,
    this.note,
    this.sourceUrl,
    this.meta = const {},
    required this.addedAt,
    required this.updatedAt,
    this.deleted = false,
    this.deviceId = '',
    this.rev = 0,
  });

  String? metaStr(String k) {
    final v = meta[k];
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    return v.toString();
  }

  double? metaNum(String k) => switch (meta[k]) {
        final num n => n.toDouble(),
        final String s => double.tryParse(s),
        _ => null,
      };

  int metaInt(String k, [int fallback = 0]) => switch (meta[k]) {
        final num n => n.toInt(),
        final String s => int.tryParse(s) ?? fallback,
        _ => fallback,
      };

  bool metaBool(String k, [bool fallback = false]) => switch (meta[k]) {
        final bool b => b,
        final num n => n != 0,
        _ => fallback,
      };

  /// 图片瀑布流依赖的宽高比（宽/高），缺省 1.2。
  double get aspect => metaNum('ar') ?? 1.2;

  /// 阅读/观看进度 0..100。
  int get progress => metaInt('prog');
  int get seen => metaInt('ep');

  Item copyWith({
    String? title,
    String? creator,
    String? year,
    String? cover,
    String? rating,
    String? status,
    String? note,
    String? sourceUrl,
    Map<String, dynamic>? meta,
    int? updatedAt,
    bool? deleted,
    int? rev,
    bool clearCover = false,
  }) {
    return Item(
      id: id,
      type: type,
      title: title ?? this.title,
      creator: creator ?? this.creator,
      year: year ?? this.year,
      cover: clearCover ? null : (cover ?? this.cover),
      rating: rating ?? this.rating,
      status: status ?? this.status,
      note: note ?? this.note,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      meta: meta ?? this.meta,
      addedAt: addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      deviceId: deviceId,
      rev: rev ?? this.rev,
    );
  }

  Item withMeta(Map<String, dynamic> patch) {
    final m = Map<String, dynamic>.from(meta);
    patch.forEach((k, v) {
      if (v == null) {
        m.remove(k);
      } else {
        m[k] = v;
      }
    });
    return copyWith(meta: m);
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'type': type,
        'title': title,
        'creator': creator,
        'year': year,
        'cover': cover,
        'rating': rating,
        'status': status,
        'note': note,
        'source_url': sourceUrl,
        'meta': jsonEncode(meta),
        'added_at': addedAt,
        'updated_at': updatedAt,
        'deleted': deleted ? 1 : 0,
        'device_id': deviceId,
        'rev': rev,
      };

  static Item fromRow(Map<String, Object?> r) {
    Map<String, dynamic> m = const {};
    final raw = r['meta'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) m = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // 坏 JSON 不应该让整条记录读不出来
      }
    } else if (raw is Map) {
      m = Map<String, dynamic>.from(raw);
    }
    return Item(
      id: r['id'] as String,
      type: r['type'] as String,
      title: (r['title'] as String?) ?? '',
      creator: r['creator'] as String?,
      year: r['year'] as String?,
      cover: r['cover'] as String?,
      rating: r['rating'] as String?,
      status: r['status'] as String?,
      note: r['note'] as String?,
      sourceUrl: r['source_url'] as String?,
      meta: m,
      addedAt: (r['added_at'] as num?)?.toInt() ?? 0,
      updatedAt: (r['updated_at'] as num?)?.toInt() ?? 0,
      deleted: ((r['deleted'] as num?)?.toInt() ?? 0) != 0,
      deviceId: (r['device_id'] as String?) ?? '',
      rev: (r['rev'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 附件（电子书正文、多格式版本等）。图片原图与缩略图也走这里，
/// 但列表用的封面/海报只记在 item.cover 上，减少一次 join。
class Asset {
  final String id;
  final String? itemId;
  final String role; // cover / original / thumb / ebook
  final String hash;
  final String path; // 相对 blob 根目录，形如 ab/cd/<sha256>.ext
  final int size;
  final String? mime;
  final String? name;
  final bool isPrimary;

  const Asset({
    required this.id,
    this.itemId,
    required this.role,
    required this.hash,
    required this.path,
    this.size = 0,
    this.mime,
    this.name,
    this.isPrimary = false,
  });

  Map<String, Object?> toRow() => {
        'id': id,
        'item_id': itemId,
        'role': role,
        'hash': hash,
        'path': path,
        'size': size,
        'mime': mime,
        'name': name,
        'is_primary': isPrimary ? 1 : 0,
      };

  static Asset fromRow(Map<String, Object?> r) => Asset(
        id: r['id'] as String,
        itemId: r['item_id'] as String?,
        role: (r['role'] as String?) ?? '',
        hash: (r['hash'] as String?) ?? '',
        path: (r['path'] as String?) ?? '',
        size: (r['size'] as num?)?.toInt() ?? 0,
        mime: r['mime'] as String?,
        name: r['name'] as String?,
        isPrimary: ((r['is_primary'] as num?)?.toInt() ?? 0) != 0,
      );
}
