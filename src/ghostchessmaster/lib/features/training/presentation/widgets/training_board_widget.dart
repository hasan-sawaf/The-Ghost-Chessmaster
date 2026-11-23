import 'package:flutter/material.dart';
import 'package:ghostchessmaster/core/services/chess_sound_service.dart';
import 'package:ghostchessmaster/core/theme/app_colors.dart';
import 'package:ghostchessmaster/core/utils/load_images.dart';
import 'package:ghostchessmaster/features/settings/presentation/bloc/settings_state.dart';

class TrainingBoardWidget extends StatelessWidget {
  final List<List<String?>> boardState;
  final SettingsState settingsState;
  final int? selectedRow;
  final int? selectedCol;
  final List<List<int>> legalDestinations;
  final int? lastMoveFromRow;
  final int? lastMoveFromCol;
  final int? lastMoveToRow;
  final int? lastMoveToCol;
  final int? hintFromRow;
  final int? hintFromCol;
  final int? hintToRow;
  final int? hintToCol;
  final bool Function(bool isWhite) isKingInCheck;
  final bool isBoardFlipped;
  final String? classificationIconPath;
  final int? classificationRow;
  final int? classificationCol;
  final void Function(int row, int col) onSquareTapped;

  const TrainingBoardWidget({
    super.key,
    required this.boardState,
    required this.settingsState,
    required this.selectedRow,
    required this.selectedCol,
    required this.legalDestinations,
    required this.lastMoveFromRow,
    required this.lastMoveFromCol,
    required this.lastMoveToRow,
    required this.lastMoveToCol,
    required this.hintFromRow,
    required this.hintFromCol,
    required this.hintToRow,
    required this.hintToCol,
    required this.isKingInCheck,
    this.isBoardFlipped = false,
    this.classificationIconPath,
    this.classificationRow,
    this.classificationCol,
    this.overridePieceTheme,
    required this.onSquareTapped,
  });

  final String? overridePieceTheme;

  String? _getPieceAssetPath(int row, int col) {
    final piece = boardState[row][col];
    if (piece == null) return null;
    final theme = (overridePieceTheme != null && overridePieceTheme!.isNotEmpty)
        ? overridePieceTheme!
        : settingsState.pieceTheme;
    return AppImageHelper.getPieceAssetPath(theme, piece);
  }

  @override
  Widget build(BuildContext context) {
    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    const ranks = ['8', '7', '6', '5', '4', '3', '2', '1'];

    final borderColor = settingsState.isDarkMode
        ? AppColors.primaryGold
        : AppColors.primaryMahogany;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 3.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
              ),
              itemCount: 64,
              itemBuilder: (context, index) {
                final r = index ~/ 8;
                final c = index % 8;
                final row = isBoardFlipped ? 7 - r : r;
                final col = isBoardFlipped ? 7 - c : c;
                final isLightSquare = (row + col) % 2 == 0;
                final pieceAsset = _getPieceAssetPath(row, col);

                final isSelected = (row == selectedRow && col == selectedCol);
                final isLegalDest = legalDestinations.any(
                  (d) => d[0] == row && d[1] == col,
                );
                final isCaptureDest =
                    isLegalDest && boardState[row][col] != null;
                final isLastMoveFrom =
                    (row == lastMoveFromRow && col == lastMoveFromCol);
                final isLastMoveTo =
                    (row == lastMoveToRow && col == lastMoveToCol);
                final isHintFrom = (row == hintFromRow && col == hintFromCol);
                final isHintTo = (row == hintToRow && col == hintToCol);

                final isCheckedKing =
                    pieceAsset != null &&
                    boardState[row][col] != null &&
                    boardState[row][col]!.endsWith('K') &&
                    ((boardState[row][col] == 'WK' && isKingInCheck(true)) ||
                        (boardState[row][col] == 'BK' && isKingInCheck(false)));

                // Dynamic Square Colors
                Color squareColor;
                if (isCaptureDest) {
                  squareColor = const Color(0xDDE53935);
                } else if (isSelected) {
                  squareColor = const Color(0xAAFFB300);
                } else if (isLastMoveFrom) {
                  squareColor = const Color(0x99FFA726);
                } else if (isLastMoveTo) {
                  squareColor = const Color(0x9966BB6A);
                } else if (isHintFrom) {
                  squareColor = const Color(0x99FB8C00);
                } else if (isHintTo) {
                  squareColor = const Color(0x994CAF50);
                } else {
                  squareColor = isLightSquare
                      ? (settingsState.isDarkMode
                            ? AppColors.darkSquareLight
                            : AppColors.lightSquareLight)
                      : (settingsState.isDarkMode
                            ? AppColors.darkSquareDark
                            : AppColors.lightSquareDark);
                }

                // Coordinates indicators
                final showFileLabel = r == 7;
                final showRankLabel = c == 0;
                final labelColor = isLightSquare
                    ? (settingsState.isDarkMode
                          ? AppColors.darkSquareDark
                          : AppColors.lightSquareDark)
                    : (settingsState.isDarkMode
                          ? AppColors.darkSquareLight
                          : AppColors.lightSquareLight);

                final squareWidget = InkWell(
                  onTap: () => onSquareTapped(row, col),
                  child: Container(
                    color: squareColor,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // --- Checked King Aura ---
                        if (isCheckedKing)
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.red.shade700,
                                  Colors.red.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                          ),

                        // --- Piece Asset (Draggable) ---
                        if (pieceAsset != null)
                          Draggable<Map<String, int>>(
                            data: {'row': row, 'col': col},
                            onDragStarted: () {
                              if (selectedRow != row || selectedCol != col) {
                                onSquareTapped(row, col);
                              }
                            },
                            feedback: Material(
                              color: Colors.transparent,
                              child: Container(
                                width: 54,
                                height: 54,
                                padding: const EdgeInsets.all(2.0),
                                child: Image.asset(
                                  pieceAsset,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.25,
                              child: Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: Image.asset(
                                  pieceAsset,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(3.0),
                              child: Image.asset(
                                pieceAsset,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                          ),

                        // --- Non-Capture Legal Move Dot ---
                        if (isLegalDest && !isCaptureDest)
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xDD2E7D32),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 4),
                              ],
                            ),
                          ),

                        // --- Capture Destination Overlay Ring ---
                        if (isCaptureDest)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 3),
                              shape: BoxShape.circle,
                            ),
                          ),

                        // --- Hint Highlight Borders ---
                        if (isHintFrom)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFFF9800),
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        if (isHintTo)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF4CAF50),
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),

                        // --- Classification Icon Overlay (Top-Right of Piece) ---
                        if (classificationIconPath != null &&
                            AppImageHelper.getClassificationIconPath(classificationIconPath) != null &&
                            row == classificationRow &&
                            col == classificationCol)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.black26,
                                  width: 0.8,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  AppImageHelper.getClassificationIconPath(classificationIconPath)!,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                          ),

                        // --- File Labels (a-h) ---
                        if (showFileLabel)
                          Positioned(
                            bottom: 2,
                            right: 3,
                            child: Text(
                              files[col],
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: labelColor.withValues(alpha: 0.85),
                              ),
                            ),
                          ),

                        // --- Rank Labels (1-8) ---
                        if (showRankLabel)
                          Positioned(
                            top: 2,
                            left: 3,
                            child: Text(
                              ranks[row],
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: labelColor.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );

                return DragTarget<Map<String, int>>(
                  onWillAcceptWithDetails: (_) => true,
                  onAcceptWithDetails: (details) {
                    final fromRow = details.data['row'];
                    final fromCol = details.data['col'];
                    if (fromRow == null || fromCol == null) return;
                    if (fromRow == row && fromCol == col) return;

                    // Check if target is a legal destination
                    final isLegal = legalDestinations.any((d) => d[0] == row && d[1] == col);
                    if (!isLegal) {
                      ChessSoundService.instance.playIllegal(settingsState.isSoundEnabled);
                    }

                    // Ensure origin piece was selected
                    if (selectedRow != fromRow || selectedCol != fromCol) {
                      onSquareTapped(fromRow, fromCol);
                    }
                    // Trigger move to destination square
                    onSquareTapped(row, col);
                  },
                  builder: (context, candidateData, rejectedData) => squareWidget,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
