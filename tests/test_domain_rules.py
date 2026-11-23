import os
import sys
import unittest
import chess
import chess.engine

from src.software.core.config import ENGINE_PATH
from src.software.domain.rules.classification import is_book_move
from src.software.domain.rules.game_rules import (
    get_mate_phrase,
    get_material_sum,
    parse_pgn_game,
)
from src.software.domain.rules.scoring import (
    NormalizedScore,
    compute_cpl,
    compute_win_probability,
)
from src.software.application.use_cases.analyze_match import analyze_game_moves
from src.software.infrastructure.firebase.firebase_manager import FirebaseManager


class TestDomainRules(unittest.TestCase):
    def test_normalized_score_and_cpl(self):
        best = NormalizedScore(chess.engine.PovScore(chess.engine.Cp(150), chess.WHITE))
        played = NormalizedScore(chess.engine.PovScore(chess.engine.Cp(80), chess.WHITE))
        self.assertEqual(best.to_display(), "+1.50")
        cpl_res = compute_cpl(best, played, side_is_white=True)
        self.assertEqual(cpl_res["cpl"], 70)
        self.assertFalse(res_swing := cpl_res["is_mate_swing"])
        self.assertFalse(res_swing)

        even = NormalizedScore(chess.engine.PovScore(chess.engine.Cp(0), chess.WHITE))
        self.assertAlmostEqual(compute_win_probability(even), 0.5, places=4)

    def test_mate_swing_detection(self):
        mate_for_white = NormalizedScore(chess.engine.PovScore(chess.engine.Mate(2), chess.WHITE))
        cp_score = NormalizedScore(chess.engine.PovScore(chess.engine.Cp(200), chess.WHITE))
        res = compute_cpl(mate_for_white, cp_score, side_is_white=True)
        self.assertTrue(res["is_mate_swing"])
        self.assertTrue(res["mate_lost"])
        self.assertEqual(res["cpl"], 800)

    def test_book_moves_and_pgn_parsing(self):
        self.assertTrue(is_book_move(["e2e4", "e7e5", "g1f3"]))
        self.assertFalse(is_book_move(["a2a4", "h7h5"]))

        game = parse_pgn_game("1. e4 e5 2. Nf3 Nc6")
        self.assertIsNotNone(game)
        moves = list(game.mainline_moves())
        self.assertEqual(len(moves), 4)

    def test_material_sum_and_mate_phrase(self):
        board = chess.Board()
        white_mat, black_mat = get_material_sum(board)
        self.assertEqual(white_mat, 3900)
        self.assertEqual(black_mat, 3900)
        self.assertEqual(get_mate_phrase("White", "#3", "+1.20"), "missed forced checkmate")
        self.assertEqual(get_mate_phrase("White", "+0.50", "#-2"), "allowed forced checkmate")

    def test_firebase_manager_placeholder_graceful_fallback(self):
        fm = FirebaseManager()
        self.assertFalse(fm.connected)
        self.assertTrue(bool(fm.board_id))

    def test_stockfish_match_analysis_smoke(self):
        if sys.platform != "win32":
            self.skipTest("Bundled Stockfish binary is Windows x86-64")
        if not os.path.exists(ENGINE_PATH):
            self.skipTest("Stockfish binary not present in expected path")
        results = analyze_game_moves(
            "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6",
            ENGINE_PATH,
            depth=6,
            enable_logging=False,
        )
        self.assertIsInstance(results, dict)
        self.assertEqual(len(results["moves"]), 6)
        self.assertGreater(results["white_accuracy"], 0)


if __name__ == "__main__":
    unittest.main()
