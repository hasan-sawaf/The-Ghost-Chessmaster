import tkinter as tk
import chess

class BoardMixin:
    def draw_board_state(self):
        """Draws the visual chessboard with ranks/files coordinates outside the board grid, and updates badges/pieces."""
        self.canvas_board.delete("all")
        sq_size = 36
        offset_x = 20
        offset_y = 0

        # 1. Determine active FEN and last move squares
        active_fen = chess.STARTING_FEN
        highlight_from = None
        highlight_to = None
        move_cls = None

        if hasattr(self, "moves_data") and self.current_move_idx >= 0 and self.current_move_idx < len(self.moves_data):
            move_item = self.moves_data[self.current_move_idx]
            if isinstance(move_item, dict):
                active_fen = move_item.get("fen", chess.STARTING_FEN)
                move_cls = move_item.get("classification")
                uci = move_item.get("move_uci", "")
                if len(uci) >= 4:
                    highlight_from = uci[:2]
                    highlight_to = uci[2:4]
        else:
            game_moves = None
            if hasattr(self, "main_gui") and hasattr(self.main_gui, "live_game_moves") and self.main_gui.live_game_moves:
                game_moves = self.main_gui.live_game_moves
            elif hasattr(self, "live_game_moves") and self.live_game_moves:
                game_moves = self.live_game_moves
                
            if game_moves:
                b = chess.Board()
                last_uci = None
                for m_str in game_moves:
                    try:
                        mv = chess.Move.from_uci(m_str)
                        if mv in b.legal_moves:
                            b.push(mv)
                            last_uci = m_str
                    except Exception:
                        break
                active_fen = b.fen()
                if last_uci and len(last_uci) >= 4:
                    highlight_from = last_uci[:2]
                    highlight_to = last_uci[2:4]

        # Initialize python-chess Board representation
        try:
            board = chess.Board(active_fen)
        except Exception:
            board = chess.Board()

        # Update check/checkmate label status next to board title
        if hasattr(self, "lbl_board_status") and self.lbl_board_status:
            if board.is_checkmate():
                self.lbl_board_status.config(text="(Checkmate)")
            elif board.is_check():
                self.lbl_board_status.config(text="(Check)")
            else:
                self.lbl_board_status.config(text="")

        # 2. Draw 8x8 Chessboard Squares (offset by x=20)
        for row in range(8):
            for col in range(8):
                x1 = offset_x + col * sq_size
                y1 = offset_y + row * sq_size
                x2 = x1 + sq_size
                y2 = y1 + sq_size
                
                # Alternate color grids
                color = "#f0d9b5" if (row + col) % 2 == 0 else "#b58863"
                self.canvas_board.create_rectangle(x1, y1, x2, y2, fill=color, outline="")

        # 3. Draw Ranks coordinate labels (8 to 1) on the left side (x = 10)
        for row in range(8):
            rank_char = str(8 - row)
            cy = offset_y + row * sq_size + (sq_size // 2)
            self.canvas_board.create_text(10, cy, text=rank_char, font=("Segoe UI", 9, "bold"), fill="#546e7a")

        # 4. Draw Files coordinate labels (a to h) on the bottom side (y = 288 + 10)
        for col in range(8):
            file_char = "abcdefgh"[col]
            cx = offset_x + col * sq_size + (sq_size // 2)
            self.canvas_board.create_text(cx, 288 + 10, text=file_char, font=("Segoe UI", 9, "bold"), fill="#546e7a")

        # 5. Draw Highlights of the active move
        for row in range(8):
            for col in range(8):
                file_char = "abcdefgh"[col]
                rank_char = str(8 - row)
                sq_name = file_char + rank_char
                
                x1 = offset_x + col * sq_size
                y1 = offset_y + row * sq_size
                x2 = x1 + sq_size
                y2 = y1 + sq_size

                # Draw move highlighted border outlines
                if sq_name == highlight_from:
                    self.canvas_board.create_rectangle(x1 + 2, y1 + 2, x2 - 2, y2 - 2, outline="#ef6c00", width=3)
                elif sq_name == highlight_to:
                    self.canvas_board.create_rectangle(x1 + 2, y1 + 2, x2 - 2, y2 - 2, outline="#2e7d32", width=3)

        # 5.5 Draw Check/Checkmate red blur highlight under checked king
        if board.is_check():
            king_square = board.king(board.turn)
            if king_square is not None:
                k_col = chess.square_file(king_square)
                k_row = 7 - chess.square_rank(king_square)
                kx1 = offset_x + k_col * sq_size
                ky1 = offset_y + k_row * sq_size
                kx2 = kx1 + sq_size
                ky2 = ky1 + sq_size
                
                # Concentric red blur rectangles
                self.canvas_board.create_rectangle(kx1 + 1, ky1 + 1, kx2 - 1, ky2 - 1, fill="#ffebee", outline="")
                self.canvas_board.create_rectangle(kx1 + 3, ky1 + 3, kx2 - 3, ky2 - 3, fill="#ffcdd2", outline="")
                self.canvas_board.create_rectangle(kx1 + 5, ky1 + 5, kx2 - 5, ky2 - 5, fill="#ef9a9a", outline="")
                self.canvas_board.create_rectangle(kx1 + 7, ky1 + 7, kx2 - 7, ky2 - 7, fill="#e57373", outline="")
                # Distinct red border outline
                self.canvas_board.create_rectangle(kx1 + 1, ky1 + 1, kx2 - 1, ky2 - 1, outline="#d32f2f", width=2)

        # 6. Render Chess Pieces
        for square in chess.SQUARES:
            piece = board.piece_at(square)
            if piece:
                col = chess.square_file(square)
                row = 7 - chess.square_rank(square)
                
                cx = offset_x + col * sq_size + (sq_size // 2)
                cy = offset_y + row * sq_size + (sq_size // 2)
                
                color_char = "W" if piece.color == chess.WHITE else "B"
                symbol = piece.symbol().upper()
                tag = f"{color_char}{symbol}"
                
                if tag in self.piece_images:
                    # Draw preloaded PIL ImageTk Photo
                    self.canvas_board.create_image(cx, cy, image=self.piece_images[tag])
                else:
                    # Fallback text formatting if images are missing
                    fg_c = "#ffffff" if color_char == "W" else "#000000"
                    bg_c = "#000000" if color_char == "W" else "#ffffff"
                    
                    self.canvas_board.create_oval(cx - 14, cy - 14, cx + 14, cy + 14, fill=bg_c, outline="gray")
                    self.canvas_board.create_text(cx, cy, text=tag, font=("Segoe UI", 9, "bold"), fill=fg_c)

        # 7. Overlay FIDE Classification Quality badge on target piece
        if highlight_to and move_cls:
            col_t = "abcdefgh".index(highlight_to[0])
            row_t = 8 - int(highlight_to[1])
            
            # Top right coordinate of square (relative to grid offset)
            x2_t = offset_x + col_t * sq_size + sq_size
            y1_t = offset_y + row_t * sq_size
            
            if move_cls in self.board_icons:
                # Center of the badge is at (x2_t - 9, y1_t + 9)
                self.canvas_board.create_image(x2_t - 9, y1_t + 9, image=self.board_icons[move_cls])
            else:
                # Text/Emoji fallback if icons directory is not present
                badge_emojis = {
                    "Brilliant": "🌟",
                    "Best": "⭐",
                    "Excellent": "🟢",
                    "Good": "🔵",
                    "Book": "📖",
                    "Inaccuracy": "🟡",
                    "Mistake": "🟠",
                    "Blunder": "🔴"
                }
                emoji = badge_emojis.get(move_cls, "")
                if emoji:
                    self.canvas_board.create_oval(x2_t - 19, y1_t + 2, x2_t - 2, y1_t + 19, fill="white", outline="#cfd8dc", width=1)
                    self.canvas_board.create_text(x2_t - 10, y1_t + 11, text=emoji, font=("Segoe UI", 9))
        
        # 8. Draw Advantage / Evaluation Bar
        self.draw_eval_bar()

    def get_numeric_eval(self, eval_val):
        if isinstance(eval_val, (int, float)):
            return float(eval_val)
        if isinstance(eval_val, str):
            if '#' in eval_val:
                val_str = eval_val.replace('#', '').strip()
                try:
                    mate_moves = int(val_str)
                    if mate_moves > 0:
                        return 10.0
                    elif mate_moves < 0:
                        return -10.0
                    else:
                        return 0.0
                except ValueError:
                    if '-' in eval_val:
                        return -10.0
                    return 10.0
            if 'Mate' in eval_val:
                if '-' in eval_val:
                    return -10.0
                return 10.0
        return 0.0

    def draw_eval_bar(self):
        """Sets the target percentage and triggers the smooth animation loop."""
        eval_val = 0.0
        if self.current_move_idx >= 0 and self.current_move_idx < len(self.moves_data):
            eval_val = self.moves_data[self.current_move_idx]["eval"]
                
        num_eval = self.get_numeric_eval(eval_val)
        
        # Map to height percentage (0.0 = Black wins, 1.0 = White wins)
        clamped = max(-8.0, min(8.0, num_eval))
        self.target_pct = 0.5 + (clamped / 16.0) * 0.9
        
        # Trigger the animation loop
        self.animate_eval_bar()

    def animate_eval_bar(self):
        """Smoothly interpolates self.current_pct towards self.target_pct."""
        if not hasattr(self, "current_pct"):
            self.current_pct = 0.5
            
        diff = self.target_pct - self.current_pct
        if abs(diff) > 0.005:
            # 15% step size for ease-out feel
            self.current_pct += diff * 0.15
            self.redraw_eval_bar_to_canvas()
            # Loop next frame
            self.root.after(16, self.animate_eval_bar)
        else:
            self.current_pct = self.target_pct
            self.redraw_eval_bar_to_canvas()

    def redraw_eval_bar_to_canvas(self):
        """Renders the eval bar dividing lines and text labels on canvas based on self.current_pct."""
        if not hasattr(self, "canvas_eval"):
            return
        
        self.canvas_eval.delete("all")
        w = 20
        h = 288 # Matching chess board grid height (excluding coordinate margin!)
        
        divider_y = h * (1.0 - self.current_pct)
        
        # Draw Black section (top)
        self.canvas_eval.create_rectangle(0, 0, w, divider_y, fill="#212121", outline="")
        # Draw White section (bottom)
        self.canvas_eval.create_rectangle(0, divider_y, w, h, fill="#ffffff", outline="")
        
        # Get active score details for display text
        eval_val = 0.0
        eval_str = "0.0"
        if self.current_move_idx >= 0 and self.current_move_idx < len(self.moves_data):
            eval_val = self.moves_data[self.current_move_idx]["eval"]
            if isinstance(eval_val, (int, float)):
                eval_str = f"{eval_val:+.1f}"
            else:
                eval_str = str(eval_val)
                
        num_eval = self.get_numeric_eval(eval_val)
        
        # Format text overlay
        display_str = eval_str
        if display_str.startswith("+"):
            display_str = display_str[1:]
        elif display_str.startswith("-"):
            display_str = display_str[1:]
            
        if '#' in eval_str or 'Mate' in eval_str:
            display_str = "M" + eval_str.replace('#', '').replace('-', '').strip()
            
        # Draw text at current animated zone
        text_color = "#212121" if self.current_pct >= 0.5 else "#ffffff"
        text_y = h - 16 if self.current_pct >= 0.5 else 16
        
        self.canvas_eval.create_text(w // 2, text_y, text=display_str, font=("Segoe UI", 7, "bold"), fill=text_color)
