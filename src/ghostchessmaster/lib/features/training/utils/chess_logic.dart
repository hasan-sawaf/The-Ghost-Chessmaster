class ChessLogic {
  /// Checks if the king of color [isWhite] is currently in check.
  static bool isKingInCheck(List<List<String?>> board, bool isWhite) {
    int kingR = -1;
    int kingC = -1;
    final kingStr = isWhite ? 'WK' : 'BK';

    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        if (board[r][c] == kingStr) {
          kingR = r;
          kingC = c;
          break;
        }
      }
      if (kingR != -1) break;
    }

    if (kingR == -1) return false;

    final enemyPrefix = isWhite ? 'B' : 'W';
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = board[r][c];
        if (p != null && p.startsWith(enemyPrefix)) {
          final moves = getPseudoLegalMovesForColor(
            board,
            r,
            c,
            isWhite: !isWhite,
            allowCastling: false,
          );
          for (final m in moves) {
            if (m[0] == kingR && m[1] == kingC) return true;
          }
        }
      }
    }
    return false;
  }

  /// Returns strictly legal moves for a piece at (r, c).
  static List<List<int>> getLegalMoves(
    List<List<String?>> board,
    int r,
    int c,
    bool isWhiteTurn,
  ) {
    final piece = board[r][c];
    if (piece == null) return [];

    final isWhitePiece = piece.startsWith('W');
    if (isWhitePiece != isWhiteTurn) return [];

    final pseudo = getPseudoLegalMovesForColor(
      board,
      r,
      c,
      isWhite: isWhitePiece,
    );
    final strictlyLegal = <List<int>>[];
    final type = piece.substring(1);

    for (final m in pseudo) {
      final toR = m[0];
      final toC = m[1];
      final targetPiece = board[toR][toC];

      board[toR][toC] = piece;
      board[r][c] = null;

      // Temporarily move rook if castling
      String? rookPiece;
      int rookFromC = -1, rookToC = -1;
      if (type == 'K' && (c - toC).abs() == 2) {
        if (toC == 6) {
          rookFromC = 7;
          rookToC = 5;
        } else if (toC == 2) {
          rookFromC = 0;
          rookToC = 3;
        }
        if (rookFromC != -1) {
          rookPiece = board[r][rookFromC];
          board[r][rookToC] = rookPiece;
          board[r][rookFromC] = null;
        }
      }

      if (!isKingInCheck(board, isWhitePiece)) {
        strictlyLegal.add(m);
      }

      // Revert rook
      if (rookPiece != null) {
        board[r][rookFromC] = rookPiece;
        board[r][rookToC] = null;
      }

      // Revert king/piece
      board[r][c] = piece;
      board[toR][toC] = targetPiece;
    }
    return strictlyLegal;
  }

  /// Returns pseudo-legal moves for a piece at (r, c).
  static List<List<int>> getPseudoLegalMovesForColor(
    List<List<String?>> board,
    int r,
    int c, {
    required bool isWhite,
    bool allowCastling = true,
  }) {
    final piece = board[r][c];
    if (piece == null) return [];

    final moves = <List<int>>[];
    final type = piece.substring(1);

    bool isEnemy(int tr, int tc) {
      final target = board[tr][tc];
      if (target == null) return false;
      return isWhite ? target.startsWith('B') : target.startsWith('W');
    }

    bool isEmpty(int tr, int tc) => board[tr][tc] == null;
    bool inBounds(int tr, int tc) => tr >= 0 && tr < 8 && tc >= 0 && tc < 8;

    if (type == 'P') {
      final dir = isWhite ? -1 : 1;
      final startRank = isWhite ? 6 : 1;

      if (inBounds(r + dir, c) && isEmpty(r + dir, c)) {
        moves.add([r + dir, c]);
        if (r == startRank && isEmpty(r + (dir * 2), c)) {
          moves.add([r + (dir * 2), c]);
        }
      }
      for (final colOff in [-1, 1]) {
        final tc = c + colOff;
        if (inBounds(r + dir, tc) && isEnemy(r + dir, tc)) {
          moves.add([r + dir, tc]);
        }
      }
    } else if (type == 'N') {
      const offsets = [
        [-2, -1],
        [-2, 1],
        [-1, -2],
        [-1, 2],
        [1, -2],
        [1, 2],
        [2, -1],
        [2, 1],
      ];
      for (final off in offsets) {
        final tr = r + off[0];
        final tc = c + off[1];
        if (inBounds(tr, tc) && (isEmpty(tr, tc) || isEnemy(tr, tc))) {
          moves.add([tr, tc]);
        }
      }
    } else if (type == 'B' || type == 'R' || type == 'Q') {
      final directions = <List<int>>[];
      if (type == 'B' || type == 'Q') {
        directions.addAll([
          [-1, -1],
          [-1, 1],
          [1, -1],
          [1, 1],
        ]);
      }
      if (type == 'R' || type == 'Q') {
        directions.addAll([
          [-1, 0],
          [1, 0],
          [0, -1],
          [0, 1],
        ]);
      }

      for (final d in directions) {
        int tr = r + d[0];
        int tc = c + d[1];
        while (inBounds(tr, tc)) {
          if (isEmpty(tr, tc)) {
            moves.add([tr, tc]);
          } else if (isEnemy(tr, tc)) {
            moves.add([tr, tc]);
            break;
          } else {
            break;
          }
          tr += d[0];
          tc += d[1];
        }
      }
    } else if (type == 'K') {
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          final tr = r + dr;
          final tc = c + dc;
          if (inBounds(tr, tc) && (isEmpty(tr, tc) || isEnemy(tr, tc))) {
            moves.add([tr, tc]);
          }
        }
      }

      if (allowCastling) {
        // Cannot castle out of check
        if (!isKingInCheck(board, isWhite)) {
          final rank = isWhite ? 7 : 0;
          final rookStr = isWhite ? 'WR' : 'BR';

          if (r == rank && c == 4) {
            // Kingside O-O
            if (isEmpty(rank, 5) &&
                isEmpty(rank, 6) &&
                board[rank][7] == rookStr) {
              // Check transit square (rank, 5)
              board[rank][5] = piece;
              board[rank][4] = null;
              bool pathOk = !isKingInCheck(board, isWhite);
              board[rank][4] = piece;
              board[rank][5] = null;

              if (pathOk) moves.add([rank, 6]);
            }

            // Queenside O-O-O
            if (isEmpty(rank, 1) &&
                isEmpty(rank, 2) &&
                isEmpty(rank, 3) &&
                board[rank][0] == rookStr) {
              // Check transit square (rank, 3)
              board[rank][3] = piece;
              board[rank][4] = null;
              bool pathOk = !isKingInCheck(board, isWhite);
              board[rank][4] = piece;
              board[rank][3] = null;

              if (pathOk) moves.add([rank, 2]);
            }
          }
        }
      }
    }

    return moves;
  }

  /// Converts a move from UCI format (e.g. "e2e4") to Standard Algebraic Notation (SAN).
  static String toSan(List<List<String?>> board, String moveUci) {
    if (moveUci.length < 4) return moveUci;

    const files = 'abcdefgh';
    const ranks = '87654321';

    final fromC = files.indexOf(moveUci[0]);
    final fromR = ranks.indexOf(moveUci[1]);
    final toC = files.indexOf(moveUci[2]);
    final toR = ranks.indexOf(moveUci[3]);

    if (fromC == -1 || fromR == -1 || toC == -1 || toR == -1) return moveUci;

    final piece = board[fromR][fromC];
    if (piece == null) return moveUci;

    final type = piece.substring(1);
    final isWhite = piece.startsWith('W');
    final targetSq = '${files[toC]}${ranks[toR]}';

    bool isCapture = board[toR][toC] != null;
    if (type == 'P' && fromC != toC && board[toR][toC] == null) {
      isCapture = true; // En Passant capture
    }

    if (type == 'K' && (fromC - toC).abs() == 2) {
      String castleSan = (toC > fromC) ? 'O-O' : 'O-O-O';
      castleSan += _getCheckSuffix(
        board,
        fromR,
        fromC,
        toR,
        toC,
        piece,
        isWhite,
        moveUci,
      );
      return castleSan;
    }

    String san = '';

    if (type == 'P') {
      if (isCapture) san += '${files[fromC]}x';
      san += targetSq;

      if (moveUci.length == 5) {
        san += '=${moveUci[4].toUpperCase()}';
      }
    } else {
      san += type;

      // Disambiguation logic
      final candidates = <List<int>>[];
      for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
          if (r == fromR && c == fromC) continue;
          if (board[r][c] == piece) {
            final moves = getLegalMoves(board, r, c, isWhite);
            if (moves.any((m) => m[0] == toR && m[1] == toC)) {
              candidates.add([r, c]);
            }
          }
        }
      }

      if (candidates.isNotEmpty) {
        bool sameFile = candidates.any((c) => c[1] == fromC);
        bool sameRank = candidates.any((c) => c[0] == fromR);

        if (!sameFile) {
          san += files[fromC];
        } else if (!sameRank) {
          san += ranks[fromR];
        } else {
          san += '${files[fromC]}${ranks[fromR]}';
        }
      }

      if (isCapture) san += 'x';
      san += targetSq;
    }

    san += _getCheckSuffix(
      board,
      fromR,
      fromC,
      toR,
      toC,
      piece,
      isWhite,
      moveUci,
    );
    return san;
  }

  static String _getCheckSuffix(
    List<List<String?>> board,
    int fromR,
    int fromC,
    int toR,
    int toC,
    String piece,
    bool isWhite,
    String moveUci,
  ) {
    final targetPiece = board[toR][toC];
    final type = piece.substring(1);

    String placedPiece = piece;
    if (type == 'P' && moveUci.length == 5) {
      placedPiece = (isWhite ? 'W' : 'B') + moveUci[4].toUpperCase();
    }

    board[toR][toC] = placedPiece;
    board[fromR][fromC] = null;

    int epPawnR = -1, epPawnC = -1;
    String? epPawnPiece;
    if (type == 'P' && fromC != toC && targetPiece == null) {
      epPawnR = fromR;
      epPawnC = toC;
      epPawnPiece = board[epPawnR][epPawnC];
      board[epPawnR][epPawnC] = null;
    }

    String? rookPiece;
    int rookFromC = -1, rookToC = -1;
    if (type == 'K' && (fromC - toC).abs() == 2) {
      if (toC == 6) {
        rookFromC = 7;
        rookToC = 5;
      } else if (toC == 2) {
        rookFromC = 0;
        rookToC = 3;
      }
      if (rookFromC != -1) {
        rookPiece = board[fromR][rookFromC];
        board[fromR][rookToC] = rookPiece;
        board[fromR][rookFromC] = null;
      }
    }

    bool isCheck = isKingInCheck(board, !isWhite);
    bool isMate = false;

    if (isCheck) {
      isMate = true;
      for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
          final p = board[r][c];
          if (p != null && (isWhite ? p.startsWith('B') : p.startsWith('W'))) {
            if (getLegalMoves(board, r, c, !isWhite).isNotEmpty) {
              isMate = false;
              break;
            }
          }
        }
        if (!isMate) break;
      }
    }

    // Revert temporary state
    if (rookPiece != null) {
      board[fromR][rookFromC] = rookPiece;
      board[fromR][rookToC] = null;
    }
    if (epPawnPiece != null) {
      board[epPawnR][epPawnC] = epPawnPiece;
    }
    board[fromR][fromC] = piece;
    board[toR][toC] = targetPiece;

    if (isMate) return '#';
    if (isCheck) return '+';
    return '';
  }

  static List<List<int>> getLegalMovesForColor(
    List<List<String?>> board,
    int r,
    int c, {
    required bool isWhite,
  }) {
    return getLegalMoves(board, r, c, isWhite);
  }
}
