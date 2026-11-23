from abc import ABC, abstractmethod

class AIPort(ABC):
    @abstractmethod
    def analyze_position(self, fen: str, depth: int) -> dict:
        pass
        
    @abstractmethod
    def quit(self):
        pass
