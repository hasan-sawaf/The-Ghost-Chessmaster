import tkinter as tk
from tkinter import ttk, scrolledtext, simpledialog, messagebox
import threading
import os
import sys
import base64
import io
import time
import queue
from PIL import Image, ImageTk

class AnalysisMixin:
    def register_live_move(self, uci_move, player_color):
        """Called by CV Bridge whenever a user/AI move registers to analyze it and push to Firebase."""
        self.live_game_moves.append(uci_move)
        self.log(f"[Live Analysis] Registered move {len(self.live_game_moves)}: {uci_move} ({player_color})")
        
        # Compute current FEN and push to Firebase RTDB under {board_name}/current_match (Physical App Mode only)
        try:
            if hasattr(self, "firebase_manager") and self.firebase_manager and getattr(self, "is_physical_app_mode", False):
                import chess
                board = chess.Board()
                for m_str in self.live_game_moves:
                    try:
                        board.push(chess.Move.from_uci(m_str))
                    except Exception:
                        break
                current_fen = board.fen()
                self.firebase_manager.push_move(uci_move, current_fen, player_color)
        except Exception as fb_err:
            self.log(f"[Firebase Error] Failed pushing move {uci_move}: {fb_err}")

        # Trigger auto-save if configured
        if hasattr(self, "auto_save_game"):
            self.auto_save_game()

        # Spawn background analysis worker thread
        threading.Thread(
            target=self._analyze_live_move_worker,
            args=(uci_move, player_color, list(self.live_game_moves)),
            daemon=True
        ).start()

    def _analyze_live_move_worker(self, uci_move, player_color, move_history_list):
        import chess
        import chess.engine
        try:
            if not hasattr(self, "live_analysis_engine") or self.live_analysis_engine.transport.is_closing():
                self.live_analysis_engine = chess.engine.SimpleEngine.popen_uci(self.engine_path)

            # Reconstruct the chess board before the last move
            board = chess.Board()
            for m_str in move_history_list[:-1]:
                board.push(chess.Move.from_uci(m_str))

            # Analyze BEFORE position to get best move & ELO score
            limit = chess.engine.Limit(depth=12) # Fast depth 12 search
            info_before = self.live_analysis_engine.analyse(board, limit)

            pv_before = info_before.get("pv", [])
            best_move_obj = pv_before[0] if pv_before else None
            best_move_san = board.san(best_move_obj) if best_move_obj else "None"

            from src.software.domain.rules.scoring import NormalizedScore, compute_cpl
            best_score = NormalizedScore(info_before["score"])

            # Push played move to analyze AFTER position
            played_move_obj = chess.Move.from_uci(uci_move)
            played_move_san = board.san(played_move_obj) if played_move_obj in board.legal_moves else uci_move
            is_best_move = (played_move_obj == best_move_obj)

            # Sacrifice check
            from src.software.domain.rules.classification import is_sacrifice
            is_sac = is_sacrifice(board, played_move_obj)

            board.push(played_move_obj)
            is_checkmate = board.is_checkmate()

            played_score = NormalizedScore(chess.engine.PovScore(chess.engine.Cp(0), chess.WHITE))
            if is_checkmate:
                played_score = NormalizedScore(chess.engine.PovScore(chess.engine.Mate(0), chess.WHITE if player_color == "White" else chess.BLACK))
            else:
                info_after = self.live_analysis_engine.analyse(board, limit)
                played_score = NormalizedScore(info_after["score"])

            # Determine FIDE classification
            from src.software.domain.rules.classification import is_book_move

            is_book = is_book_move(move_history_list)

            if is_book:
                classification = "Book"
                cpl = 0
                is_mate_swing = False
                move_accuracy = 100.0
            else:
                # Centipawn Loss (CPL) calculations
                if is_checkmate or is_best_move:
                    cpl = 0
                    is_mate_swing = False
                else:
                    cpl_result = compute_cpl(best_score, played_score, player_color == "White")
                    cpl = cpl_result["cpl"]
                    is_mate_swing = cpl_result["is_mate_swing"]

                # Determine FIDE classification
                from src.software.domain.rules.classification import DEFAULT_THRESHOLDS
                t = DEFAULT_THRESHOLDS

                if (is_best_move or is_checkmate) and is_sac:
                    classification = "Brilliant"
                elif is_best_move or is_checkmate:
                    classification = "Best"
                elif is_mate_swing:
                    classification = "Blunder" if cpl >= t["mistake_max"] else "Mistake"
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

                # Win Probability Move Accuracy calculation
                def get_win_prob_pov(score, side_is_white_pov):
                    if score.is_mate:
                        is_favorable = (score.mate_in > 0 and side_is_white_pov) or (score.mate_in < 0 and not side_is_white_pov)
                        if score.mate_in == 0:
                            return 100.0
                        return 100.0 if is_favorable else 0.0
                    cp_pov = score.cp if side_is_white_pov else -score.cp
                    try:
                        import math
                        return 100.0 / (1.0 + math.exp(-0.00368208 * cp_pov))
                    except OverflowError:
                        return 100.0 if cp_pov > 0 else 0.0

                if is_checkmate or is_best_move:
                    move_accuracy = 100.0
                else:
                    wp_best = get_win_prob_pov(best_score, player_color == "White")
                    wp_played = get_win_prob_pov(played_score, player_color == "White")
                    wp_loss = max(0.0, wp_best - wp_played)
                    move_accuracy = max(0.0, min(100.0, 100.0 - wp_loss))

                if classification == "Mistake":
                    move_accuracy = min(40.0, move_accuracy)
                elif classification == "Blunder":
                    move_accuracy = min(10.0, move_accuracy)

            eval_val = played_score.to_report_value()
            eval_str = f"+{eval_val}" if isinstance(eval_val, (int, float)) and eval_val > 0 else str(eval_val)

            # Append to internal list of analyzed moves
            move_num = len(move_history_list)
            move_data = {
                "move_num": (move_num + 1) // 2,
                "player": player_color,
                "move_str": played_move_san,
                "cpl": cpl,
                "eval": eval_val,
                "classification": classification,
                "best_move": best_move_san,
                "best_eval": best_score.to_report_value(),
                "best_pv": "",
                "is_mate_swing": is_mate_swing,
                "fen": board.fen(),
                "move_uci": uci_move,
                "accuracy": round(move_accuracy, 1)
            }
            self.live_analyzed_moves.append(move_data)

            # Post updates to UI
            self.root.after(0, lambda: self._update_live_analysis_ui(uci_move, classification, eval_str))

            # Game is over, stop timers and log it
            if board.is_game_over():
                self.root.after(0, self.stop_game_timers)
                self.root.after(0, lambda: self.var_status.set("Game Over!"))

        except Exception as e:
            self.log(f"[Live Analysis Error] {e}")

    def _update_live_analysis_ui(self, _uci_move, classification, eval_str):
        if not self.live_analyzed_moves:
            return

        move_data = self.live_analyzed_moves[-1]

        # Update played move label & color badge matching its rating
        self.lbl_live_move.config(text=move_data["move_str"])
        colors = self.get_class_colors(classification)
        self.lbl_live_class.config(text=f"Rating: {classification}", fg=colors["fg"])

        # Recommendation
        self.lbl_best_move.config(text=move_data["best_move"])
        self.lbl_live_eval.config(text=f"Eval: {eval_str}")

        # Detail line metrics
        cpl = move_data["cpl"]
        acc = move_data.get("accuracy", 100.0)
        self.lbl_detail_metrics.config(text=f"Centipawn Loss: {cpl} | Move Accuracy: {acc:.1f}%")

        # Update stats cards
        self.update_live_stats_cards()

        # Insert into moves log Treeview
        num = len(self.live_analyzed_moves)
        self.tree_live_moves.insert(
            "",
            "end",
            values=(
                num,
                move_data["player"],
                move_data["move_str"],
                eval_str,
                f"{move_data['accuracy']:.1f}%",
                classification
            ),
            tags=(classification.lower(),)
        )
        self.tree_live_moves.yview_moveto(1.0) # Auto-scroll to bottom

        self.current_eval_str = eval_str
        self.update_live_eval(eval_str)

        # Refresh Deep Analysis frame live if it is currently visible
        if hasattr(self, "deep_analysis_page") and self.deep_analysis_frame.winfo_viewable():
            self.deep_analysis_page.sync_with_game_state()

    def on_live_move_select(self, _event):
        selected_items = self.tree_live_moves.selection()
        if not selected_items:
            return

        item_id = selected_items[0]
        try:
            index = self.tree_live_moves.index(item_id)
            if 0 <= index < len(self.live_analyzed_moves):
                move_data = self.live_analyzed_moves[index]

                # Update played move label & rating badge
                self.lbl_live_move.config(text=move_data["move_str"])
                cls = move_data["classification"]
                colors = self.get_class_colors(cls)
                self.lbl_live_class.config(text=f"Rating: {cls}", fg=colors["fg"])

                # Update recommendation & evaluation
                self.lbl_best_move.config(text=move_data["best_move"])

                eval_val = move_data["eval"]
                eval_str = f"+{eval_val}" if isinstance(eval_val, (int, float)) and eval_val > 0 else str(eval_val)
                self.lbl_live_eval.config(text=f"Eval: {eval_str}")

                # Detail line metrics
                cpl = move_data["cpl"]
                acc = move_data.get("accuracy", 100.0)
                self.lbl_detail_metrics.config(text=f"Centipawn Loss: {cpl} | Move Accuracy: {acc:.1f}%")

                # Update advantage status bar
                self.current_eval_str = eval_str
                self.update_live_eval(eval_str)
        except Exception as e:
            self.log(f"[Error] Failed to select move: {e}")

    def update_live_stats_cards(self):
        # 1. Reset counters
        white_stats = {"Brilliant": 0, "Best": 0, "Excellent": 0, "Good": 0, "Book": 0, "Inaccuracy": 0, "Mistake": 0, "Blunder": 0}
        black_stats = {"Brilliant": 0, "Best": 0, "Excellent": 0, "Good": 0, "Book": 0, "Inaccuracy": 0, "Mistake": 0, "Blunder": 0}

        white_weighted_sum = 0.0
        white_weight_total = 0.0
        black_weighted_sum = 0.0
        black_weight_total = 0.0

        for m in self.live_analyzed_moves:
            player = m["player"]
            cls = m["classification"]
            acc = m.get("accuracy", 100.0)

            # Tally stats
            if player == "White":
                if cls in white_stats:
                    white_stats[cls] += 1
            else:
                if cls in black_stats:
                    black_stats[cls] += 1

            # Weighted accuracy calculation
            if cls == "Blunder":
                w = 6.0
            elif cls == "Mistake":
                w = 3.0
            elif cls == "Inaccuracy":
                w = 1.5
            else:
                w = 1.0

            if player == "White":
                white_weighted_sum += acc * w
                white_weight_total += w
            else:
                black_weighted_sum += acc * w
                black_weight_total += w

        white_accuracy = (white_weighted_sum / white_weight_total) if white_weight_total > 0 else 100.0
        black_accuracy = (black_weighted_sum / black_weight_total) if black_weight_total > 0 else 100.0

        # 2. Update UI labels
        self.lbl_white_accuracy.config(text=f"Accuracy: {white_accuracy:.1f}%")
        for cat, val in white_stats.items():
            self.white_stat_labels[cat].config(text=f" {val}")

        self.lbl_black_accuracy.config(text=f"Accuracy: {black_accuracy:.1f}%")
        for cat, val in black_stats.items():
            self.black_stat_labels[cat].config(text=f" {val}")

    # ==========================================
    # GAME ARCHIVER & PERSISTENCE
    # ==========================================
    def get_class_colors(self, name):
        colors = {
            "Brilliant": {"bg": "#f3e5f5", "fg": "#8e24aa"},
            "Best": {"bg": "#e0f2f1", "fg": "#004d40"},
            "Excellent": {"bg": "#e8f5e9", "fg": "#2e7d32"},
            "Good": {"bg": "#e3f2fd", "fg": "#1565c0"},
            "Book": {"bg": "#efebe9", "fg": "#4e342e"},
            "Inaccuracy": {"bg": "#fffde7", "fg": "#f57f17"},
            "Mistake": {"bg": "#fff3e0", "fg": "#ef6c00"},
            "Blunder": {"bg": "#ffebee", "fg": "#c62828"}
        }
        return colors.get(name, {"bg": "#ffffff", "fg": "#000000"})

    def get_numeric_eval(self, eval_val):
        if isinstance(eval_val, (int, float)):
            return float(eval_val)
        if isinstance(eval_val, str):
            if '#' in eval_val:
                val_str = eval_val.replace('#', '').strip()
                try:
                    mate_moves = int(val_str)
                    return 10.0 if mate_moves > 0 else -10.0
                except ValueError:
                    return -10.0 if '-' in eval_val else 10.0
            if 'Mate' in eval_val:
                return -10.0 if '-' in eval_val else 10.0
            try:
                return float(eval_val)
            except ValueError:
                pass
        return 0.0

    def update_live_eval(self, eval_val):
        num_eval = self.get_numeric_eval(eval_val)
        clamped = max(-8.0, min(8.0, num_eval))
        self.target_pct_live = 0.5 + (clamped / 16.0) * 0.9
        self.animate_live_eval_bar()

    def animate_live_eval_bar(self):
        if not hasattr(self, "current_pct_live"):
            self.current_pct_live = 0.5

        diff = self.target_pct_live - self.current_pct_live
        if abs(diff) > 0.005:
            self.current_pct_live += diff * 0.15
            self.redraw_live_eval_bar_to_canvas()
            self.root.after(16, self.animate_live_eval_bar)
        else:
            self.current_pct_live = self.target_pct_live
            self.redraw_live_eval_bar_to_canvas()

    def redraw_live_eval_bar_to_canvas(self):
        if not hasattr(self, "canvas_eval_live"):
            return

        self.canvas_eval_live.delete("all")

        # Determine current layout dimensions dynamically
        w = self.canvas_eval_live.winfo_width()
        h = self.canvas_eval_live.winfo_height()
        if w <= 1: w = 22
        if h <= 1: h = 300

        divider_y = h * (1.0 - self.current_pct_live)

        # Black (top)
        self.canvas_eval_live.create_rectangle(0, 0, w, divider_y, fill="#212121", outline="")
        # White (bottom)
        self.canvas_eval_live.create_rectangle(0, divider_y, w, h, fill="#ffffff", outline="")

        # Crisp interior border frame outline (prevents coordinate clipping)
        self.canvas_eval_live.create_rectangle(0, 0, w-1, h-1, outline="#cfd8dc")

        text_color = "#212121" if self.current_pct_live >= 0.5 else "#ffffff"
        text_y = h - 16 if self.current_pct_live >= 0.5 else 16

        if hasattr(self, "current_eval_str"):
            display_str = self.current_eval_str
            if display_str.startswith("+"):
                display_str = display_str[1:]
            elif display_str.startswith("-"):
                display_str = display_str[1:]
            if '#' in display_str:
                display_str = "M" + display_str.replace('#', '').strip()
            self.canvas_eval_live.create_text(w // 2, text_y, text=display_str, font=("Segoe UI", 7, "bold"), fill=text_color)

