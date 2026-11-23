import os
import math
import chess
import chess.engine
from src.software.domain.rules.scoring import NormalizedScore, compute_cpl
from src.software.domain.rules.classification import DEFAULT_THRESHOLDS, is_book_move, is_sacrifice
from src.software.core.logger import AnalysisLogger
from src.software.domain.rules.game_rules import get_material_sum, parse_pgn_game, PIECE_VALUES

def analyze_game_moves(pgn_str, engine_path, depth=20, callback=None,
                       thresholds=None, enable_logging=True, log_dir=None):
    """
    Analyzes a chess game with 8 categories: Brilliant, Best, Excellent, Good, Book,
    Inaccuracy, Mistake, Blunder.
    """
    game = parse_pgn_game(pgn_str)
    if not game:
        raise ValueError("Invalid PGN format or empty game.")

    if not os.path.exists(engine_path):
        raise FileNotFoundError(f"Stockfish engine not found at: {engine_path}")

    # Merge user thresholds with defaults
    t = dict(DEFAULT_THRESHOLDS)
    if thresholds:
        t.update(thresholds)

    logger = AnalysisLogger(enabled=enable_logging, log_dir=log_dir)
    engine = chess.engine.SimpleEngine.popen_uci(engine_path)
    limit = chess.engine.Limit(depth=depth)

    board = game.board()
    moves_analysis = []
    played_uci_history = []

    total_moves = len(list(game.mainline_moves()))

    white_cpls = []
    black_cpls = []

    for index, node in enumerate(game.mainline()):
        move = node.move
        color = board.turn
        side_is_white = (color == chess.WHITE)
        played_uci_history.append(move.uci())

        # ── Book move check ──
        if is_book_move(played_uci_history):
            move_san = board.san(move)
            board.push(move)

            dummy_eval = 0.3 if side_is_white else -0.3

            if side_is_white:
                white_cpls.append(0)
            else:
                black_cpls.append(0)

            moves_analysis.append({
                "move_num": (index // 2) + 1,
                "player": "White" if side_is_white else "Black",
                "move_str": move_san,
                "cpl": 0,
                "eval": round(dummy_eval, 2),
                "classification": "Book",
                "best_move": move_san,
                "best_eval": round(dummy_eval, 2),
                "best_pv": move_san,
                "is_mate_swing": False,
                "fen": board.fen(),
                "move_uci": move.uci(),
                "accuracy": 100.0
            })
            if callback:
                callback(index + 1, total_moves)
            continue

        # ── Step 1: Analyze BEFORE position ──
        fen_before = board.fen()
        material_before = get_material_sum(board)
        is_promotion = move.promotion is not None

        best_move_obj = None
        best_move_san = "None"
        best_score = NormalizedScore(chess.engine.PovScore(chess.engine.Cp(0), chess.WHITE))
        best_pv_str = ""
        is_best_move = False

        try:
            info_before = engine.analyse(board, limit)
            best_move_obj = info_before.get("pv", [None])[0]
            if best_move_obj:
                best_move_san = board.san(best_move_obj)
                is_best_move = (move == best_move_obj)
            best_score = NormalizedScore(info_before["score"])
            pv_moves = info_before.get("pv", [])
            pv_sans = []
            temp_board = board.copy()
            for pv_m in pv_moves[:5]:
                try:
                    pv_sans.append(temp_board.san(pv_m))
                    temp_board.push(pv_m)
                except Exception:
                    break
            best_pv_str = " ".join(pv_sans)
        except Exception:
            pass

        move_san = board.san(move)
        is_sac = is_sacrifice(board, move)

        # ── Step 2: Apply played move and analyze AFTER position ──
        board.push(move)
        is_checkmate = board.is_checkmate()
        material_after = get_material_sum(board)

        if is_promotion:
            promoted_piece = move.promotion
            expected_gain = PIECE_VALUES.get(promoted_piece, 0) - PIECE_VALUES[chess.PAWN]
            if side_is_white:
                actual_gain = material_after[0] - material_before[0]
            else:
                actual_gain = material_after[1] - material_before[1]
            if actual_gain < expected_gain - 50:
                print(f"[WARNING] Promotion sanity check failed at move {move_san}: "
                      f"expected gain ~{expected_gain}, actual {actual_gain}")

        played_score = NormalizedScore(chess.engine.PovScore(chess.engine.Cp(0), chess.WHITE))
        played_pv_str = ""
        
        if is_checkmate:
            played_score = NormalizedScore(chess.engine.PovScore(chess.engine.Mate(0), chess.WHITE if side_is_white else chess.BLACK))
        else:
            try:
                info_after = engine.analyse(board, limit)
                played_score = NormalizedScore(info_after["score"])
                pv_moves = info_after.get("pv", [])
                pv_sans = []
                temp_board = board.copy()
                for pv_m in pv_moves[:5]:
                    try:
                        pv_sans.append(temp_board.san(pv_m))
                        temp_board.push(pv_m)
                    except Exception:
                        break
                played_pv_str = " ".join(pv_sans)
            except Exception:
                pass

        # ── Step 3: Compute CPL ──
        if is_checkmate or is_best_move:
            cpl = 0
            is_mate_swing = False
        else:
            cpl_result = compute_cpl(best_score, played_score, side_is_white)
            cpl = cpl_result["cpl"]
            is_mate_swing = cpl_result["is_mate_swing"]

        # ── Win Probability Move Accuracy calculation ──
        def get_win_prob_pov(score, side_is_white_pov):
            if score.is_mate:
                is_favorable = (score.mate_in > 0 and side_is_white_pov) or (score.mate_in < 0 and not side_is_white_pov)
                if score.mate_in == 0:
                    return 100.0
                return 100.0 if is_favorable else 0.0
            cp_pov = score.cp if side_is_white_pov else -score.cp
            try:
                return 100.0 / (1.0 + math.exp(-0.00368208 * cp_pov))
            except OverflowError:
                return 100.0 if cp_pov > 0 else 0.0

        if is_checkmate or is_best_move:
            move_accuracy = 100.0
        else:
            wp_best = get_win_prob_pov(best_score, side_is_white)
            wp_played = get_win_prob_pov(played_score, side_is_white)
            wp_loss = max(0.0, wp_best - wp_played)
            move_accuracy = max(0.0, min(100.0, 100.0 - wp_loss))

        # ── Step 4: 8-Tier Classification ──
        if (is_best_move or is_checkmate) and is_sac:
            classification = "Brilliant"
        elif is_best_move or is_checkmate:
            classification = "Best"
        elif is_mate_swing:
            if cpl >= t["mistake_max"]:
                classification = "Blunder"
            else:
                classification = "Mistake"
        elif cpl <= t["excellent_max"]:
            classification = "Excellent"
        elif cpl <= t["good_max"]:
            classification = "Good"
        elif cpl <= t["inaccuracy_max"]:
            classification = "Inaccuracy"
        elif cpl <= t["mistake_max"]:
            classification = "Mistake"
        else:
            classification = "Blunder"

        # Apply flat vertical accuracy penalty for Mistakes and Blunders
        if classification == "Mistake":
            move_accuracy = min(40.0, move_accuracy)
        elif classification == "Blunder":
            move_accuracy = min(10.0, move_accuracy)

        if side_is_white:
            white_cpls.append(cpl)
        else:
            black_cpls.append(cpl)

        moves_analysis.append({
            "move_num": (index // 2) + 1,
            "player": "White" if side_is_white else "Black",
            "move_str": move_san,
            "cpl": cpl,
            "eval": played_score.to_report_value(),
            "classification": classification,
            "best_move": best_move_san,
            "best_eval": best_score.to_report_value(),
            "best_pv": best_pv_str,
            "is_mate_swing": is_mate_swing,
            "fen": board.fen(),
            "move_uci": move.uci(),
            "accuracy": round(move_accuracy, 1)
        })

        logger.log_move(
            move_index=index,
            fen_before=fen_before,
            move_san=move_san,
            move_uci=move.uci(),
            best_move_san=best_move_san,
            best_score_display=best_score.to_display(),
            best_pv=best_pv_str,
            played_score_display=played_score.to_display(),
            played_pv=played_pv_str,
            cpl=cpl,
            classification=classification,
            is_promotion=is_promotion,
            material_before={"white": material_before[0], "black": material_before[1]},
            material_after={"white": material_after[0], "black": material_after[1]}
        )

        if callback:
            callback(index + 1, total_moves)

    engine.quit()
    logger.save()

    # Statistics Tally
    white_stats = {"brilliant": 0, "best": 0, "excellent": 0, "good": 0, "book": 0, "inaccuracy": 0, "mistake": 0, "blunder": 0}
    black_stats = {"brilliant": 0, "best": 0, "excellent": 0, "good": 0, "book": 0, "inaccuracy": 0, "mistake": 0, "blunder": 0}
    
    for m in moves_analysis:
        key = m["classification"].lower()
        if m["player"] == "White":
            white_stats[key] += 1
        else:
            black_stats[key] += 1

    white_weighted_sum = 0.0
    white_weight_total = 0.0
    black_weighted_sum = 0.0
    black_weight_total = 0.0

    for m in moves_analysis:
        cls = m["classification"]
        acc = m["accuracy"]
        
        if cls == "Blunder":
            w = 6.0
        elif cls == "Mistake":
            w = 3.0
        elif cls == "Inaccuracy":
            w = 1.5
        else:
            w = 1.0

        if m["player"] == "White":
            white_weighted_sum += acc * w
            white_weight_total += w
        else:
            black_weighted_sum += acc * w
            black_weight_total += w

    white_accuracy = (white_weighted_sum / white_weight_total) if white_weight_total > 0 else 100.0
    black_accuracy = (black_weighted_sum / black_weight_total) if black_weight_total > 0 else 100.0

    return {
        "white_accuracy": round(white_accuracy, 1),
        "black_accuracy": round(black_accuracy, 1),
        "white_stats": white_stats,
        "black_stats": black_stats,
        "moves": moves_analysis,
        "analysis_log": logger.entries if enable_logging else []
    }
