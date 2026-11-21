/// 数据源匹配。接口先留好，源全挂时也必须有手工兜底。
///
/// 设计约束：
///  · key 只存本地设置，不进代码、不进仓库；
///  · 网络失败绝不阻塞保存；
///  · 匹配到的封面必须下载成 blob 再入库，绝不在条目里存远程 URL。
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../data/settings.dart';

Dio buildDio({bool meta = true}) {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 25),
    headers: {'User-Agent': 'shijian/1.0'},
  ));
  final proxy = Settings.proxy.trim();
  if (proxy.isNotEmpty && meta) {
    if (_isRelay(proxy)) {
      // 中转模式：把原始 URL 交给中转服务（Cloudflare Worker 等），
      // 形如 https://xxx.workers.dev/?url=<原始地址>，或含 {url} 占位。
      dio.interceptors.add(_RelayInterceptor(proxy));
      return dio;
    }
    // 代理模式：支持裸 host:port、http://、https://、socks5://、socks://
    var hp = proxy;
    String scheme = 'PROXY';
    final lower = hp.toLowerCase();
    if (lower.startsWith('socks5://')) {
      scheme = 'SOCKS5';
      hp = hp.substring(9);
    } else if (lower.startsWith('socks://')) {
      scheme = 'SOCKS5';
      hp = hp.substring(8);
    } else if (lower.startsWith('http://')) {
      hp = hp.substring(7);
    } else if (lower.startsWith('https://')) {
      hp = hp.substring(8);
    }
    hp = hp.split('/').first; // 去掉任何 path
    final target = scheme == 'SOCKS5' ? 'SOCKS5 $hp' : 'PROXY $hp';
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final c = HttpClient();
        c.findProxy = (_) => target;
        c.connectionTimeout = const Duration(seconds: 12);
        return c;
      },
    );
  }
  return dio;
}

/// 判断填写的是「中转地址」还是「代理地址」。
/// 代理一定带端口（127.0.0.1:7897），中转是普通域名/URL，不带端口。
bool _isRelay(String v) {
  var s = v;
  final lower = s.toLowerCase();
  if (lower.startsWith('socks5://') || lower.startsWith('socks://')) return false;
  if (lower.startsWith('http://')) s = s.substring(7);
  if (lower.startsWith('https://')) s = s.substring(8);
  if (s.contains('{url}')) return true; // 显式模板
  return !s.contains(':'); // 带 :port 的是代理
}

/// 把每个数据源请求改写成 `<中转>?url=<原始地址>`。
class _RelayInterceptor extends Interceptor {
  _RelayInterceptor(this.tpl);

  final String tpl;

  /// 国内直连就通、而且中转白名单里没有的站点：别绕中转（绕了反而 403/变慢）。
  static const Set<String> _directHosts = <String>{};

  @override
  void onRequest(RequestOptions o, RequestInterceptorHandler h) {
    if (_directHosts.contains(o.uri.host)) {
      h.next(o);
      return;
    }
    final full = o.uri.toString();
    final enc = Uri.encodeComponent(full);
    final base = tpl.trim();
    if (base.contains('{url}')) {
      o.path = base.replaceAll('{url}', enc);
    } else {
      final sep = base.contains('?') ? '&' : '?';
      o.path = '$base${sep}url=$enc';
    }
    o.baseUrl = '';
    h.next(o);
  }
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
    // 中文书优先走 NeoDB（结构化 JSON、ISBN 精确、封面无防盗链），
    // 再退 Open Library；Google Books 匿名配额为 0，只在填了 Key 时才有用。
    _NeoDb(),
    _IsbnLookup(),
    _GoogleBooks(),
    _OpenLibrary(),
    _Tmdb(),
    _Bangumi(),
  ];

  /// 设置页的连通性自检：返回命中条数（-1=不可用）和失败原因（空串=成功）。
  static Future<({int hits, String error})> probe(String label) async {
    final p = providers.where((e) => e.label == label).firstOrNull;
    if (p == null) return (hits: -1, error: '未知数据源');
    if (p.id == 'tmdb' && Settings.tmdbKey.trim().isEmpty) {
      return (hits: -1, error: '未填 TMDB API Key');
    }
    // Open Library 要求 query ≥3 字符，「三体」只有 2 个汉字会 422，用 4 字词。
    // ISBN 通道必须喂一个真实 ISBN，否则它按「不是 ISBN」直接返回空。
    final q = p.id == 'isbn' ? '9787536692930' : '三体小说';
    final type = switch (p.id) {
      'tmdb' => 'movie',
      'bangumi' => 'tv',
      _ => 'book',
    };
    try {
      final r = await p.search(type, q).timeout(const Duration(seconds: 15));
      return (hits: r.length, error: '');
    } catch (e) {
      // ignore: avoid_print — 只写 logcat，方便排查数据源连通性
      print('[probe] $label 失败 -> $e');
      return (hits: -1, error: _errText(e));
    }
  }

  static String _errText(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          return '连接超时（网络/DNS 不通）';
        case DioExceptionType.connectionError:
          return '连接失败：${_short(e.error ?? e.message)}';
        case DioExceptionType.receiveTimeout:
          return '响应超时';
        case DioExceptionType.badResponse:
          return 'HTTP ${e.response?.statusCode}';
        default:
          return '网络错误：${_short(e.error ?? e.message)}';
      }
    }
    if (e is TimeoutException) return '超时';
    if (e is TypeError || e is FormatException) {
      return '返回的不是预期的 JSON（中转地址可能填错）';
    }
    return _short(e);
  }

  /// 把底层异常（SocketException / HandshakeException 等）压成一行可读文字。
  static String _short(Object? o) {
    if (o == null) return '无详情';
    var s = o.toString().replaceAll('\n', ' ').trim();
    if (s.length > 110) s = '${s.substring(0, 110)}…';
    return s;
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
      queryParameters: {
        'q': query,
        'maxResults': 10,
        if (Settings.gbKey.isNotEmpty) 'key': Settings.gbKey,
      },
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

/// ISBN 精确查询：Open Library 的 /api/books 接口，命中率比 search.json 高得多，
/// 而且中文书也有（实测 9787536692930 → 三体 / 刘慈欣）。只在输入是 ISBN 时生效。
/// NeoDB（neodb.social）：联邦式书影音库，**中文书 ISBN 命中率最高**的一档。
///
/// 实测（2026-11）：10 个中文 ISBN 全部精确命中，出版社是中文原名
/// （对比 Open Library 会给 "Chongqing Press" 这种罗马化名字），
/// 封面没有防盗链，返回的是结构化 JSON —— 不用解析 HTML，也不会被 418。
/// 它是志愿者单实例，挂了可以退回 Open Library；所以放在最前面但必须有兜底。
class _NeoDb implements MetaProvider {
  @override
  String get id => 'neodb';
  @override
  String get label => 'NeoDB';
  @override
  bool supports(String type) => type == 'book';

  static const String _base = 'https://neodb.social';

  @override
  Future<List<MetaCandidate>> search(String type, String q) async {
    final raw = q.trim();
    if (raw.isEmpty) return const [];
    final isbn = raw.replaceAll(RegExp(r'[^0-9Xx]'), '').toUpperCase();
    final isIsbn = isbn.length == 10 || isbn.length == 13;
    final r = await MetaService._dio.get(
      '$_base/api/catalog/search',
      queryParameters: {
        'query': isIsbn ? isbn : raw,
        'category': 'book',
      },
      options: Options(responseType: ResponseType.json),
    );
    final data = (r.data as Map?)?['data'] as List?;
    if (data == null || data.isEmpty) return const [];

    final out = <MetaCandidate>[];
    for (final e in data.take(8)) {
      final m = e as Map?;
      if (m == null) continue;
      // 按 ISBN 查时，搜索结果仍是全文匹配，必须回读校验，否则会串到别的书。
      if (isIsbn && (m['isbn'] ?? '').toString().replaceAll('-', '') != isbn) {
        continue;
      }
      final title = (m['display_title'] ?? m['title'] ?? '').toString();
      if (title.isEmpty) continue;
      final cat = (m['category'] ?? 'book').toString();
      out.add(MetaCandidate(
        provider: id,
        id: (m['uuid'] ?? m['id'] ?? isbn).toString(),
        title: title,
        creator: _joinAuthors(m),
        year: _yearOf((m['pub_year'] ?? m['pub_month'] ?? '').toString()),
        rating: (m['rating'] is num)
            ? (m['rating'] as num).toStringAsFixed(1)
            : null,
        note: (m['brief'] ?? '').toString().isEmpty
            ? null
            : m['brief'].toString(),
        coverUrl: (m['cover_image_url'] ?? '').toString().isEmpty
            ? null
            : m['cover_image_url'].toString(),
        sourceUrl: '$_base/$cat/${m['uuid']}',
      ));
    }
    return out;
  }

  static String? _joinAuthors(Map m) {
    final a = (m['author'] as List?) ?? const [];
    final names = a.map((e) => e.toString()).where((e) => e.isNotEmpty);
    if (names.isEmpty) return null;
    return names.join(' / ');
  }
}

class _IsbnLookup implements MetaProvider {
  @override
  String get id => 'isbn';
  @override
  String get label => 'ISBN';
  @override
  bool supports(String type) => type == 'book';

  static bool looksLikeIsbn(String q) {
    final v = q.replaceAll(RegExp(r'[^0-9Xx]'), '');
    return v.length == 10 || v.length == 13;
  }

  @override
  Future<List<MetaCandidate>> search(String type, String q) async {
    final isbn = q.replaceAll(RegExp(r'[^0-9Xx]'), '').toUpperCase();
    if (!looksLikeIsbn(isbn)) return const [];
    final r = await MetaService._dio.get(
      'https://openlibrary.org/api/books',
      queryParameters: {
        'bibkeys': 'ISBN:$isbn',
        'format': 'json',
        'jscmd': 'data',
      },
    );
    final map = r.data as Map?;
    final book = map?['ISBN:$isbn'] as Map?;
    if (book == null) return const [];
    final cover = (book['cover'] as Map?) ?? const {};
    final authors = (book['authors'] as List?) ?? const [];
    return [
      MetaCandidate(
        provider: id,
        id: isbn,
        title: (book['title'] ?? '').toString(),
        creator: authors
            .map((a) => (a as Map)['name']?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .join(' / '),
        year: _yearOf(book['publish_date']?.toString()),
        coverUrl: (cover['medium'] ?? cover['large'] ?? cover['small'])
                ?.toString()
                ?.replaceFirst('http://', 'https://') ??
            // 很多版本没有 cover 字段，但按 ISBN 直取封面通常有；
            // default=false 让「确实没有封面」时返回 404，避免存进一张 1px 的空图。
            'https://covers.openlibrary.org/b/isbn/$isbn-L.jpg?default=false',
        sourceUrl: book['url']?.toString(),
        note: ((book['subjects'] as List?) ?? const [])
            .take(8)
            .map((s) => (s as Map)['name']?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .join('、'),
      ),
    ];
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
