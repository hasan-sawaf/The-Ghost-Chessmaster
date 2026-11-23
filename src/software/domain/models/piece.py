import chess

class Piece:
    def __init__(self, color: bool, piece_type: int):
        self.color = color
        self.piece_type = piece_type
