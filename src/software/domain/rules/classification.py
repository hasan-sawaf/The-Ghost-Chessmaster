import chess
from .game_rules import PIECE_VALUES

DEFAULT_THRESHOLDS = {
    "excellent_max": 15,     # CPL 0-15 = Excellent
    "good_max": 30,          # CPL 16-30 = Good
    "inaccuracy_max": 100,   # CPL 31-100 = Inaccuracy
    "mistake_max": 300,      # CPL 101-300 = Mistake
}

BOOK_LINES = [
    # --- OPEN GAMES (1.e4 e5) ---
    ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5"],                                                             # Ruy Lopez (Spanish Opening)
    ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6", "b5a4", "g8f6", "e1g1", "f8e7", "f1e1", "b7b5", "a4b3", "d7d6", "c2c3", "e8g8", "h2h3"], # Ruy Lopez: Closed Main Line
    ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6", "b5c6"],                                             # Ruy Lopez: Exchange Variation
    ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "g8f6"],                                                     # Ruy Lopez: Berlin Defense
    ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "f7f5"],                                                     # Ruy Lopez: Schliemann Defense
    ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6", "b5a4", "g8f6", "e1g1", "f8e7", "f1e1", "b7b5", "a4b3", "e8g8", "c2c3", "d7d5"], # Ruy Lopez: Marshall Attack
    ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6", "b5a4", "g8f6", "e1g1", "f8e7", "f1e1", "b7b5", "a4b3", "d7d6", "c2c3", "e8g8", "h2h3", "c6a5", "b3c2", "c7c5", "d2d4", "d8c7"], # Ruy Lopez: Chigorin Variation
    ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6", "b5a4", "g8f6", "e1g1", "f8e7", "f1e1", "b7b5", "a4b3", "d7d6", "c2c3", "e8g8", "h2h3", "c6b8"], # Ruy Lopez: Breyer Variation
    ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6", "b5a4", "g8f6", "e1g1", "b7b5", "a4b3", "c8b7"],       # Ruy Lopez: Archangel Defense
    ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6", "b5a4", "g8f6", "e1g1", "f6e4", "d2d4", "b7b5", "a4b3", "d7d5", "d4e5", "c8e6"], # Ruy Lopez: Open Variation
    ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4"],                                                             # Italian Game
    ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5"],                                                     # Italian Game: Giuoco Piano
    ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5", "b2b4"],                                             # Italian Game: Evans Gambit
    ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5", "b2b4", "c5b4", "c2c3", "b4a5"],                     # Evans Gambit Accepted: Main Line
    ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "g8f6"],                                                     # Italian Game: Two Knights Defense
    ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "g8f6", "f3g5", "d7d5", "e4d5", "f6d5", "g5f7", "e8f7"],       # Two Knights: Fried Liver Attack
    ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "g8f6", "d2d4", "e5d4", "e1g1", "f8c5", "e4e5"],             # Max Lange Attack
    ["e2e4", "e7e5", "g1f3", "b8c6", "d2d4"],                                                             # Scotch Game
    ["e2e4", "e7e5", "g1f3", "b8c6", "d2d4", "e5d4", "f3d4"],                                             # Scotch Game: Main Line
    ["e2e4", "e7e5", "g1f3", "b8c6", "d2d4", "e5d4", "f1c4"],                                             # Scotch Gambit
    ["e2e4", "e7e5", "g1f3", "b8c6", "b1c3", "g8f6"],                                                     # Four Knights Game
    ["e2e4", "e7e5", "g1f3", "b8c6", "b1c3", "g8f6", "d2d4"],                                             # Four Knights: Scotch Variation
    ["e2e4", "e7e5", "g1f3", "b8c6", "b1c3", "g8f6", "f1b5"],                                             # Four Knights: Spanish Variation
    ["e2e4", "e7e5", "g1f3", "g8f6"],                                                                     # Petrov's Defense (Russian Game)
    ["e2e4", "e7e5", "g1f3", "g8f6", "f3e5", "d7d6", "e5f3", "f6e4", "d2d4", "d7d5"],                     # Petrov: Classical Attack
    ["e2e4", "e7e5", "g1f3", "g8f6", "d2d4", "e5d4", "e4e5", "f6e4"],                                     # Petrov: Steinitz Attack
    ["e2e4", "e7e5", "g1f3", "d7d6"],                                                                     # Philidor Defense
    ["e2e4", "e7e5", "b1c3"],                                                                             # Vienna Game
    ["e2e4", "e7e5", "b1c3", "g8f6", "f2f4", "d7d5"],                                                     # Vienna Gambit: Main Line
    ["e2e4", "e7e5", "f2f4"],                                                                             # King's Gambit
    ["e2e4", "e7e5", "f2f4", "e5f4", "g1f3", "g7g5"],                                                     # King's Gambit Accepted: Classical Variation
    ["e2e4", "e7e5", "f2f4", "e5f4", "f1c4"],                                                             # King's Gambit Accepted: Bishop's Gambit
    ["e2e4", "e7e5", "f2f4", "d7d5"],                                                                     # King's Gambit Declined: Falkbeer Countergambit
    ["e2e4", "e7e5", "d2d4", "e5d4", "d1d4"],                                                             # Center Game
    ["e2e4", "e7e5", "d2d4", "e5d4", "c2c3", "d4c3", "f1c4"],                                             # Danish Gambit
    # --- SEMI-OPEN GAMES (1.e4, Black replies with non-e5) ---
    ["e2e4", "c7c5"],                                                                                     # Sicilian Defense
    ["e2e4", "c7c5", "g1f3", "d7d6", "d2d4", "c5d4", "f3d4", "g8f6", "b1c3"],                             # Open Sicilian
    ["e2e4", "c7c5", "g1f3", "d7d6", "d2d4", "c5d4", "f3d4", "g8f6", "b1c3", "a7a6"],                     # Sicilian Najdorf
    ["e2e4", "c7c5", "g1f3", "d7d6", "d2d4", "c5d4", "f3d4", "g8f6", "b1c3", "g7g6"],                     # Sicilian Dragon
    ["e2e4", "c7c5", "c2c3"],                                                                             # Sicilian Alapin (Anti-Sicilian)
    ["e2e4", "c7c5", "b1c3", "b8c6", "g2g3"],                                                             # Closed Sicilian
    ["e2e4", "c7c5", "g1f3", "b8c6", "f1b5"],                                                             # Sicilian Rossolimo Variation
    ["e2e4", "e7e6"],                                                                                     # French Defense
    ["e2e4", "e7e6", "d2d4", "d7d5", "e4e5"],                                                             # French Defense: Advance Variation
    ["e2e4", "e7e6", "d2d4", "d7d5", "b1c3", "g8f6"],                                                     # French Defense: Classical Variation
    ["e2e4", "e7e6", "d2d4", "d7d5", "b1d2"],                                                             # French Defense: Tarrasch Variation
    ["e2e4", "c7c6"],                                                                                     # Caro-Kann Defense
    ["e2e4", "c7c6", "d2d4", "d7d5", "e4e5"],                                                             # Caro-Kann: Advance Variation
    ["e2e4", "c7c6", "d2d4", "d7d5", "b1c3", "d5e4", "c3e4", "c8f5"],                                     # Caro-Kann: Classical Variation
    ["e2e4", "d7d5"],                                                                                     # Scandinavian Defense
    ["e2e4", "d7d6", "d2d4", "g8f6", "b1c3", "g7g6"],                                                     # Pirc Defense
    ["e2e4", "g7g6", "d2d4", "f8g7"],                                                                     # Modern Defense
    ["e2e4", "g8f6"],                                                                                     # Alekhine's Defense
    # --- CLOSED GAMES & QUEEN'S PAWN (1.d4 d5) ---
    ["d2d4", "d7d5"],                                                                                     # Closed Game
    ["d2d4", "d7d5", "c2c4"],                                                                             # Queen's Gambit
    ["d2d4", "d7d5", "c2c4", "d5c4"],                                                                     # Queen's Gambit Accepted (QGA)
    ["d2d4", "d7d5", "c2c4", "e7e6"],                                                                     # Queen's Gambit Declined (QGD)
    ["d2d4", "d7d5", "c2c4", "e7e6", "b1c3", "g8f6"],                                                     # QGD: Orthodox Defense
    ["d2d4", "d7d5", "c2c4", "c7c6"],                                                                     # Slav Defense
    ["d2d4", "d7d5", "c2c4", "c7c6", "g1f3", "g8f6", "b1c3", "e7e6"],                                     # Semi-Slav Defense
    ["d2d4", "d7d5", "g1f3", "g8f6", "c1f4"],                                                             # London System
    ["d2d4", "d7d5", "g1f3", "g8f6", "e2e3", "e7e6", "f1d3", "c7c5", "c2c3"],                             # Colle System
    # --- INDIAN DEFENSES (1.d4 Nf6) ---
    ["d2d4", "g8f6"],                                                                                     # Indian Defense
    ["d2d4", "g8f6", "c2c4", "g7g6", "b1c3", "f8g7", "e2e4", "d7d6"],                                     # King's Indian Defense (KID)
    ["d2d4", "g8f6", "c2c4", "g7g6", "b1c3", "d7d5"],                                                     # Grünfeld Defense
    ["d2d4", "g8f6", "c2c4", "e7e6", "b1c3", "f1b4"],                                                     # Nimzo-Indian Defense
    ["d2d4", "g8f6", "c2c4", "e7e6", "g1f3", "b7b6"],                                                     # Queen's Indian Defense (QID)
    ["d2d4", "g8f6", "c2c4", "c7c5", "d4d5", "e7e6"],                                                     # Modern Benoni
    ["d2d4", "g8f6", "c2c4", "c7c5", "d4d5", "b7b5"],                                                     # Benko Gambit (Volga Gambit)
    ["d2d4", "g8f6", "c1g5"],                                                                             # Trompowsky Attack
    # --- FLANK OPENINGS ---
    ["c2c4"],                                                                                             # English Opening
    ["c2c4", "e7e5", "b1c3"],                                                                             # English: Reversed Sicilian
    ["g1f3"],                                                                                             # Réti Opening
    ["g1f3", "d7d5", "c2c4"],                                                                             # Réti Gambit
    ["f2f4"],                                                                                             # Bird's Opening
    ["b2b3"],                                                                                             # Nimzowitsch-Larsen Attack
]

def is_book_move(played_uci_history):
    """Checks if the played moves history matches a standard opening book prefix."""
    for line in BOOK_LINES:
        if len(played_uci_history) <= len(line):
            if line[:len(played_uci_history)] == played_uci_history:
                return True
    return False

def is_sacrifice(board_before, move):
    """
    Detects if the move is a tactical piece sacrifice (Knight/Bishop/Rook/Queen).
    Excludes standard equal-value exchanges.
    """
    color = board_before.turn
    piece_type = board_before.piece_type_at(move.from_square)

    if piece_type in [chess.KNIGHT, chess.BISHOP, chess.ROOK, chess.QUEEN]:
        to_sq = move.to_square
        opp_color = not color

        attackers = board_before.attackers(opp_color, to_sq)
        for attacker_sq in attackers:
            attacker_type = board_before.piece_type_at(attacker_sq)
            if attacker_type and PIECE_VALUES[attacker_type] < PIECE_VALUES[piece_type]:
                if board_before.is_capture(move):
                    captured_type = board_before.piece_type_at(to_sq)
                    if captured_type and PIECE_VALUES[captured_type] >= PIECE_VALUES[piece_type]:
                        continue
                return True

        defenders = board_before.attackers(color, to_sq)
        if len(attackers) > 0 and len(defenders) == 0:
            if board_before.is_capture(move):
                captured_type = board_before.piece_type_at(to_sq)
                if captured_type and PIECE_VALUES[captured_type] >= PIECE_VALUES[piece_type]:
                    pass
                else:
                    return True
            else:
                return True

    if board_before.is_capture(move):
        captured_type = board_before.piece_type_at(move.to_square)
        if captured_type and piece_type:
            if PIECE_VALUES[captured_type] < PIECE_VALUES[piece_type] - 100:
                opp_color = not color
                temp = board_before.copy()
                temp.push(move)
                attackers_after = temp.attackers(opp_color, move.to_square)
                if len(attackers_after) > 0:
                    return True

    return False
