import tkinter as tk
from tkinter import messagebox, scrolledtext
from src.software.domain.rules.game_rules import get_mate_phrase

class ReportMixin:
    def generate_report_text(self):
        """Generates a cleanly formatted, comprehensive text report of the game analysis."""
        if not self.moves_data or not self.last_report:
            return ""

        w_acc = self.last_report.get("white_accuracy", 0)
        b_acc = self.last_report.get("black_accuracy", 0)
        w_s = self.last_report.get("white_stats", {})
        b_s = self.last_report.get("black_stats", {})

        lines = []
        lines.append("┌───────────────────────────────────────────────────────────────────┐")
        lines.append("│                CHESSTRACKER GAMEPLAY ANALYSIS REPORT              │")
        lines.append("└───────────────────────────────────────────────────────────────────┘\n")
        
        lines.append("📊 PLAYER ACCURACIES")
        lines.append("--------------------")
        lines.append(f"⚪ Player White Accuracy: {w_acc}%")
        lines.append(f"⚫ Player Black Accuracy: {b_acc}%")
        lines.append("-" * 69)
        
        lines.append("\n📋 MOVE QUALITY SUMMARY COMPARISON")
        lines.append("┌─────────────────┬──────────┬──────────┐")
        lines.append("│ Move Category   │  White   │  Black   │")
        lines.append("├─────────────────┼──────────┼──────────┤")
        
        cats = [
            ("brilliant", "🌟 Brilliant"),
            ("best", "⭐ Best     "),
            ("excellent", "🟢 Excellent"),
            ("good", "🔵 Good     "),
            ("book", "📖 Book     "),
            ("inaccuracy", "🟡 Inaccuracy"),
            ("mistake", "🟠 Mistake  "),
            ("blunder", "🔴 Blunder  ")
        ]
        
        for key, display in cats:
            w_val = w_s.get(key, 0)
            b_val = b_s.get(key, 0)
            lines.append(f"│ {display:<15} │ {w_val:>8} │ {b_val:>8} │")
            
        lines.append("└─────────────────┴──────────┴──────────┘")
            
        lines.append("\n📝 MOVE-BY-MOVE BREAKDOWN")
        lines.append("-------------------------")
        
        # Group moves by number
        moves_by_num = {}
        for m in self.moves_data:
            num = m["move_num"]
            if num not in moves_by_num:
                moves_by_num[num] = {"white": None, "black": None}
            if m["player"] == "White":
                moves_by_num[num]["white"] = m
            else:
                moves_by_num[num]["black"] = m
                
        for num in sorted(moves_by_num.keys()):
            w_move = moves_by_num[num]["white"]
            b_move = moves_by_num[num]["black"]
            
            # Format White move block
            w_block = ""
            if w_move:
                eval_val = w_move['eval']
                eval_str = f"+{eval_val}" if isinstance(eval_val, float) and eval_val > 0 else str(eval_val)
                w_block = f"{w_move['move_str']:<7} [{eval_str:>6} | {w_move['classification']:<10}]"
            
            # Format Black move block
            b_block = ""
            if b_move:
                eval_val = b_move['eval']
                eval_str = f"+{eval_val}" if isinstance(eval_val, float) and eval_val > 0 else str(eval_val)
                b_block = f"{b_move['move_str']:<7} [{eval_str:>6} | {b_move['classification']:<10}]"
                
            # Combine side-by-side with padding alignment
            lines.append(f" {num:2d}. {w_block:<32}    {b_block}")
            
            # Print annotations/warnings for inaccuracies, mistakes, blunders
            if w_move and w_move["classification"] in ["Inaccuracy", "Mistake", "Blunder"]:
                best_eval = w_move["best_eval"]
                best_eval_str = f"+{best_eval}" if isinstance(best_eval, float) and best_eval > 0 else str(best_eval)
                if w_move.get("is_mate_swing", False):
                    phrase = get_mate_phrase("White", w_move["best_eval"], w_move["eval"])
                    lines.append(f"     ⚪ White played {w_move['move_str']} ({phrase})")
                else:
                    lines.append(f"     ⚪ White played {w_move['move_str']} (CPL Loss: {w_move['cpl']} CP)")
                lines.append(f"        ↳ Recommended alternative: {w_move['best_move']} ({best_eval_str})")
                
            if b_move and b_move["classification"] in ["Inaccuracy", "Mistake", "Blunder"]:
                best_eval = b_move["best_eval"]
                best_eval_str = f"+{best_eval}" if isinstance(best_eval, float) and best_eval > 0 else str(best_eval)
                if b_move.get("is_mate_swing", False):
                    phrase = get_mate_phrase("Black", b_move["best_eval"], b_move["eval"])
                    lines.append(f"     ⚫ Black played {b_move['move_str']} ({phrase})")
                else:
                    lines.append(f"     ⚫ Black played {b_move['move_str']} (CPL Loss: {b_move['cpl']} CP)")
                lines.append(f"        ↳ Recommended alternative: {b_move['best_move']} ({best_eval_str})")
                
        lines.append("\n🏁 CRITICAL HIGHLIGHTS SUMMARY")
        lines.append("------------------------------")
        
        has_highlights = False
        for m in self.moves_data:
            eval_val = m['eval']
            is_mate_delivery = False
            if isinstance(eval_val, str) and ('#0' in eval_val or '#' in eval_val or 'Mate' in eval_val):
                if '#0' in eval_val or '#' in m['move_str'] or 'Mate 0' in eval_val:
                    is_mate_delivery = True

            if m["classification"] in ["Brilliant", "Blunder", "Mistake"] or is_mate_delivery:
                has_highlights = True
                eval_str = f"+{eval_val}" if isinstance(eval_val, float) and eval_val > 0 else str(eval_val)
                best_eval = m["best_eval"]
                best_eval_str = f"+{best_eval}" if isinstance(best_eval, float) and best_eval > 0 else str(best_eval)
                
                if is_mate_delivery:
                    lines.append(f"🏁 Move {m['move_num']} ({m['player']}): Played {m['move_str']} - classified as {m['classification']}.")
                    lines.append(f"  Game-ending checkmate delivered! Position evaluation: Game Over (#).\n")
                elif m["classification"] == "Brilliant":
                    lines.append(f"🌟 Move {m['move_num']} ({m['player']}): Played {m['move_str']} - classified as {m['classification']}.")
                    lines.append(f"  Brilliant move! Found a master-level continuation. Position evaluation: {eval_str}\n")
                else:
                    lines.append(f"⚠️ Move {m['move_num']} ({m['player']}): Played {m['move_str']} - classified as {m['classification']}.")
                    if m.get("is_mate_swing", False):
                        phrase = get_mate_phrase(m['player'], m["best_eval"], m["eval"])
                        if phrase == "missed forced checkmate":
                            lines.append(f"  Missed forced checkmate — position went from {best_eval_str} to {eval_str}.")
                        else:
                            lines.append(f"  Allowed forced checkmate — position went from {best_eval_str} to {eval_str}.")
                    else:
                        lines.append(f"  Advantage dropped by {m['cpl']} centipawns (from {best_eval_str} to {eval_str}).")
                    lines.append(f"  ↳ Recommended alternative: {m['best_move']}\n")
                    
        if not has_highlights:
            lines.append("No blunders, mistakes, or brilliant moves detected in this game. Solid play!")
            
        lines.append("\nReport generated by ChessTracker Offline Game Analysis Engine.")
        return "\n".join(lines)

    def show_text_report(self):
        """Displays the generated game analysis report in a scrollable, copyable pop-up window."""
        if not self.moves_data or not self.last_report:
            messagebox.showwarning("Warning", "Please run a game analysis first.")
            return

        report_text = self.generate_report_text()

        # Create Pop-up
        popup = tk.Toplevel(self.root)
        popup.title("ChessTracker - Gameplay Analysis Report")
        popup.geometry("750x650")
        popup.configure(bg="#f4f6f9")
        popup.transient(self.root)
        popup.grab_set()

        # Title label
        lbl_title = tk.Label(popup, text="📊 CHESS GAMEPLAY ANALYSIS REPORT", font=("Segoe UI", 12, "bold"), fg="#37474f", bg="#f4f6f9")
        lbl_title.pack(anchor="w", padx=15, pady=(15, 5))

        # Text area
        txt = scrolledtext.ScrolledText(popup, font=("Consolas", 10), wrap=tk.WORD, bg="white", bd=1, relief="solid")
        txt.pack(fill=tk.BOTH, expand=True, padx=15, pady=5)

        # Parse and insert text + inline graphical PNG icons
        emoji_to_category = {
            "🌟": "Brilliant",
            "⭐": "Best",
            "🟢": "Excellent",
            "🔵": "Good",
            "📖": "Book",
            "🟡": "Inaccuracy",
            "🟠": "Mistake",
            "🔴": "Blunder",
            "🏁": "Alternative"
        }

        current_idx = 0
        while current_idx < len(report_text):
            found_emoji = None
            for emoji in emoji_to_category:
                if report_text.startswith(emoji, current_idx):
                    found_emoji = emoji
                    break
            
            if found_emoji:
                cat = emoji_to_category[found_emoji]
                icon_img = self.legend_icons.get(cat, "")
                if icon_img:
                    txt.image_create(tk.END, image=icon_img)
                else:
                    txt.insert(tk.END, found_emoji)
                current_idx += len(found_emoji)
            else:
                txt.insert(tk.END, report_text[current_idx])
                current_idx += 1

        txt.config(state=tk.DISABLED) # Read-only

        # Buttons frame
        btn_frame = tk.Frame(popup, bg="#f4f6f9")
        btn_frame.pack(fill=tk.X, padx=15, pady=15)

        def copy_clipboard():
            self.root.clipboard_clear()
            self.root.clipboard_append(report_text)
            messagebox.showinfo("Success", "Report copied to clipboard!", parent=popup)

        def save_file():
            from tkinter import filedialog
            filepath = filedialog.asksaveasfilename(
                defaultextension=".txt",
                filetypes=[("Text Files", "*.txt"), ("Markdown Files", "*.md"), ("All Files", "*.*")],
                title="Save Analysis Report",
                parent=popup
            )
            if filepath:
                try:
                    with open(filepath, "w", encoding="utf-8") as f:
                        f.write(report_text)
                    messagebox.showinfo("Success", f"Report saved successfully to:\n{filepath}", parent=popup)
                except Exception as e:
                    messagebox.showerror("Error", f"Failed to save file:\n{e}", parent=popup)

        btn_copy = tk.Button(btn_frame, text="📋 Copy to Clipboard", font=("Segoe UI", 9, "bold"), bg="#1976d2", fg="white", relief="flat", cursor="hand2", command=copy_clipboard)
        btn_copy.pack(side=tk.LEFT, padx=(0, 10), ipady=3, ipadx=10)

        btn_save = tk.Button(btn_frame, text="💾 Save to File", font=("Segoe UI", 9, "bold"), bg="#2e7d32", fg="white", relief="flat", cursor="hand2", command=save_file)
        btn_save.pack(side=tk.LEFT, padx=10, ipady=3, ipadx=10)

        btn_close = tk.Button(btn_frame, text="Close", font=("Segoe UI", 9), bg="#cfd8dc", fg="#37474f", relief="flat", cursor="hand2", command=popup.destroy)
        btn_close.pack(side=tk.RIGHT, ipady=3, ipadx=10)
