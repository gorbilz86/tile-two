import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tile_two/ui/game_buttons.dart';

Widget _buildButtons({
  required int undoStock,
  required int shuffleStock,
  required int hintStock,
  bool shuffleUnlocked = true,
  bool hintUnlocked = true,
}) {
  return MaterialApp(
    home: Center(
      child: GameButtons(
        onUndo: () {},
        onShuffle: () {},
        onHint: () {},
        undoStock: undoStock,
        shuffleStock: shuffleStock,
        hintStock: hintStock,
        shuffleUnlocked: shuffleUnlocked,
        hintUnlocked: hintUnlocked,
        shuffleUnlockLevel: 5,
        hintUnlockLevel: 8,
      ),
    ),
  );
}

void main() {
  group('resolveBoosterBadgeMode', () {
    test('mengembalikan locked saat booster belum terbuka', () {
      final mode = resolveBoosterBadgeMode(isUnlocked: false, stock: 7);
      expect(mode, BoosterBadgeMode.locked);
    });

    test('mengembalikan stock saat stock lebih dari 0', () {
      final mode = resolveBoosterBadgeMode(isUnlocked: true, stock: 2);
      expect(mode, BoosterBadgeMode.stock);
    });

    test('mengembalikan price saat stock habis', () {
      final mode = resolveBoosterBadgeMode(isUnlocked: true, stock: 0);
      expect(mode, BoosterBadgeMode.price);
    });
  });

  group('GameButtons stock display', () {
    testWidgets('menampilkan harga coin saat semua stock = 0', (tester) async {
      await tester.pumpWidget(
        _buildButtons(
          undoStock: 0,
          shuffleStock: 0,
          hintStock: 0,
        ),
      );

      expect(find.text('45'), findsOneWidget);
      expect(find.text('55'), findsOneWidget);
      expect(find.text('35'), findsOneWidget);
    });

    testWidgets('menampilkan stock saat stock > 0', (tester) async {
      await tester.pumpWidget(
        _buildButtons(
          undoStock: 3,
          shuffleStock: 2,
          hintStock: 1,
        ),
      );

      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('45'), findsNothing);
      expect(find.text('55'), findsNothing);
      expect(find.text('35'), findsNothing);
    });

    testWidgets(
      'display independen per item sesuai stock masing-masing',
      (tester) async {
        await tester.pumpWidget(
          _buildButtons(
            undoStock: 2,
            shuffleStock: 0,
            hintStock: 5,
          ),
        );

        expect(find.text('2'), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
        expect(find.text('55'), findsOneWidget);
        expect(find.text('45'), findsNothing);
        expect(find.text('35'), findsNothing);
      },
    );

    testWidgets('display berubah dinamis setelah transaksi pembelian item', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildButtons(
          undoStock: 1,
          shuffleStock: 0,
          hintStock: 0,
        ),
      );

      expect(find.text('55'), findsOneWidget);
      expect(find.text('35'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      await tester.pumpWidget(
        _buildButtons(
          undoStock: 1,
          shuffleStock: 3,
          hintStock: 2,
        ),
      );
      await tester.pump();

      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('55'), findsNothing);
      expect(find.text('35'), findsNothing);
    });
  });
}
