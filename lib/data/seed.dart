/// 首装演示数据。让第一次打开不是六片空白 —— 空书架没有任何说服力。
library;

import '../core/ids.dart';
import '../core/model.dart';

List<Item> seedItems() {
  final now = DateTime.now().millisecondsSinceEpoch;
  var t = now;
  Item mk(
    String type,
    String title, {
    String? creator,
    String? year,
    String? note,
    Map<String, dynamic> meta = const {},
    String? status,
    String? rating,
    int daysAgo = 0,
  }) {
    t -= 1000;
    return Item(
      id: Ids.ulid(),
      type: type,
      title: title,
      creator: creator,
      year: year,
      note: note,
      meta: meta,
      status: status,
      rating: rating,
      addedAt: t - daysAgo * 86400000,
      updatedAt: t,
      deviceId: '',
    );
  }

  return [
    mk(ST.book, '夜晚的潜水艇', creator: '陈春成', year: '2020',
        status: '在读',
        meta: {'c1': '#1F4B41', 'c2': '#0E2A24', 'prog': 46, 'tags': '短篇, 中文'},
        daysAgo: 1),
    mk(ST.book, '三体', creator: '刘慈欣', year: '2008', status: '已读',
        rating: '9.3',
        meta: {'c1': '#2A3B58', 'c2': '#141C2B', 'prog': 100, 'tags': '科幻'},
        daysAgo: 12),
    mk(ST.book, '长安的荔枝', creator: '马伯庸', year: '2021', status: '已读',
        rating: '8.5',
        meta: {'c1': '#7A4A22', 'c2': '#3D2410', 'prog': 100, 'tags': '历史'},
        daysAgo: 30),
    mk(ST.book, '额尔古纳河右岸', creator: '迟子建', year: '2005',
        status: '想读',
        meta: {'c1': '#24402C', 'c2': '#101F16', 'prog': 0, 'tags': '中文, 长篇'},
        daysAgo: 45),
    mk(ST.book, '漫长的告别', creator: '雷蒙德·钱德勒', year: '1953',
        status: '想读',
        meta: {'c1': '#5B2540', 'c2': '#2A0F1D', 'prog': 0, 'tags': '推理'},
        daysAgo: 60),

    mk(ST.movie, '海上钢琴师', creator: '朱塞佩·托纳多雷', year: '1998',
        rating: '9.3', note: '重看的时候还是会在甲板上那段停下来。',
        meta: {'dur': '165 分钟', 'genre': '剧情 / 音乐', 'tags': '重看'},
        daysAgo: 3),
    mk(ST.movie, '步履不停', creator: '是枝裕和', year: '2008', rating: '8.8',
        meta: {'dur': '115 分钟', 'genre': '剧情 / 家庭', 'tags': '日影'},
        daysAgo: 8),
    mk(ST.movie, '燃烧', creator: '李沧东', year: '2018', rating: '8.1',
        meta: {'dur': '148 分钟', 'genre': '剧情 / 悬疑', 'tags': '韩影'},
        daysAgo: 21),

    mk(ST.tv, '漫长的季节', creator: '辛爽', year: '2023', rating: '9.4',
        status: '看完',
        meta: {'ep': 12, 'genre': '剧情 / 悬疑', 'tags': '国产'},
        daysAgo: 5),
    mk(ST.tv, '平原上的摩西', creator: '张大磊', year: '2023', rating: '8.1',
        status: '在看',
        meta: {'ep': 6, 'prog': 50, 'genre': '剧情', 'tags': '国产'},
        daysAgo: 15),

    mk(ST.link, 'Excalidraw', creator: 'excalidraw.com', year: '2024',
        note: '手绘风白板，画架构图很顺手。',
        meta: {'c': '#3D4A66', 'tags': '工具, 画图'}, daysAgo: 2),
    mk(ST.link, 'Regex101', creator: 'regex101.com', year: '2024',
        note: '正则调试，带解释。', meta: {'c': '#4A3D66', 'tags': '工具'},
        daysAgo: 9),
    mk(ST.link, 'MDN Web Docs', creator: 'developer.mozilla.org', year: '2023',
        note: '查 CSS 和 Web API。', meta: {'c': '#2F4A44', 'tags': '文档'},
        daysAgo: 18),
  ];
}
