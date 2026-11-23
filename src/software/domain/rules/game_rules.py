import chess
import chess.pgn
import io

PIECE_VALUES = {
    chess.PAWN: 100,
    chess.KNIGHT: 300,
    chess.BISHOP: 300,
    chess.ROOK: 500,
    chess.QUEEN: 900,
    chess.KING: 0
}

def get_material_sum(board):
    """Calculates total material value for both sides. Used for promotion sanity checks."""
    white_mat = 0
    black_mat = 0
    for sq in chess.SQUARES:
        piece = board.piece_at(sq)
        if piece:
            val = PIECE_VALUES.get(piece.piece_type, 0)
            if piece.color == chess.WHITE:
                white_mat += val
            else:
                black_mat += val
    return white_mat, black_mat

def parse_pgn_game(pgn_str):
    """Parses a PGN string into a chess.pgn.Game object."""
    pgn_io = io.StringIO(pgn_str.strip())
    return chess.pgn.read_game(pgn_io)

def get_mate_phrase(player, best_eval, played_eval):
    """Detects if player missed or allowed checkmate based on evaluation comparison."""
    best_mate = None
    if isinstance(best_eval, str) and '#' in best_eval:
        try:
            best_mate = int(best_eval.replace('#', '').replace(' ', ''))
        except ValueError:
            pass

    played_mate = None
    if isinstance(played_eval, str) and '#' in played_eval:
        try:
            played_mate = int(played_eval.replace('#', '').replace(' ', ''))
        except ValueError:
            pass

    had_forced_mate = False
    if best_mate is not None:
        if player == "White" and best_mate > 0:
            had_forced_mate = True
        elif player == "Black" and best_mate < 0:
            had_forced_mate = True

    opponent_has_forced_mate = False
    if played_mate is not None:
        if player == "White" and played_mate < 0:
            opponent_has_forced_mate = True
        elif player == "Black" and played_mate > 0:
            opponent_has_forced_mate = True

    if had_forced_mate and not opponent_has_forced_mate:
        return "missed forced checkmate"
    elif not had_forced_mate and opponent_has_forced_mate:
        return "allowed forced checkmate"
    return "missed/allowed checkmate"
