import os
import json
import datetime

class AnalysisLogger:
    """Captures raw engine outputs for every analyzed move for offline debugging."""

    def __init__(self, enabled=True, log_dir=None):
        self.enabled = enabled
        self.entries = []
        self.log_dir = log_dir

    def log_move(self, move_index, fen_before, move_san, move_uci,
                 best_move_san, best_score_display, best_pv,
                 played_score_display, played_pv,
                 cpl, classification, is_promotion, material_before, material_after):
        if not self.enabled:
            return
        self.entries.append({
            "move_index": move_index,
            "fen_before": fen_before,
            "move_san": move_san,
            "move_uci": move_uci,
            "best_move": best_move_san,
            "best_score": best_score_display,
            "best_pv": best_pv,
            "played_score": played_score_display,
            "played_pv": played_pv,
            "cpl": cpl,
            "classification": classification,
            "is_promotion": is_promotion,
            "material_before": material_before,
            "material_after": material_after
        })

    def save(self, filepath=None):
        """Persist log to a JSON file."""
        if not self.enabled or not self.entries:
            return
        if filepath is None:
            if self.log_dir:
                os.makedirs(self.log_dir, exist_ok=True)
                ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
                filepath = os.path.join(self.log_dir, f"analysis_log_{ts}.json")
            else:
                return
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(self.entries, f, indent=2, ensure_ascii=False)
