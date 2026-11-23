from abc import ABC, abstractmethod

class VisionPort(ABC):
    @abstractmethod
    def start_vision(self, current_elo: int, on_startup_finished_callback=None):
        pass
        
    @abstractmethod
    def stop_vision(self):
        pass
        
    @abstractmethod
    def send_command(self, cmd: str):
        pass
