import 'package:flutter/material.dart';

import '../../core/model.dart';
import '../../data/app_state.dart';
import '../form/item_form.dart';
import '../kit.dart';
import '../theme.dart';
import 'book_detail.dart';
import 'shelf_view.dart';

export 'shelf_view.dart' show bookColors;

/// 书架板块：薄壳，真正的 3D 场景在 [ShelfView]。
class BookPage extends StatelessWidget {
  const BookPage({super.key});

  Future<void> _open(BuildContext context, int i) async {
    final books = App.I.of(ST.book);
    if (i < 0 || i >= books.length) return;
    await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, a, __) =>
            FadeTransition(opacity: a, child: BookDetailPage(item: books[i])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.I,
      builder: (context, _) {
        final books = App.I.of(ST.book);
        if (books.isEmpty) return _empty(context);
        return ShelfView(books: books, onOpen: (i) => _open(context, i));
      },
    );
  }

  Widget _empty(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 46, color: C.text3),
            const SizedBox(height: 14),
            Text('书架还空着', style: T.sectionTitle.copyWith(fontSize: 15)),
            const SizedBox(height: 6),
            Text('点右上角 + 加第一本', style: T.small),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => ItemForm.show(context, type: ST.book),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.accent2,
                side: const BorderSide(color: C.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('添加书'),
            ),
          ],
        ),
      );
}
