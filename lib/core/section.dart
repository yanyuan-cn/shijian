/// 板块注册表：一个板块 = 一组字段 + 一个标签 + 一种列表形态。
///
/// 加第七个板块时，这里加一条，UI 那边加一个列表 Widget —— 数据、表单、
/// 搜索、导入导出、备份全都不用动。
library;

enum FieldKind { text, number, multiline, choice, multi, tags, image, color }

/// 影视「类型」的预设项（可多选，也可自己补）。
const List<String> kGenres = [
  '剧情', '喜剧', '动作', '科幻', '爱情', '悬疑', '犯罪', '惊悚',
  '恐怖', '奇幻', '冒险', '动画', '纪录片', '历史', '战争', '音乐',
  '家庭', '武侠', '古装', '真人秀',
];

class FieldSpec {
  const FieldSpec(
    this.key, {
    required this.label,
    this.kind = FieldKind.text,
    this.hint,
    this.options = const [],
    this.required = false,
    this.half = false,
  });

  /// 普通字段直接是列名；板块专属字段写成 'm:key'，落到 item.meta。
  final String key;
  final String label;
  final FieldKind kind;
  final String? hint;
  final List<String> options;
  final bool required;
  final bool half;

  bool get isMeta => key.startsWith('m:');
  String get bareKey => isMeta ? key.substring(2) : key;
}

class SectionSpec {
  const SectionSpec({
    required this.type,
    required this.label,
    required this.titleLabel,
    required this.titleHint,
    required this.fields,
    this.coverLabel,
  });

  final String type;
  final String label;
  final String titleLabel;
  final String titleHint;
  final List<FieldSpec> fields;

  /// 封面/海报/图片字段的提示语
  final String? coverLabel;

  static const _book = SectionSpec(
    type: 'book',
    label: '书架',
    titleLabel: '书名',
    titleHint: '例如：夜晚的潜水艇',
    coverLabel: '封面（可选，不填就用书脊配色）',
    fields: [
      FieldSpec('creator', label: '作者', half: true, hint: '刘慈欣'),
      FieldSpec('year', label: '出版年', half: true, kind: FieldKind.number),
      FieldSpec('status',
          label: '状态',
          kind: FieldKind.choice,
          options: ['想读', '在读', '已读']),
      FieldSpec('rating', label: '评分', half: true, kind: FieldKind.number),
      FieldSpec('m:tags', label: '标签', kind: FieldKind.tags, half: true),
      FieldSpec('note', label: '简介 / 摘记', kind: FieldKind.multiline),
    ],
  );

  static const _movie = SectionSpec(
    type: 'movie',
    label: '电影',
    titleLabel: '片名',
    titleHint: '例如：海上钢琴师',
    coverLabel: '海报',
    fields: [
      FieldSpec('creator', label: '导演', half: true),
      FieldSpec('year', label: '年份', half: true, kind: FieldKind.number),
      FieldSpec('m:dur', label: '片长', half: true, hint: '165 分钟'),
      FieldSpec('m:genre', label: '类型', half: true,
          kind: FieldKind.multi, options: kGenres),
      FieldSpec('rating', label: '评分', half: true, kind: FieldKind.number),
      FieldSpec('m:tags', label: '标签', kind: FieldKind.tags, half: true),
      FieldSpec('note', label: '简介 / 备注', kind: FieldKind.multiline),
    ],
  );

  static const _tv = SectionSpec(
    type: 'tv',
    label: '剧集',
    titleLabel: '剧名',
    titleHint: '例如：漫长的季节',
    coverLabel: '海报',
    fields: [
      FieldSpec('creator', label: '主创', half: true),
      FieldSpec('year', label: '年份', half: true, kind: FieldKind.number),
      FieldSpec('m:ep', label: '总集数', half: true, kind: FieldKind.number),
      FieldSpec('m:seen', label: '已看集数', half: true, kind: FieldKind.number),
      FieldSpec('m:genre', label: '类型', half: true,
          kind: FieldKind.multi, options: kGenres),
      FieldSpec('rating', label: '评分', half: true, kind: FieldKind.number),
      FieldSpec('m:tags', label: '标签', kind: FieldKind.tags, half: true),
      FieldSpec('note', label: '简介 / 备注', kind: FieldKind.multiline),
    ],
  );

  static const _pic = SectionSpec(
    type: 'pic',
    label: '图集',
    titleLabel: '标题',
    titleHint: '可以留空，用文件名',
    coverLabel: '图片',
    fields: [
      FieldSpec('m:cat', label: '分类', half: true, hint: '壁纸 / 收藏'),
      FieldSpec('m:tags', label: '标签', kind: FieldKind.tags, half: true),
      FieldSpec('note', label: '备注', kind: FieldKind.multiline),
    ],
  );

  static const _link = SectionSpec(
    type: 'link',
    label: '链接',
    titleLabel: '名称',
    titleHint: '例如：Excalidraw',
    fields: [
      FieldSpec('source_url',
          label: '网址', hint: 'https://…', required: true),
      FieldSpec('m:cat', label: '分类', half: true),
      FieldSpec('m:tags', label: '标签', kind: FieldKind.tags, half: true),
      FieldSpec('note', label: '备注', kind: FieldKind.multiline),
    ],
  );

  static const Map<String, SectionSpec> all = {
    'book': _book,
    'movie': _movie,
    'tv': _tv,
    'pic': _pic,
    'link': _link,
  };

  static SectionSpec of(String type) => all[type] ?? _book;
}
