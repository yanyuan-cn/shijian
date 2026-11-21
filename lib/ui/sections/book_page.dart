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
  const BookPage({
    super.key,
    this.focusIndex = 0,
    this.focusNonce = 0,
  });

  final int focusIndex;
  final int focusNonce;

  Future<void> _open(BuildContext context, int i) async {
    final books = App.I.of(ST.book);
    if (i < 0 || i >= books.length) return;
    await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, a, __) => BookDetailPage(item: books[i]),
        transitionsBuilder: (_, a, __, child) {
          // cubic-bezier(.22, .61, .36, 1)
          final curved = CurvedAnimation(
            parent: a,
            curve: const Cubic(0.22, 0.61, 0.36, 1),
            reverseCurve: const Cubic(0.22, 0.61, 0.36, 1).flipped,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
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
        return ShelfView(
          books: books,
          onOpen: (i) => _open(context, i),
          onTap: (i) => _open(context, i),
          focusIndex: focusIndex,
          focusNonce: focusNonce,
        );
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
