#!/usr/bin/env python3
"""
Video Downloader Pro - Descarga videos de redes sociales
Compatibilidad total con Adobe Premiere (H.264 + AAC, MP4)
"""

import tkinter as tk
from tkinter import ttk, filedialog, messagebox, scrolledtext
import threading
import subprocess
import os
import sys
import re
import glob
import uuid
import time
import shutil
import socket
import json as _json
import tempfile
import urllib.request
from pathlib import Path


# ─── Cookies: extracción automática vía CDP ───────────────────────────────────

_BROWSER_EXE_PATHS = {
    'chrome': [
        r'C:\Program Files\Google\Chrome\Application\chrome.exe',
        r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
        os.path.join(os.environ.get('LOCALAPPDATA', ''),
                     r'Google\Chrome\Application\chrome.exe'),
    ],
    'brave': [
        r'C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe',
        r'C:\Program Files (x86)\BraveSoftware\Brave-Browser\Application\brave.exe',
        os.path.join(os.environ.get('LOCALAPPDATA', ''),
                     r'BraveSoftware\Brave-Browser\Application\brave.exe'),
    ],
    'edge': [
        r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
        r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    ],
    'chromium': [
        os.path.join(os.environ.get('LOCALAPPDATA', ''),
                     r'Chromium\Application\chrome.exe'),
    ],
}

_BROWSER_USERDATAS = {
    'chrome':   os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Google', 'Chrome', 'User Data'),
    'brave':    os.path.join(os.environ.get('LOCALAPPDATA', ''), 'BraveSoftware', 'Brave-Browser', 'User Data'),
    'edge':     os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Microsoft', 'Edge', 'User Data'),
    'chromium': os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Chromium', 'User Data'),
}

_BROWSER_PROC = {'chrome': 'chrome.exe', 'brave': 'brave.exe',
                 'edge':   'msedge.exe', 'chromium': 'chrome.exe'}


def _is_process_running(exe_name: str) -> bool:
    try:
        out = subprocess.check_output(
            ['tasklist', '/FI', f'IMAGENAME eq {exe_name}', '/NH', '/FO', 'CSV'],
            text=True, stderr=subprocess.DEVNULL, timeout=5)
        return exe_name.lower() in out.lower()
    except Exception:
        return False


def _find_browser_exe(browser: str):
    """Busca el ejecutable del navegador: primero procesos activos, luego rutas conocidas."""
    exe_name = _BROWSER_PROC.get(browser)
    if exe_name:
        try:
            out = subprocess.check_output(
                ['wmic', 'process', 'where', f'name="{exe_name}"',
                 'get', 'ExecutablePath'],
                text=True, stderr=subprocess.DEVNULL, timeout=5)
            for line in out.splitlines():
                line = line.strip()
                if line and line != 'ExecutablePath' and os.path.isfile(line):
                    return line
        except Exception:
            pass
    for p in _BROWSER_EXE_PATHS.get(browser, []):
        if p and os.path.isfile(p):
            return p
    return None


def _ensure_websocket_client(log_fn=None):
    try:
        import websocket  # noqa: F401
        return True
    except ImportError:
        if log_fn: log_fn("  [cookies] instalando websocket-client…")
        r = subprocess.run(
            [sys.executable, '-m', 'pip', 'install', '-q', 'websocket-client'],
            capture_output=True)
        return r.returncode == 0


def extract_cookies_auto(browser: str, log_fn=None):
    """
    Extrae cookies de YouTube/Google lanzando el navegador en modo headless con
    el protocolo DevTools. Funciona con v20 App-Bound Encryption porque es el
    propio navegador quien descifra sus cookies.

    Devuelve (cookie_file_temp, browser_exe_path). El archivo se borra después.
    """
    def _log(m):
        if log_fn: log_fn(m)

    exe = _find_browser_exe(browser)
    ud  = _BROWSER_USERDATAS.get(browser)
    if not exe:
        _log(f"  [cookies] {browser}: ejecutable no encontrado")
        return None, None

    # Marca de si el navegador estaba abierto (para saber si reabrirlo al final)
    proc_name   = os.path.basename(exe)
    was_running = _is_process_running(proc_name)
    reopen_exe  = exe if was_running else None

    if not ud or not os.path.isdir(ud):
        _log(f"  [cookies] {browser}: carpeta de usuario no encontrada ({ud})")
        return None, reopen_exe

    # 1. Cerrar instancias existentes (sólo si estaba corriendo)
    if was_running:
        _log(f"  [cookies] cerrando {proc_name}…")
        subprocess.run(['taskkill', '/F', '/IM', proc_name, '/T'],
                       capture_output=True)
        time.sleep(1.5)

    # 2. websocket-client
    if not _ensure_websocket_client(log_fn):
        _log("  [cookies] no se pudo instalar websocket-client")
        return None, reopen_exe

    # 3. Puerto libre
    s = socket.socket(); s.bind(('127.0.0.1', 0))
    port = s.getsockname()[1]; s.close()

    # 4. Lanzar navegador headless apuntando al perfil real
    args = [exe,
            f'--remote-debugging-port={port}',
            '--remote-allow-origins=*',
            '--headless=new',
            '--disable-gpu',
            '--no-first-run',
            '--no-default-browser-check',
            '--disable-extensions',
            '--disable-background-networking',
            f'--user-data-dir={ud}']
    proc = subprocess.Popen(args,
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                            creationflags=0x08000000)  # CREATE_NO_WINDOW

    # 5. Esperar a que DevTools responda
    ws_url = None
    for _ in range(100):  # hasta 20s
        try:
            with urllib.request.urlopen(
                    f'http://127.0.0.1:{port}/json/version',
                    timeout=0.5) as r:
                ws_url = _json.loads(r.read()).get('webSocketDebuggerUrl')
            if ws_url:
                break
        except Exception:
            time.sleep(0.2)

    if not ws_url:
        try: proc.terminate()
        except Exception: pass
        _log("  [cookies] DevTools no respondió")
        return None, reopen_exe

    cookies_raw = None
    try:
        import websocket
        ws = websocket.create_connection(ws_url, timeout=10)
        # Storage.getCookies funciona sobre el target del navegador (browser-level).
        # Network.getAllCookies requeriría attach a un page target.
        ws.send(_json.dumps({'id': 1, 'method': 'Storage.getCookies'}))
        for _ in range(50):
            msg = _json.loads(ws.recv())
            if msg.get('id') == 1:
                if 'error' in msg:
                    _log(f"  [cookies] CDP error: {msg['error']}")
                    # Fallback: Network.getAllCookies (requiere target; probamos igualmente)
                    ws.send(_json.dumps({'id': 2, 'method': 'Network.getAllCookies'}))
                    for _ in range(30):
                        m2 = _json.loads(ws.recv())
                        if m2.get('id') == 2:
                            cookies_raw = m2.get('result', {}).get('cookies', [])
                            break
                else:
                    cookies_raw = msg.get('result', {}).get('cookies', [])
                break
        ws.close()
    except Exception as e:
        _log(f"  [cookies] WebSocket: {e}")
    finally:
        try:
            proc.terminate()
            proc.wait(timeout=3)
        except Exception:
            try: proc.kill()
            except Exception: pass
        # Matar también cualquier child de la instancia headless
        subprocess.run(['taskkill', '/F', '/IM', proc_name, '/T'],
                       capture_output=True)
        time.sleep(0.5)

    if not cookies_raw:
        _log("  [cookies] respuesta CDP vacía")
        return None, reopen_exe

    # 6. Filtrar dominios útiles para YouTube/Google
    keep = ('youtube', 'google', 'ytimg', 'googlevideo', 'gstatic')
    relevant = [c for c in cookies_raw
                if any(k in c.get('domain', '').lower() for k in keep)]
    if not relevant:
        _log(f"  [cookies] 0 cookies de YouTube/Google (sesión no iniciada en {browser}?)")
        return None, reopen_exe

    # 7. Escribir formato Netscape
    lines = ["# Netscape HTTP Cookie File\n"]
    for c in relevant:
        dom  = c.get('domain', '')
        sub  = 'TRUE' if dom.startswith('.') else 'FALSE'
        path = c.get('path', '/')
        sec  = 'TRUE' if c.get('secure') else 'FALSE'
        exp  = int(c.get('expires', 0) or 0)
        if exp < 0:
            exp = 0
        name  = c.get('name', '')
        value = c.get('value', '')
        if not name or value is None:
            continue
        # Sin tabs ni saltos en valores (por si acaso)
        value = value.replace('\t', ' ').replace('\n', ' ').replace('\r', '')
        lines.append(f"{dom}\t{sub}\t{path}\t{sec}\t{exp}\t{name}\t{value}\n")

    tmp = tempfile.NamedTemporaryFile(mode='w', suffix='.txt',
                                      prefix='vdlcookies_',
                                      delete=False, encoding='utf-8')
    tmp.writelines(lines)
    tmp.close()
    _log(f"  [cookies] {len(relevant)} cookies OK → se borrarán al terminar")
    return tmp.name, reopen_exe


def reopen_browser_exe(exe_path: str | None, log_fn=None):
    """Reabre el navegador normalmente en segundo plano."""
    if not exe_path or not os.path.isfile(exe_path):
        return
    try:
        subprocess.Popen([exe_path],
                         creationflags=0x00000008)  # DETACHED_PROCESS
        if log_fn:
            log_fn(f"  {os.path.basename(exe_path)} reabierto")
    except Exception as e:
        if log_fn:
            log_fn(f"  No se pudo reabrir el navegador: {e}")


# ─── Utilidades ───────────────────────────────────────────────────────────────


def check_ffmpeg():
    try:
        r = subprocess.run(['ffmpeg', '-version'], capture_output=True)
        return r.returncode == 0
    except FileNotFoundError:
        return False


def parse_time_to_seconds(t: str) -> float:
    """Acepta HH:MM:SS, MM:SS o segundos directamente."""
    t = t.strip()
    if re.match(r'^\d+(\.\d+)?$', t):
        return float(t)
    parts = t.split(':')
    if len(parts) == 2:
        return int(parts[0]) * 60 + float(parts[1])
    if len(parts) == 3:
        return int(parts[0]) * 3600 + int(parts[1]) * 60 + float(parts[2])
    raise ValueError(f"Formato de tiempo inválido: '{t}'\nUsa HH:MM:SS, MM:SS o segundos.")


def safe_filename(title: str, max_len: int = 80) -> str:
    s = re.sub(r'[\\/*?:"<>|\t\n\r]', '_', title).strip('. _')
    s = re.sub(r'_+', '_', s)
    return s[:max_len] if s else 'video'


def unique_path(path: str) -> str:
    if not os.path.exists(path):
        return path
    base, ext = os.path.splitext(path)
    i = 1
    while os.path.exists(f"{base}_{i}{ext}"):
        i += 1
    return f"{base}_{i}{ext}"


class DownloadCancelled(Exception):
    pass


# ─── UI Principal ─────────────────────────────────────────────────────────────

# ─── Paleta y tipografía ────────────────────────────────────────────────────────
BG        = "#0a0a12"   # fondo principal
BG2       = "#13131f"   # tarjetas
BG3       = "#1c1c2b"   # inputs / controles
BORDER    = "#2a2a3e"   # bordes sutiles
ACCENT    = "#e94560"   # rojo/rosa de marca
ACCENT_HI = "#ff5d77"   # hover del acento
ACCENT2   = "#5b8cff"   # azul secundario
GREEN     = "#2ee6a0"   # verde de éxito
FG        = "#ececf7"   # texto principal
FG_MID    = "#9a9ac0"   # texto medio
FG_DIM    = "#5b5b80"   # texto tenue
FONT      = "Segoe UI"


class VideoDownloaderApp:

    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("Video Downloader Pro — Premiere Ready")
        self.root.geometry("720x790")
        self.root.configure(bg=BG)
        self.root.minsize(660, 700)
        self.root.resizable(True, True)

        self._thread: threading.Thread | None = None
        self._stop = False
        self._seg_buttons = {}

        self._setup_ttk_styles()
        self._build_ui()
        self._check_deps_async()

    # ── Estilos ttk ───────────────────────────────────────────────────────────────

    def _setup_ttk_styles(self):
        s = ttk.Style()
        s.theme_use('clam')
        s.configure('Bar.Horizontal.TProgressbar',
                    troughcolor=BG3, background=ACCENT,
                    lightcolor=ACCENT, darkcolor=ACCENT,
                    bordercolor=BG3, thickness=8)
        s.configure('Vdl.TCombobox',
                    fieldbackground=BG3, background=BG3, foreground=FG,
                    arrowcolor=FG_MID, bordercolor=BORDER,
                    lightcolor=BORDER, darkcolor=BORDER, relief='flat')
        s.map('Vdl.TCombobox',
              fieldbackground=[('readonly', BG3)],
              selectbackground=[('readonly', BG3)],
              selectforeground=[('readonly', FG)],
              bordercolor=[('focus', ACCENT)])

    # ── Comprobación de dependencias ──────────────────────────────────────────────

    def _check_deps_async(self):
        threading.Thread(target=self._check_deps, daemon=True).start()

    def _check_deps(self):
        try:
            import yt_dlp  # noqa: F401
        except ImportError:
            self._log("⚠  yt-dlp no encontrado — se instalará al descargar")

        if not check_ffmpeg():
            self._log("⚠  FFmpeg no encontrado en el PATH")
            self._log("   Instálalo: winget install Gyan.FFmpeg")
            self._log("   O descárgalo de https://ffmpeg.org/download.html")
        else:
            self._log("✓  FFmpeg detectado")

        try:
            import yt_dlp  # noqa: F401
            self._log("✓  yt-dlp detectado")
        except ImportError:
            pass

    # ── Helpers visuales ──────────────────────────────────────────────────────────

    def _hover(self, w, normal, hot):
        w.bind("<Enter>", lambda _e: w.config(bg=hot))
        w.bind("<Leave>", lambda _e: w.config(bg=normal))

    def _pill(self, parent, text):
        lbl = tk.Label(parent, text=text, bg=BG3, fg=FG_MID,
                       font=(FONT, 8), padx=11, pady=4)
        lbl.pack(side=tk.LEFT, padx=(0, 7))
        return lbl

    def _card(self, parent, title: str) -> tk.Frame:
        # Borde sutil simulado con un frame contenedor de 1px
        shell = tk.Frame(parent, bg=BORDER)
        shell.pack(fill=tk.X, pady=(0, 11))
        outer = tk.Frame(shell, bg=BG2, padx=16, pady=14)
        outer.pack(fill=tk.X, padx=1, pady=1)

        head = tk.Frame(outer, bg=BG2)
        head.pack(fill=tk.X, pady=(0, 11))
        tk.Frame(head, bg=ACCENT, width=3, height=13).pack(side=tk.LEFT, padx=(0, 9))
        tk.Label(head, text=title, bg=BG2, fg=FG_MID,
                 font=(FONT, 8, "bold")).pack(side=tk.LEFT)
        return outer

    def _btn(self, parent, text, cmd, color=None):
        c = color or BG3
        hot = BORDER if c == BG3 else ACCENT_HI
        b = tk.Button(parent, text=text, command=cmd,
                      bg=c, fg=FG, relief="flat", bd=0,
                      font=(FONT, 9), cursor="hand2",
                      activebackground=hot, activeforeground=FG,
                      padx=12, pady=6,
                      highlightthickness=1, highlightbackground=BORDER)
        self._hover(b, c, hot)
        return b

    def _time_entry(self, parent, var: tk.StringVar) -> tk.Entry:
        return tk.Entry(parent, textvariable=var,
                        bg=BG3, fg=FG, insertbackground=ACCENT,
                        disabledforeground="#3a3a52", disabledbackground=BG3,
                        font=(FONT, 10), width=9, relief="flat",
                        highlightthickness=1, highlightbackground=BORDER,
                        highlightcolor=ACCENT, state="disabled")

    def _select_type(self, val):
        self.dl_type.set(val)
        for v, b in self._seg_buttons.items():
            if v == val:
                b.config(bg=ACCENT, fg="white", font=(FONT, 9, "bold"))
            else:
                b.config(bg=BG3, fg=FG_MID, font=(FONT, 9))

    # ── Construcción de UI ────────────────────────────────────────────────────────

    def _build_ui(self):
        wrap = tk.Frame(self.root, bg=BG)
        wrap.pack(fill=tk.BOTH, expand=True, padx=24, pady=20)

        # ── Cabecera ──────────────────────────────────────────────────────────────
        header = tk.Frame(wrap, bg=BG)
        header.pack(fill=tk.X)

        logo = tk.Label(header, text="⬇", bg=ACCENT, fg="white",
                        font=(FONT, 17, "bold"), padx=12, pady=3)
        logo.pack(side=tk.LEFT, padx=(0, 13))

        titlebox = tk.Frame(header, bg=BG)
        titlebox.pack(side=tk.LEFT, anchor="w")
        tk.Label(titlebox, text="VIDEO DOWNLOADER PRO",
                 bg=BG, fg=FG, font=(FONT, 18, "bold")).pack(anchor="w")
        tk.Label(titlebox, text="Descarga · recorta · listo para Adobe Premiere",
                 bg=BG, fg=FG_DIM, font=(FONT, 9)).pack(anchor="w", pady=(1, 0))

        # Pills de plataformas
        pills = tk.Frame(wrap, bg=BG)
        pills.pack(fill=tk.X, pady=(14, 18))
        for p in ["YouTube", "TikTok", "Instagram", "X / Twitter", "Facebook"]:
            self._pill(pills, p)

        # ── URL ─────────────────────────────────────────────────────────────────────
        url_card = self._card(wrap, "URL DEL VÍDEO")
        url_row = tk.Frame(url_card, bg=BG2)
        url_row.pack(fill=tk.X)

        self.url_var = tk.StringVar()
        url_ent = tk.Entry(url_row, textvariable=self.url_var,
                           bg=BG3, fg=FG, insertbackground=ACCENT,
                           font=(FONT, 11), relief="flat",
                           highlightthickness=1,
                           highlightcolor=ACCENT, highlightbackground=BORDER)
        url_ent.pack(side=tk.LEFT, fill=tk.X, expand=True, ipady=8)
        url_ent.bind('<Return>', lambda _: self.start_download())

        self._btn(url_row, "  Pegar  ", self.paste_url).pack(side=tk.RIGHT, padx=(8, 0))

        # ── Opciones ──────────────────────────────────────────────────────────────
        opt_card = self._card(wrap, "OPCIONES DE DESCARGA")

        # Modo (control segmentado)
        mode_row = tk.Frame(opt_card, bg=BG2)
        mode_row.pack(fill=tk.X, pady=(0, 13))
        tk.Label(mode_row, text="Contenido", bg=BG2, fg=FG_MID,
                 font=(FONT, 9), width=10, anchor="w").pack(side=tk.LEFT)

        self.dl_type = tk.StringVar(value="av")
        seg = tk.Frame(mode_row, bg=BORDER)
        seg.pack(side=tk.LEFT)
        for label, val in [("🎬 Video + Audio", "av"),
                           ("🎥 Solo Video", "v"),
                           ("🎵 Solo Audio", "a")]:
            b = tk.Button(seg, text=label, relief="flat", bd=0,
                          font=(FONT, 9), cursor="hand2",
                          padx=13, pady=7, bg=BG3, fg=FG_MID,
                          activebackground=ACCENT, activeforeground="white",
                          command=lambda v=val: self._select_type(v))
            b.pack(side=tk.LEFT, padx=1, pady=1)
            self._seg_buttons[val] = b
        self._select_type("av")

        # Recorte de tiempo
        time_row = tk.Frame(opt_card, bg=BG2)
        time_row.pack(fill=tk.X)

        self.use_trim = tk.BooleanVar(value=False)
        tk.Checkbutton(time_row, text="✂  Recortar segmento",
                       variable=self.use_trim, command=self._toggle_trim,
                       bg=BG2, fg=FG, selectcolor=BG3,
                       activebackground=BG2, activeforeground=ACCENT,
                       font=(FONT, 9)).pack(side=tk.LEFT, padx=(0, 16))

        tk.Label(time_row, text="Inicio", bg=BG2, fg=FG_MID,
                 font=(FONT, 9)).pack(side=tk.LEFT, padx=(0, 5))
        self.t_start = tk.StringVar(value="00:00:00")
        self.ent_start = self._time_entry(time_row, self.t_start)
        self.ent_start.pack(side=tk.LEFT, padx=(0, 13), ipady=3)

        tk.Label(time_row, text="Fin", bg=BG2, fg=FG_MID,
                 font=(FONT, 9)).pack(side=tk.LEFT, padx=(0, 5))
        self.t_end = tk.StringVar(value="00:01:00")
        self.ent_end = self._time_entry(time_row, self.t_end)
        self.ent_end.pack(side=tk.LEFT, padx=(0, 11), ipady=3)

        tk.Label(time_row, text="HH:MM:SS o segundos", bg=BG2, fg=FG_DIM,
                 font=(FONT, 8)).pack(side=tk.LEFT)

        self._toggle_trim()

        # Separador
        tk.Frame(opt_card, bg=BORDER, height=1).pack(fill=tk.X, pady=15)

        # Acceso restringido / cookies
        auth_row = tk.Frame(opt_card, bg=BG2)
        auth_row.pack(fill=tk.X)

        tk.Label(auth_row, text="Acceso", bg=BG2, fg=FG_MID,
                 font=(FONT, 9), width=10, anchor="w").pack(side=tk.LEFT)

        self.bypass_var = tk.BooleanVar(value=True)
        tk.Checkbutton(auth_row, text="Auto-bypass edad",
                       variable=self.bypass_var,
                       bg=BG2, fg=FG, selectcolor=BG3,
                       activebackground=BG2, activeforeground=GREEN,
                       font=(FONT, 9)).pack(side=tk.LEFT, padx=(0, 22))

        tk.Label(auth_row, text="Cookies de", bg=BG2, fg=FG_MID,
                 font=(FONT, 9)).pack(side=tk.LEFT, padx=(0, 7))
        self.browser_var = tk.StringVar(value="none")
        browser_menu = ttk.Combobox(auth_row, textvariable=self.browser_var,
                                    values=["none", "chrome", "brave", "firefox", "edge", "chromium"],
                                    state="readonly", width=10,
                                    style="Vdl.TCombobox", font=(FONT, 9))
        browser_menu.pack(side=tk.LEFT, padx=(0, 10))

        # Archivo cookies.txt manual
        cookies_row = tk.Frame(opt_card, bg=BG2)
        cookies_row.pack(fill=tk.X, pady=(11, 0))

        tk.Label(cookies_row, text="cookies.txt", bg=BG2, fg=FG_MID,
                 font=(FONT, 9), width=10, anchor="w").pack(side=tk.LEFT)
        self.cookies_file_var = tk.StringVar(value="")
        tk.Entry(cookies_row, textvariable=self.cookies_file_var,
                 bg=BG3, fg=FG, insertbackground=ACCENT, font=(FONT, 9),
                 relief="flat", highlightthickness=1,
                 highlightbackground=BORDER, highlightcolor=ACCENT).pack(
            side=tk.LEFT, fill=tk.X, expand=True, ipady=5)
        self._btn(cookies_row, " Examinar ", self.browse_cookies_file).pack(
            side=tk.LEFT, padx=(8, 4))
        self._btn(cookies_row, " Limpiar ", lambda: self.cookies_file_var.set("")).pack(
            side=tk.LEFT)

        tk.Label(opt_card,
                 text="Si 'Auto-bypass' falla con vídeos con restricción de edad, exporta "
                      "cookies.txt con la extensión 'Get cookies.txt LOCALLY' desde una "
                      "pestaña de YouTube con sesión iniciada.",
                 bg=BG2, fg=FG_DIM, font=(FONT, 8), wraplength=600,
                 justify="left").pack(anchor="w", pady=(9, 0))

        # ── Destino ─────────────────────────────────────────────────────────────────
        dest_card = self._card(wrap, "CARPETA DE DESTINO")
        dest_row = tk.Frame(dest_card, bg=BG2)
        dest_row.pack(fill=tk.X)

        self.out_folder = tk.StringVar(value=str(Path.home() / "Downloads"))
        tk.Entry(dest_row, textvariable=self.out_folder,
                 bg=BG3, fg=FG, insertbackground=ACCENT, font=(FONT, 9),
                 relief="flat", highlightthickness=1,
                 highlightbackground=BORDER, highlightcolor=ACCENT).pack(
            side=tk.LEFT, fill=tk.X, expand=True, ipady=6)
        self._btn(dest_row, " Examinar ", self.browse_folder).pack(
            side=tk.RIGHT, padx=(8, 0))

        # ── Botones de acción ─────────────────────────────────────────────────────
        btn_row = tk.Frame(wrap, bg=BG)
        btn_row.pack(fill=tk.X, pady=(14, 8))

        self.dl_btn = tk.Button(btn_row, text="⬇   DESCARGAR",
                                bg=ACCENT, fg="white",
                                font=(FONT, 13, "bold"),
                                relief="flat", padx=20, pady=12, bd=0,
                                cursor="hand2", activebackground=ACCENT_HI,
                                activeforeground="white",
                                command=self.start_download)
        self.dl_btn.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 8))
        self._hover(self.dl_btn, ACCENT, ACCENT_HI)

        self.stop_btn = tk.Button(btn_row, text="✕  Detener",
                                  bg=BG2, fg=FG_MID,
                                  font=(FONT, 10), relief="flat",
                                  padx=16, pady=12, bd=0, cursor="hand2",
                                  highlightthickness=1, highlightbackground=BORDER,
                                  state="disabled", command=self.stop_download)
        self.stop_btn.pack(side=tk.RIGHT)

        # ── Progreso ────────────────────────────────────────────────────────────────
        self.prog_var = tk.DoubleVar()
        self.prog_bar = ttk.Progressbar(wrap, variable=self.prog_var,
                                        maximum=100, mode='determinate',
                                        style='Bar.Horizontal.TProgressbar')
        self.prog_bar.pack(fill=tk.X, pady=(2, 3))

        self.status_var = tk.StringVar(value="Listo.")
        tk.Label(wrap, textvariable=self.status_var, bg=BG, fg=FG_DIM,
                 font=(FONT, 8), anchor="w").pack(fill=tk.X, pady=(0, 8))

        # ── Log ───────────────────────────────────────────────────────────────────
        log_shell = tk.Frame(wrap, bg=BORDER)
        log_shell.pack(fill=tk.BOTH, expand=True)
        log_bg = tk.Frame(log_shell, bg=BG2, padx=6, pady=6)
        log_bg.pack(fill=tk.BOTH, expand=True, padx=1, pady=1)

        self.log_box = scrolledtext.ScrolledText(
            log_bg, bg="#06060f", fg=GREEN,
            font=("Consolas", 8), height=8,
            relief="flat", state="disabled",
            wrap=tk.WORD, insertbackground="white",
            selectbackground=ACCENT)
        self.log_box.pack(fill=tk.BOTH, expand=True)

        self.log_box.tag_config("err", foreground="#ff5566")
        self.log_box.tag_config("ok",  foreground=GREEN)
        self.log_box.tag_config("dim", foreground=FG_DIM)

    # ── Acciones de UI ────────────────────────────────────────────────────────────

    def paste_url(self):
        try:
            self.url_var.set(self.root.clipboard_get().strip())
        except Exception:
            pass


    def browse_folder(self):
        folder = filedialog.askdirectory(initialdir=self.out_folder.get())
        if folder:
            self.out_folder.set(folder)

    def browse_cookies_file(self):
        path = filedialog.askopenfilename(
            title="Selecciona cookies.txt",
            filetypes=[("Netscape cookies", "*.txt"), ("Todos", "*.*")])
        if path:
            self.cookies_file_var.set(path)

    def _toggle_trim(self):
        state = "normal" if self.use_trim.get() else "disabled"
        self.ent_start.config(state=state)
        self.ent_end.config(state=state)

    def start_download(self):
        if self._thread and self._thread.is_alive():
            return
        url = self.url_var.get().strip()
        if not url:
            messagebox.showerror("Error", "Introduce una URL primero.")
            return

        self._stop = False
        self._clear_log()
        self._set_prog(0)
        self.dl_btn.config(state="disabled", text="Descargando...")
        self.stop_btn.config(state="normal")

        self._thread = threading.Thread(target=self._worker, daemon=True)
        self._thread.start()

    def stop_download(self):
        self._stop = True
        self._set_status("Cancelando…")
        self._log("⚠  Cancelando…", tag="err")

    def _reset_ui(self):
        self.dl_btn.config(state="normal", text="⬇   DESCARGAR")
        self.stop_btn.config(state="disabled")
        self.prog_bar.config(mode='determinate')
        self.prog_bar.stop()

    # ── Log y estado ──────────────────────────────────────────────────────────

    def _log(self, msg: str, tag: str = ""):
        def _do():
            self.log_box.config(state="normal")
            self.log_box.insert(tk.END, msg + "\n", tag or "")
            self.log_box.see(tk.END)
            self.log_box.config(state="disabled")
        self.root.after(0, _do)

    def _clear_log(self):
        def _do():
            self.log_box.config(state="normal")
            self.log_box.delete("1.0", tk.END)
            self.log_box.config(state="disabled")
        self.root.after(0, _do)

    def _set_status(self, msg: str):
        self.root.after(0, lambda: self.status_var.set(msg))

    def _set_prog(self, val: float):
        self.root.after(0, lambda: self.prog_var.set(val))

    def _start_pulse(self):
        def _do():
            self.prog_bar.config(mode='indeterminate')
            self.prog_bar.start(12)
        self.root.after(0, _do)

    def _stop_pulse(self):
        def _do():
            self.prog_bar.stop()
            self.prog_bar.config(mode='determinate')
            self.prog_var.set(100)
        self.root.after(0, _do)

    # ── Hilo de descarga ──────────────────────────────────────────────────────

    def _worker(self):
        try:
            self._run_download()
        except DownloadCancelled:
            self._log("✗  Descarga cancelada.", tag="err")
            self._set_status("Cancelado.")
        except Exception as exc:
            self._log(f"✗  Error inesperado: {exc}", tag="err")
            self._set_status("Error.")
        finally:
            self.root.after(0, self._reset_ui)

    def _run_download(self):
        # Asegurarse de que yt-dlp está instalado
        try:
            import yt_dlp
        except ImportError:
            self._log("Instalando yt-dlp…", tag="dim")
            self._set_status("Instalando yt-dlp…")
            result = subprocess.run(
                [sys.executable, '-m', 'pip', 'install', '-q', 'yt-dlp'],
                capture_output=True
            )
            if result.returncode != 0:
                self._log("✗  No se pudo instalar yt-dlp.", tag="err")
                return
            import yt_dlp

        url         = self.url_var.get().strip()
        out_dir     = self.out_folder.get()
        dl_type     = self.dl_type.get()
        trim        = self.use_trim.get()
        bypass      = self.bypass_var.get()
        browser     = self.browser_var.get()
        cookies_txt = self.cookies_file_var.get().strip()

        os.makedirs(out_dir, exist_ok=True)

        temp_id   = f"_vdl_{uuid.uuid4().hex[:10]}"
        temp_tmpl = os.path.join(out_dir, f"{temp_id}.%(ext)s")

        self._log(f"→  {url}")
        self._set_status("Obteniendo información del vídeo…")

        # ── yt-dlp progress hook ──────────────────────────────────────────────
        def hook(d):
            if self._stop:
                raise DownloadCancelled()
            if d['status'] == 'downloading':
                try:
                    pct = float(d.get('_percent_str', '0%').strip().rstrip('%'))
                    self._set_prog(pct * 0.6)
                    speed = d.get('_speed_str', '').strip()
                    eta   = d.get('_eta_str', '').strip()
                    self._set_status(f"Descargando  {pct:.0f}%  —  {speed}  —  ETA {eta}")
                except Exception:
                    pass
            elif d['status'] == 'finished':
                fn = os.path.basename(d.get('filename', ''))
                self._log(f"  ✓  Descargado: {fn}", tag="dim")
                self._set_prog(62)

        # ── Opciones yt-dlp ───────────────────────────────────────────────────
        ydl_opts: dict = {
            'outtmpl':         temp_tmpl,
            'progress_hooks':  [hook],
            'noplaylist':      True,
            'retries':         3,
            'quiet':           True,
            'no_warnings':     True,
        }

        # Cookies: prioridad al archivo manual; si no, extracción automática con CDP
        cookie_file_temp = None       # archivo temporal creado por nosotros (a borrar)
        browser_exe_to_reopen = None
        has_cookies = False
        if cookies_txt:
            if os.path.isfile(cookies_txt):
                ydl_opts['cookiefile'] = cookies_txt
                self._log(f"  Cookies: archivo {os.path.basename(cookies_txt)}", tag="dim")
                has_cookies = True
            else:
                self._log(f"✗  cookies.txt no encontrado: {cookies_txt}", tag="err")
                self._set_status("Archivo cookies.txt inválido.")
                return
        elif browser != 'none':
            self._log(f"  Extrayendo cookies de {browser} (headless + DevTools)…", tag="dim")
            self._set_status(f"Cerrando {browser} y extrayendo cookies…")
            logfn = lambda m: self._log(m, tag="dim")
            cookie_file_temp, browser_exe_to_reopen = extract_cookies_auto(
                browser, log_fn=logfn)
            if browser_exe_to_reopen:
                reopen_browser_exe(browser_exe_to_reopen, log_fn=logfn)
            if cookie_file_temp:
                ydl_opts['cookiefile'] = cookie_file_temp
                has_cookies = True
            else:
                self._log(f"  ⚠  No se pudieron extraer cookies de {browser}. "
                          f"Sigo adelante sin cookies…", tag="err")

        # YouTube: con cookies dejamos el cliente por defecto (todos los formatos).
        # Sin cookies aplicamos el bypass con clients que no piden login.
        if bypass and not has_cookies:
            ydl_opts['extractor_args'] = {
                'youtube': {'player_client': ['tv_embedded', 'web_embedded', 'mweb', 'android']}
            }

        if dl_type == 'a':
            ydl_opts['format'] = 'bestaudio/best'
        elif dl_type == 'v':
            ydl_opts['format'] = 'bestvideo/best'
            ydl_opts['merge_output_format'] = 'mkv'
        else:
            ydl_opts['format'] = 'bestvideo+bestaudio/best'
            ydl_opts['merge_output_format'] = 'mkv'

        # ── Descarga ──────────────────────────────────────────────────────────
        title = "video"
        def _try_download(opts):
            with yt_dlp.YoutubeDL(opts) as ydl:
                return ydl.extract_info(url, download=True)

        try:
            try:
                info = _try_download(ydl_opts)
            except yt_dlp.utils.DownloadError as first:
                low = str(first).lower()
                # Diagnóstico: si YouTube devuelve needs_auth/solo storyboards,
                # significa que la cuenta de Google no está verificada en edad
                if 'format is not available' in low:
                    try:
                        with yt_dlp.YoutubeDL(
                                {**ydl_opts, 'quiet': True, 'no_warnings': True}) as ydl:
                            raw = ydl.extract_info(url, download=False, process=False)
                        avail = (raw.get('availability') or '').lower()
                        age   = raw.get('age_limit') or 0
                        fmts  = raw.get('formats') or []
                        only_sb = bool(fmts) and all(
                            f.get('ext') == 'mhtml' or
                            'storyboard' in (f.get('format_note') or '').lower()
                            for f in fmts)
                        if avail == 'needs_auth' or (age >= 18 and only_sb):
                            self._log("", tag="err")
                            self._log("  ⚠  YouTube solo devuelve miniaturas para este vídeo.", tag="err")
                            self._log("      Tu cuenta de Google NO está verificada en edad.", tag="err")
                            self._log("      Las cookies funcionan, pero el servidor retiene", tag="err")
                            self._log("      los streams hasta que verifiques tu edad en Google.", tag="err")
                            self._log("  →   Abre https://myaccount.google.com/birthday", tag="err")
                            self._log("      y confirma tu fecha de nacimiento (≥18).", tag="err")
                            self._log("      En UE/UK puede pedirte verificar con DNI o tarjeta.", tag="err")
                            self._set_status("Cuenta Google no verificada en edad.")
                            self._cleanup_temp(out_dir, temp_id)
                            return
                    except Exception:
                        pass
                    # Fallback genérico: reintentar con 'best'
                    if ydl_opts.get('format') != 'best':
                        self._log("  Formato no disponible; reintento con 'best'…",
                                  tag="dim")
                        ydl_opts['format'] = 'best'
                        ydl_opts.pop('merge_output_format', None)
                        info = _try_download(ydl_opts)
                    else:
                        raise
                else:
                    raise
            title = info.get('title', 'video')
        except DownloadCancelled:
            raise
        except Exception as exc:
            msg = str(exc)
            low = msg.lower()
            self._log(f"✗  Error de descarga: {msg}", tag="err")
            if ('age' in low or 'sign in' in low or 'confirm your age' in low
                    or 'inappropriate' in low):
                self._log("  →  El vídeo requiere sesión iniciada. Selecciona "
                          "tu navegador en 'Cookies de:' y reintenta.", tag="err")
            self._set_status("Error de descarga.")
            self._cleanup_temp(out_dir, temp_id)
            return
        finally:
            # Borrar el archivo temporal de cookies (nunca el manual del usuario)
            if cookie_file_temp and os.path.exists(cookie_file_temp):
                try: os.remove(cookie_file_temp)
                except Exception: pass

        if self._stop:
            self._cleanup_temp(out_dir, temp_id)
            raise DownloadCancelled()

        # Buscar el archivo descargado
        temp_files = [f for f in glob.glob(os.path.join(out_dir, f"{temp_id}.*"))
                      if not f.endswith(('.part', '.ytdl'))]

        if not temp_files:
            self._log("✗  No se encontró el archivo descargado.", tag="err")
            return

        temp_file = temp_files[0]
        self._log(f"  Archivo temporal: {os.path.basename(temp_file)}", tag="dim")

        # ── Nombre de salida ──────────────────────────────────────────────────
        safe  = safe_filename(title)
        if dl_type == 'a':
            out_ext, suffix = 'm4a', '_audio'
        elif dl_type == 'v':
            out_ext, suffix = 'mp4', '_video'
        else:
            out_ext, suffix = 'mp4', ''

        out_path = unique_path(os.path.join(out_dir, f"{safe}{suffix}.{out_ext}"))

        # ── FFmpeg ────────────────────────────────────────────────────────────
        if not check_ffmpeg():
            self._log("⚠  FFmpeg no disponible — guardando sin conversión.", tag="err")
            shutil.move(temp_file, out_path)
            self._finish(out_path)
            return

        self._log("→  Convirtiendo para Adobe Premiere (H.264 + AAC)…")
        self._set_status("Procesando con FFmpeg…")
        self._set_prog(65)
        self._start_pulse()

        # Validar tiempos si se recorta
        start_sec = end_sec = None
        if trim:
            try:
                start_sec = parse_time_to_seconds(self.t_start.get())
                end_sec   = parse_time_to_seconds(self.t_end.get())
                if end_sec <= start_sec:
                    self._stop_pulse()
                    self._log("✗  El tiempo de fin debe ser mayor que el de inicio.", tag="err")
                    self._cleanup_temp(out_dir, temp_id)
                    return
                self._log(f"  ✂  Recorte: {self.t_start.get()} → {self.t_end.get()}", tag="dim")
            except ValueError as exc:
                self._stop_pulse()
                self._log(f"✗  {exc}", tag="err")
                self._cleanup_temp(out_dir, temp_id)
                return

        # Construir comando ffmpeg
        cmd = ['ffmpeg', '-y', '-hide_banner', '-loglevel', 'warning']

        # Input seeking (antes del -i para velocidad máxima)
        if trim and start_sec is not None:
            cmd += ['-ss', str(start_sec)]

        cmd += ['-i', temp_file]

        if trim and end_sec is not None:
            # Duración relativa al punto de inicio
            cmd += ['-t', str(end_sec - start_sec)]

        if dl_type == 'a':
            # Solo audio → AAC en M4A (Premiere lo importa perfectamente)
            cmd += [
                '-vn',
                '-c:a', 'aac',
                '-ar', '48000',
                '-b:a', '320k',
                out_path
            ]
        elif dl_type == 'v':
            # Solo video → H.264 High Profile, sin audio
            cmd += [
                '-an',
                '-c:v', 'libx264',
                '-profile:v', 'high',
                '-level:v', '4.1',
                '-preset', 'slow',
                '-crf', '18',
                '-pix_fmt', 'yuv420p',
                out_path
            ]
        else:
            # Video + Audio → H.264 + AAC en MP4 (máxima compatibilidad Premiere)
            cmd += [
                '-c:v', 'libx264',
                '-profile:v', 'high',
                '-level:v', '4.1',
                '-preset', 'slow',
                '-crf', '18',
                '-pix_fmt', 'yuv420p',
                '-c:a', 'aac',
                '-ar', '48000',
                '-b:a', '192k',
                '-movflags', '+faststart',
                out_path
            ]

        self._log(f"  CMD: {' '.join(cmd)}", tag="dim")

        # Ejecutar ffmpeg con posibilidad de cancelar
        proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)

        while proc.poll() is None:
            if self._stop:
                proc.terminate()
                self._stop_pulse()
                self._cleanup_temp(out_dir, temp_id)
                try:
                    os.remove(out_path)
                except FileNotFoundError:
                    pass
                raise DownloadCancelled()
            time.sleep(0.3)

        self._stop_pulse()
        stderr_out = proc.stderr.read().decode('utf-8', errors='replace')

        if proc.returncode == 0:
            self._cleanup_temp(out_dir, temp_id)
            self._finish(out_path)
        else:
            self._log(f"✗  Error FFmpeg (código {proc.returncode}):", tag="err")
            if stderr_out:
                for line in stderr_out.strip().splitlines()[-8:]:
                    self._log(f"   {line}", tag="err")
            self._set_status("Error en FFmpeg.")

    # ── Helpers ───────────────────────────────────────────────────────────────

    def _cleanup_temp(self, out_dir: str, temp_id: str):
        for f in glob.glob(os.path.join(out_dir, f"{temp_id}.*")):
            try:
                os.remove(f)
            except OSError:
                pass

    def _finish(self, path: str):
        size_mb = os.path.getsize(path) / (1024 * 1024)
        self._log(f"✓  {os.path.basename(path)}  ({size_mb:.1f} MB)", tag="ok")
        self._set_status(f"Completado — {os.path.basename(path)}")
        self.root.after(0, lambda: messagebox.showinfo(
            "Descarga completada",
            f"Archivo guardado:\n{path}\n\nTamaño: {size_mb:.1f} MB"
        ))


# ─── Entrada ──────────────────────────────────────────────────────────────────

def main():
    root = tk.Tk()
    try:
        root.iconbitmap(default='')
    except Exception:
        pass
    app = VideoDownloaderApp(root)
    root.mainloop()


if __name__ == '__main__':
    main()
