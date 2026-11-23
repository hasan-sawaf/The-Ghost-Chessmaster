import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghostchessmaster/core/theme/app_theme.dart';
import 'package:ghostchessmaster/features/training/utils/chess_logic.dart';

List<List<String?>> _initialBoard() {
  return [
    ['BR', 'BN', 'BB', 'BQ', 'BK', 'BB', 'BN', 'BR'],
    ['BP', 'BP', 'BP', 'BP', 'BP', 'BP', 'BP', 'BP'],
    List<String?>.filled(8, null),
    List<String?>.filled(8, null),
    List<String?>.filled(8, null),
    List<String?>.filled(8, null),
    ['WP', 'WP', 'WP', 'WP', 'WP', 'WP', 'WP', 'WP'],
    ['WR', 'WN', 'WB', 'WQ', 'WK', 'WB', 'WN', 'WR'],
  ];
}

void main() {
  group('ChessLogic', () {
    test('starting position e2 pawn has 2 legal moves and converts e2e4 to SAN', () {
      final board = _initialBoard();
      // Row 6, col 4 is e2 in rank-8-top matrix
      final moves = ChessLogic.getLegalMoves(board, 6, 4, true);
      expect(moves, hasLength(2));
      expect(ChessLogic.toSan(board, 'e2e4'), equals('e4'));
      expect(ChessLogic.isKingInCheck(board, true), isFalse);
    });

    test('detects check on white king', () {
      final board = List.generate(8, (_) => List<String?>.filled(8, null));
      board[7][4] = 'WK';
      board[0][4] = 'BR';
      board[0][0] = 'BK';
      expect(ChessLogic.isKingInCheck(board, true), isTrue);
      expect(ChessLogic.isKingInCheck(board, false), isFalse);
    });
  });

  testWidgets('AppTheme renders GhostChessMaster MaterialApp cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(child: Text('GhostChessMaster')),
        ),
      ),
    );

    expect(find.text('GhostChessMaster'), findsOneWidget);
  });
}
