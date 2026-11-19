/// 数据源匹配。接口先留好，源全挂时也必须有手工兜底。
///
/// 设计约束：
///  · key 只存本地设置，不进代码、不进仓库；
///  · 网络失败绝不阻塞保存；
///  · 匹配到的封面必须下载成 blob 再入库，绝不在条目里存远程 URL。
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../data/app_state.dart';
import '../data/settings.dart';

Dio buildDio({bool meta = true}) {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 25),
    headers: {'User-Agent': 'shijian/1.0'},
  ));
  final proxy = Settings.proxy.trim();
  if (proxy.isNotEmpty && meta) {
    var hp = proxy;
    if (hp.startsWith('http://')) hp = hp.substring(7);
    if (hp.startsWith('https://')) hp = hp.substring(8);
    hp = hp.split('/').first;
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final c = HttpClient();
        c.findProxy = (_) => 'PROXY $hp';
        c.connectionTimeout = const Duration(seconds: 12);
        return c;
      },
    );
  }
  return dio;
}

class MetaCandidate {
  MetaCandidate({
    required this.provider,
    required this.id,
    required this.title,
    this.creator,
    this.year,
    this.rating,
    this.note,
    this.coverUrl,
    this.sourceUrl,
    this.meta = const {},
  });

  final String provider;
  final String id;
  final String title;
  final String? creator;
  final String? year;
  final String? rating;
  final String? note;
  final String? coverUrl;
  final String? sourceUrl;
  final Map<String, dynamic> meta;
}

abstract class MetaProvider {
  String get id;
  String get label;
  bool supports(String type);

  /// 返回已足够完整的结果（封面 URL 也算），一次请求就够填表。
  Future<List<MetaCandidate>> search(String type, String query);
}

/// 匹配结果：已经带着下载好的封面字节，表单拿到就能存。
class MatchResult {
  MatchResult({
    required this.title,
    this.creator,
    this.year,
    this.rating,
    this.note,
    this.coverBytes,
    this.sourceUrl,
    this.meta = const {},
    this.external,
  });

  final String title;
  final String? creator;
  final String? year;
  final String? rating;
  final String? note;
  final List<int>? coverBytes;
  final String? sourceUrl;
  final Map<String, dynamic> meta;
  final MetaCandidate? external;
}

class MetaService {
  // 代理设置改了要换一个 Dio：IOHttpClientAdapter 的 findProxy 是建的时候定的。
  static Dio? _cached;
  static String _cachedProxy = '';

  static Dio get _dio {
    final p = Settings.proxy.trim();
    if (_cached == null || p != _cachedProxy) {
      _cachedProxy = p;
      _cached = buildDio();
    }
    return _cached!;
  }

  static final List<MetaProvider> providers = [
    _GoogleBooks(),
    _OpenLibrary(),
    _Tmdb(),
    _Bangumi(),
  ];

  /// 设置页的连通性自检：返回命中条数，-1 表示这个源当前不可用。
  static Future<int> probe(String label) async {
    final p = providers.where((e) => e.label == label).firstOrNull;
    if (p == null) return -1;
    if (p.id == 'tmdb' && Settings.tmdbKey.trim().isEmpty) return -1;
    final q = switch (p.id) {
      'googlebooks' || 'openlibrary' => '三体',
      'tmdb' => '三体',
      _ => '三体',
    };
    final type = switch (p.id) {
      'tmdb' => 'movie',
      'bangumi' => 'tv',
      _ => 'book',
    };
    try {
      final r = await p.search(type, q).timeout(const Duration(seconds: 15));
      return r.length;
    } catch (_) {
      return -1;
    }
  }

  static Future<List<MetaCandidate>> search(String type, String q,
      {int limit = 12}) async {
    final usable = providers.where((p) => p.supports(type));
    final out = <MetaCandidate>[];
    for (final p in usable) {
      try {
        final r = await p.search(type, q).timeout(const Duration(seconds: 20));
        out.addAll(r);
      } catch (_) {
        // 单个源挂了不影响其它源，更不影响手工填写
      }
      if (out.length >= limit) break;
    }
    return out.take(limit).toList();
  }

  /// 下载封面 → 存 blob。失败返回 null（没有封面也能保存）。
  static Future<List<int>?> fetchCover(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final r = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = r.data;
      if (data == null || data.isEmpty) return null;
      if (data.length > 25 * 1024 * 1024) return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  static Future<List<int>?> fetchCoverToBlob(String? url) async {
    final bytes = await fetchCover(url);
    if (bytes == null) return null;
    // 这里只是存进仓库，actual 引用由调用方写进 item.cover
    return bytes;
  }
}

String _yearOf(String? s) {
  if (s == null) return '';
  final m = RegExp(r'\d{4}').firstMatch(s);
  return m?.group(0) ?? '';
}

class _GoogleBooks implements MetaProvider {
  @override
  String get id => 'googlebooks';
  @override
  String get label => 'Google Books';
  @override
  bool supports(String type) => type == 'book';

  @override
  Future<List<MetaCandidate>> search(String type, String q) async {
    final isIsbn = RegExp(r'^\d{9}[\dXx]$').hasMatch(q.replaceAll('-', ''));
    final query = isIsbn ? 'isbn:${q.replaceAll('-', '')}' : 'intitle:$q';
    final r = await MetaService._dio.get(
      'https://www.googleapis.com/books/v1/volumes',
      queryParameters: {'q': query, 'maxResults': 10},
    );
    final items = (r.data?['items'] as List?) ?? const [];
    return items.map((e) {
      final v = (e as Map)['volumeInfo'] as Map? ?? const {};
      final links = (v['imageLinks'] as Map?) ?? const {};
      final authors = (v['authors'] as List?)?.join(' / ');
      return MetaCandidate(
        provider: id,
        id: (e['id'] ?? '').toString(),
        title: (v['title'] ?? '').toString(),
        creator: authors?.toString(),
        year: _yearOf(v['publishedDate']?.toString()),
        rating: v['averageRating']?.toString(),
        note: v['description']?.toString(),
        coverUrl: (links['thumbnail'] ?? links['smallThumbnail'])
            ?.toString()
            ?.replaceFirst('http://', 'https://'),
        sourceUrl: (v['infoLink'] ?? '').toString(),
      );
    }).where((c) => c.title.isNotEmpty).toList();
  }
}

class _OpenLibrary implements MetaProvider {
  @override
  String get id => 'openlibrary';
  @override
  String get label => 'Open Library';
  @override
  bool supports(String type) => type == 'book';

  @override
  Future<List<MetaCandidate>> search(String type, String q) async {
    final r = await MetaService._dio.get(
      'https://openlibrary.org/search.json',
      queryParameters: {'q': q, 'limit': 10, 'fields': 'key,title,author_name,'
          'first_publish_year,cover_i,subject'},
    );
    final docs = (r.data?['docs'] as List?) ?? const [];
    return docs.map((e) {
      final m = e as Map;
      final cover = m['cover_i'];
      return MetaCandidate(
        provider: id,
        id: (m['key'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        creator: (m['author_name'] as List?)?.join(' / '),
        year: _yearOf(m['first_publish_year']?.toString()),
        coverUrl: cover == null
            ? null
            : 'https://covers.openlibrary.org/b/id/$cover-L.jpg',
        sourceUrl: m['key'] == null
            ? null
            : 'https://openlibrary.org${m['key']}',
      );
    }).where((c) => c.title.isNotEmpty).toList();
  }
}

class _Tmdb implements MetaProvider {
  @override
  String get id => 'tmdb';
  @override
  String get label => 'TMDB';
  @override
  bool supports(String type) => type == 'movie' || type == 'tv';

  @override
  Future<List<MetaCandidate>> search(String type, String q) async {
    final key = Settings.tmdbKey.trim();
    if (key.isEmpty) return const [];
    final isTv = type == 'tv';
    final r = await MetaService._dio.get(
      'https://api.themoviedb.org/3/search/${isTv ? 'tv' : 'movie'}',
      queryParameters: {
        'api_key': key,
        'query': q,
        'language': 'zh-CN',
        'include_adult': false,
      },
    );
    final list = (r.data?['results'] as List?) ?? const [];
    return list.map((e) {
      final m = e as Map;
      final date = (m['release_date'] ?? m['first_air_date'] ?? '').toString();
      final poster = m['poster_path']?.toString();
      return MetaCandidate(
        provider: id,
        id: (m['id'] ?? '').toString(),
        title: (m['title'] ?? m['name'] ?? '').toString(),
        year: _yearOf(date),
        rating: m['vote_average'] == null
            ? null
            : (m['vote_average'] as num).toStringAsFixed(1),
        note: m['overview']?.toString(),
        coverUrl:
            poster == null ? null : 'https://image.tmdb.org/t/p/w780$poster',
        sourceUrl: m['id'] == null
            ? null
            : 'https://www.themoviedb.org/${isTv ? 'tv' : 'movie'}/${m['id']}',
      );
    }).where((c) => c.title.isNotEmpty).toList();
  }
}

class _Bangumi implements MetaProvider {
  @override
  String get id => 'bangumi';
  @override
  String get label => 'Bangumi';
  @override
  bool supports(String type) => type == 'tv';

  @override
  Future<List<MetaCandidate>> search(String type, String q) async {
    final r = await MetaService._dio.get(
      'https://api.bgm.tv/search/subject/${Uri.encodeComponent(q)}',
      queryParameters: {'type': 2, 'responseGroup': 'large', 'max_results': 10},
      options: Options(headers: {'User-Agent': 'shijian/1.0 (personal app)'}),
    );
    final list = (r.data?['list'] as List?) ?? const [];
    return list.map((e) {
      final m = e as Map;
      final images = (m['images'] as Map?) ?? const {};
      final rating = (m['rating'] as Map?) ?? const {};
      final name = (m['name_cn'] ?? m['name'] ?? '').toString();
      return MetaCandidate(
        provider: id,
        id: (m['id'] ?? '').toString(),
        title: name,
        year: _yearOf((m['air_date'] ?? '').toString()),
        rating: rating['score']?.toString(),
        note: m['summary']?.toString(),
        coverUrl: (images['large'] ?? images['common'])?.toString(),
        sourceUrl: m['id'] == null
            ? null
            : 'https://bgm.tv/subject/${m['id']}',
      );
    }).where((c) => c.title.isNotEmpty).toList();
  }
}
