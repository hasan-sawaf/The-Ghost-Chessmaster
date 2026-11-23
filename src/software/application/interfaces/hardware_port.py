from abc import ABC, abstractmethod

class HardwarePort(ABC):
    @abstractmethod
    def connect(self, port: str, baudrate: int) -> bool:
        pass
        
    @abstractmethod
    def disconnect(self):
        pass
        
    @abstractmethod
    def send_command(self, cmd: str):
        pass
