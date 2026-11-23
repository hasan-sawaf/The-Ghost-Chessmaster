import threading
import time
import socket
import logging

class NetworkManager:
    """Monitors internet connectivity status asynchronously with physical adapter filtering & multi-protocol fallbacks."""
    
    # Endpoints spanning HTTP (port 80), HTTPS (443), and DNS (53)
    PROBE_ENDPOINTS = [
        ("1.1.1.1", 80),        # Cloudflare HTTP
        ("8.8.8.8", 53),        # Google DNS
        ("1.1.1.1", 53),        # Cloudflare DNS
        ("www.google.com", 80), # Google HTTP via OS DNS resolution
    ]
    
    # Keywords identifying virtual, VPN, tunnel, or loopback network adapters
    VIRTUAL_IFACE_KEYWORDS = [
        'vpn', 'tap', 'tun', 'wireguard', 'wintun', 'openvpn', 
        'proton', 'nord', 'express', 'cisco', 'zerotier', 'tailscale', 
        'vbox', 'vmware', 'virtual', 'loopback', 'pseudo'
    ]
    
    def __init__(self, check_interval=1.0, fail_threshold=2, success_threshold=1):
        self._is_online = False
        self._running = False
        self._thread = None
        self.on_status_changed = None  # callback(is_online: bool)
        
        self._check_interval = check_interval
        self._fail_threshold = fail_threshold
        self._success_threshold = success_threshold
        
        self._consecutive_fails = 0
        self._consecutive_successes = 0

    @property
    def is_online(self):
        return self._is_online

    def start(self):
        """Start background connectivity monitoring (100% non-blocking for instant GUI launch)."""
        if self._running:
            return
        self._running = True
            
        self._thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self._thread.start()
        logging.info("[NetworkManager] Started async internet connectivity monitoring thread.")

    def stop(self):
        self._running = False

    def _is_physical_interface_up(self):
        """
        Verifies if an actual physical Wi-Fi or Ethernet adapter is UP with an assigned IPv4 address.
        Filters out VPN, TAP, Tunnel, and Virtual adapters so turning off Wi-Fi returns False even if VPN is active.
        """
        try:
            import psutil
            stats = psutil.net_if_stats()
            addrs = psutil.net_if_addrs()
            
            for iface_name, stat in stats.items():
                iface_lower = iface_name.lower()
                if not stat.isup:
                    continue
                
                # Exclude virtual / VPN / tunnel adapters
                if any(kw in iface_lower for kw in self.VIRTUAL_IFACE_KEYWORDS):
                    continue
                
                # Check if this physical interface has a valid non-loopback IPv4 address
                for addr in addrs.get(iface_name, []):
                    if addr.family == socket.AF_INET:
                        ip = addr.address
                        if ip and not ip.startswith('127.') and not ip.startswith('169.254.'):
                            return True
            return False
        except Exception as e:
            logging.debug(f"[NetworkManager] Physical interface check notice: {e}")
            return True  # Fallback to standard socket check if psutil unavailable

    def _check_internet(self):
        """
        Checks if physical Wi-Fi/Ethernet interface is active AND internet probe succeeds.
        Returns False immediately if Wi-Fi/Ethernet physical interface is disabled.
        """
        # Step 1: Must have an active physical Wi-Fi or Ethernet adapter UP
        if not self._is_physical_interface_up():
            return False

        # Step 2: Try network socket probes
        for host, port in self.PROBE_ENDPOINTS:
            try:
                sock = socket.create_connection((host, port), timeout=0.3)
                sock.close()
                return True
            except (socket.timeout, socket.error, OSError):
                continue
        
        # Step 3: Fallback OS-level hostname lookup
        try:
            socket.gethostbyname("www.google.com")
            return True
        except Exception:
            pass

        return False

    def _monitor_loop(self):
        # Initial fast check in background thread
        initial_online = self._check_internet()
        self._is_online = initial_online
        if initial_online:
            self._consecutive_successes = self._success_threshold
            self._consecutive_fails = 0
        else:
            self._consecutive_fails = self._fail_threshold
            self._consecutive_successes = 0

        # Trigger initial UI update immediately
        if self.on_status_changed:
            try:
                self.on_status_changed(self._is_online)
            except Exception as e:
                logging.debug(f"[NetworkManager] Initial callback error: {e}")

        while self._running:
            time.sleep(self._check_interval)
            if not self._running:
                break

            raw_online = self._check_internet()
            
            if raw_online:
                self._consecutive_successes += 1
                self._consecutive_fails = 0
            else:
                self._consecutive_fails += 1
                self._consecutive_successes = 0
            
            # Apply debouncing hysteresis
            new_state = self._is_online
            if not self._is_online and self._consecutive_successes >= self._success_threshold:
                new_state = True
            elif self._is_online and self._consecutive_fails >= self._fail_threshold:
                new_state = False

            if new_state != self._is_online:
                self._is_online = new_state
                logging.info(f"[NetworkManager] Internet status changed: {'ONLINE' if self._is_online else 'OFFLINE'}")
                if self.on_status_changed:
                    try:
                        self.on_status_changed(self._is_online)
                    except Exception as e:
                        logging.debug(f"[NetworkManager] Callback error: {e}")
