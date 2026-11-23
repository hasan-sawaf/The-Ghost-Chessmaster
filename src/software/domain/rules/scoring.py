class NormalizedScore:
    """
    Normalized engine evaluation — always from White's perspective.
    Mate scores are stored as structured data, never converted to centipawns.
    """
    __slots__ = ('is_mate', 'mate_in', 'cp')

    def __init__(self, pov_score):
        """
        pov_score: chess.engine.PovScore from engine.analyse()
        Always normalizes to White's perspective via .white()
        """
        score = pov_score.white()
        self.is_mate = score.is_mate()
        self.mate_in = score.mate() if self.is_mate else None
        self.cp = score.score() if not self.is_mate else None

    def to_display(self):
        """Human-readable evaluation string."""
        if self.is_mate:
            return f"#{'+'if self.mate_in > 0 else ''}{self.mate_in}"
        cp_val = self.cp / 100.0
        return f"+{cp_val:.2f}" if cp_val > 0 else f"{cp_val:.2f}"

    def to_report_value(self):
        """Value for the report dict (float cp/100 or string)."""
        if self.is_mate:
            return f"#{self.mate_in}"
        return round(self.cp / 100.0, 2)

    def white_advantage_cp(self):
        """Returns cp from White's view, or None if mate."""
        return self.cp


def compute_cpl(best, played, side_is_white):
    """
    Computes centipawn loss and detects mate swings.
    """
    result = {"cpl": 0, "is_mate_swing": False, "mate_lost": False, "mate_allowed": False}

    # Case 1: Both are centipawn scores — standard direct CPL
    if not best.is_mate and not played.is_mate:
        if side_is_white:
            result["cpl"] = max(0, best.cp - played.cp)
        else:
            # For Black, advantage means lower White cp
            result["cpl"] = max(0, played.cp - best.cp)
        return result

    # Case 2: Best is mate (favorable for our side), played is not mate
    if best.is_mate and not played.is_mate:
        best_favorable = (best.mate_in > 0 and side_is_white) or (best.mate_in < 0 and not side_is_white)
        if best_favorable:
            # We had a forced mate and lost it — this is a clear blunder
            result["is_mate_swing"] = True
            result["mate_lost"] = True
            # Assign a high but bounded CPL for classification
            result["cpl"] = 800
            return result
        else:
            # Best was getting mated, played avoids mate — this is actually an improvement
            result["cpl"] = 0
            return result

    # Case 3: Best is not mate, played is mate (unfavorable for our side)
    if not best.is_mate and played.is_mate:
        played_unfavorable = (played.mate_in > 0 and not side_is_white) or (played.mate_in < 0 and side_is_white)
        if played_unfavorable:
            # We allowed the opponent to force mate — blunder
            result["is_mate_swing"] = True
            result["mate_allowed"] = True
            result["cpl"] = 800
            return result
        else:
            # Played move leads to us mating — this is good
            result["cpl"] = 0
            return result

    # Case 4: Both are mate — compare mate distances
    if best.is_mate and played.is_mate:
        best_m = best.mate_in
        played_m = played.mate_in

        # Check if they're mating the same side
        best_we_mate = (best_m > 0 and side_is_white) or (best_m < 0 and not side_is_white)
        played_we_mate = (played_m > 0 and side_is_white) or (played_m < 0 and not side_is_white)

        if best_we_mate and played_we_mate:
            # Both are us mating, compare distances (smaller = better)
            best_dist = abs(best_m)
            played_dist = abs(played_m)
            delay = played_dist - best_dist
            if delay >= 3:
                # Delayed mate significantly — mild inaccuracy/mistake
                result["cpl"] = min(delay * 30, 200)
            else:
                result["cpl"] = 0
            return result

        if not best_we_mate and not played_we_mate:
            # Both are opponent mating us — played is better if farther away
            best_dist = abs(best_m)
            played_dist = abs(played_m)
            if played_dist < best_dist:
                # Got mated faster — mild mistake
                result["cpl"] = min((best_dist - played_dist) * 50, 300)
            else:
                result["cpl"] = 0
            return result

        # One side mates in best, other side mates in played — huge swing
        result["is_mate_swing"] = True
        result["mate_lost"] = best_we_mate
        result["mate_allowed"] = not best_we_mate
        result["cpl"] = 1000
        return result

    return result


def compute_win_probability(score):
    """
    Converts a NormalizedScore to win probability [0.0, 1.0] from White's perspective.
    Uses standard logistic model: WinProb = 1 / (1 + 10^(-cp / 400))
    """
    if score.is_mate:
        return 1.0 if score.mate_in > 0 else 0.0
    return 1.0 / (1.0 + 10.0 ** (-score.cp / 400.0))
