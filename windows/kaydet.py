"""Kaydet for Windows. The same executable runs UI and isolated download workers."""
import ctypes
from ctypes import wintypes
import json
import os
from pathlib import Path
import queue
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import tkinter as tk
from tkinter import ttk
from urllib.parse import urlsplit

CREATE_NO_WINDOW = getattr(subprocess, 'CREATE_NO_WINDOW', 0)
ROOT = Path(getattr(sys, '_MEIPASS', Path(__file__).resolve().parent))

def binary(name):
    local = ROOT / (name + '.exe')
    return str(local) if local.is_file() else shutil.which(name)

def downloads_dir():
    class GUID(ctypes.Structure):
        _fields_ = [('Data1', wintypes.DWORD), ('Data2', wintypes.WORD), ('Data3', wintypes.WORD), ('Data4', ctypes.c_ubyte * 8)]
    guid = GUID(0x374DE290, 0x123F, 0x4565, (ctypes.c_ubyte * 8)(0x91, 0x64, 0x39, 0xC4, 0x92, 0x5E, 0x46, 0x7B))
    pointer = ctypes.c_wchar_p()
    if ctypes.windll.shell32.SHGetKnownFolderPath(ctypes.byref(guid), 0, None, ctypes.byref(pointer)) != 0:
        raise OSError('Downloads folder unavailable')
    try:
        return Path(pointer.value)
    finally:
        ctypes.windll.ole32.CoTaskMemFree(pointer)

def send(kind, **kwargs):
    print(json.dumps({'kind': kind, **kwargs}, ensure_ascii=True), flush=True)

def worker(mode, url, height=None):
    import yt_dlp
    node = binary('node')
    common = {'noplaylist': True, 'quiet': True, 'no_warnings': True, 'ignoreconfig': True}
    if node:
        common['js_runtimes'] = {'node': {'path': node}}
    try:
        if mode == 'formats':
            with yt_dlp.YoutubeDL(common) as ydl:
                info = ydl.extract_info(url, download=False)
            formats = info.get('formats') or []
            heights = sorted({f['height'] for f in formats if f.get('vcodec') not in (None, 'none') and isinstance(f.get('height'), int) and f['height'] > 0}, reverse=True)
            if not heights:
                raise RuntimeError('No video formats found')
            send('formats', heights=heights)
            return
        ffmpeg, ffprobe = binary('ffmpeg'), binary('ffprobe')
        if not ffmpeg or not ffprobe:
            raise RuntimeError('FFmpeg and FFprobe are required')
        audio = mode == 'audio'
        selected = 'bestaudio/best' if audio else f'bv*[height={int(height)}]+ba/b[height={int(height)}][acodec!=none]'
        with tempfile.TemporaryDirectory(prefix='kaydet-') as temp:
            def progress(data):
                if data['status'] == 'downloading':
                    total = data.get('total_bytes') or data.get('total_bytes_estimate')
                    if total:
                        send('progress', phase='download', value=min(99, 100 * data.get('downloaded_bytes', 0) / total))
            options = dict(common, format=selected, outtmpl=str(Path(temp) / '%(title).120s [%(id)s].%(ext)s'), progress_hooks=[progress], ffmpeg_location=str(Path(ffmpeg).parent))
            with yt_dlp.YoutubeDL(options) as ydl:
                info = ydl.extract_info(url, download=True)
                path = Path(info.get('filepath') or ydl.prepare_filename(info))
                if not path.is_file():
                    candidates = [p for p in Path(temp).iterdir() if p.is_file() and not p.name.endswith(('.part', '.ytdl'))]
                    if len(candidates) != 1:
                        raise RuntimeError('Downloaded file could not be located')
                    path = candidates[0]
            probe = subprocess.run([ffprobe, '-v', 'error', '-show_entries', 'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1', str(path)], capture_output=True, text=True, creationflags=CREATE_NO_WINDOW)
            try:
                duration = float(probe.stdout.strip())
                if duration <= 0:
                    duration = None
            except ValueError:
                duration = None
            ext = '.mp3' if audio else '.mp4'
            result = Path(temp) / ('converted' + ext)
            codec = ['-vn', '-c:a', 'libmp3lame', '-q:a', '2'] if audio else ['-map', '0:v:0', '-map', '0:a:0?', '-c:v', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart']
            send('progress', phase='convert', value=0 if duration else None)
            command = [ffmpeg, '-nostdin', '-hide_banner', '-loglevel', 'error', '-progress', 'pipe:1', '-nostats', '-y', '-i', str(path), *codec, str(result)]
            with tempfile.TemporaryFile(mode='w+', encoding='utf-8') as errors:
                process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=errors, text=True, encoding='utf-8', errors='replace', creationflags=CREATE_NO_WINDOW)
                for line in process.stdout:
                    if line.startswith('out_time_us=') and duration:
                        try:
                            send('progress', phase='convert', value=min(99, max(0, int(line.split('=', 1)[1]) / 1_000_000 / duration * 100)))
                        except ValueError:
                            pass
                if process.wait() != 0 or not result.is_file():
                    errors.seek(0)
                    raise RuntimeError('Conversion failed: ' + errors.read()[-1200:])
            folder = downloads_dir()
            target = folder / (path.stem + ext)
            i = 2
            while target.exists():
                target = folder / f'{path.stem} ({i}){ext}'
                i += 1
            shutil.copyfile(result, target)
            send('done', path=str(target))
    except Exception as exc:
        send('error', message=str(exc))
        sys.exit(1)

def allowed(url):
    try:
        parsed = urlsplit(url)
        host = (parsed.hostname or '').lower()
        return parsed.scheme in ('http', 'https') and not parsed.username and any(host == x or host.endswith('.' + x) for x in ('youtube.com', 'youtu.be', 'instagram.com'))
    except ValueError:
        return False

class App:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title('Free Video Downloader')
        self.root.resizable(False, False)
        self.root.geometry('380x170')
        self.url = tk.StringVar()
        self.url.trace_add('write', self.changed)
        self.choice = tk.StringVar()
        self.events = queue.Queue()
        self.known = None
        self.timer = None
        self.busy = False
        frame = ttk.Frame(self.root, padding=16)
        frame.pack(fill='both', expand=True)
        self.entry = ttk.Entry(frame, textvariable=self.url)
        self.entry.pack(fill='x', ipady=5)
        row = ttk.Frame(frame)
        row.pack(fill='x', pady=(14, 8))
        self.formats = ttk.Combobox(row, textvariable=self.choice, state='disabled', values=['🎧 MP3'])
        self.formats.pack(side='left', fill='x', expand=True)
        self.button = ttk.Button(row, text='↓', command=self.download, state='disabled')
        self.button.pack(side='left', fill='x', expand=True, padx=(8, 0))
        self.bar = ttk.Progressbar(frame, maximum=100)
        self.bar.pack(fill='x', pady=(2, 3))
        self.status = ttk.Label(frame, text='')
        self.status.pack(anchor='w')
        self.root.protocol('WM_DELETE_WINDOW', self.hide)
        self.root.after(100, self.process_events)
        self.tray = None
        self.install_tray()
    def install_tray(self):
        try:
            import pystray
            from PIL import Image, ImageDraw
            im = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
            draw = ImageDraw.Draw(im)
            draw.rounded_rectangle((4, 10, 60, 54), radius=9, fill='#286d56')
            draw.polygon([(26, 20), (26, 44), (46, 32)], fill='white')
            self.tray = pystray.Icon('FreeVideoDownloader', im, 'Free Video Downloader', menu=pystray.Menu(pystray.MenuItem('Open', lambda *_: self.root.after(0, self.show), default=True), pystray.MenuItem('Exit', lambda *_: self.root.after(0, self.exit))))
            threading.Thread(target=self.tray.run, daemon=True).start()
        except ImportError:
            self.tray = None
    def show(self):
        self.root.deiconify()
        self.root.lift()
        self.entry.focus_set()
    def hide(self):
        if self.tray:
            self.root.withdraw()
        else:
            self.exit()
    def exit(self):
        if self.busy:
            self.status.config(text='⚠ Download in progress')
            self.show()
            return
        if self.tray:
            self.tray.stop()
        self.root.destroy()
    def changed(self, *_):
        if self.busy:
            return
        if self.timer:
            self.root.after_cancel(self.timer)
        self.known = None
        self.formats.config(state='disabled')
        self.button.config(state='disabled')
        self.status.config(text='')
        if allowed(self.url.get().strip()):
            self.timer = self.root.after(600, self.load)
    def start(self, mode, url, height=None):
        self.busy = True
        self.entry.config(state='disabled')
        self.formats.config(state='disabled')
        self.button.config(state='disabled')
        self.status.config(text='…')
        args = [sys.executable, '--worker', mode, url] if getattr(sys, 'frozen', False) else [sys.executable, __file__, '--worker', mode, url]
        if height is not None:
            args.append(str(height))
        def run():
            try:
                with tempfile.TemporaryFile(mode='w+', encoding='utf-8') as errors:
                    process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=errors, text=True, encoding='utf-8', errors='replace', creationflags=CREATE_NO_WINDOW)
                    delivered_terminal = False
                    for line in process.stdout:
                        try:
                            event = json.loads(line)
                            delivered_terminal |= event.get('kind') in ('error', 'done', 'formats')
                            self.events.put((url, event))
                        except ValueError:
                            pass
                    code = process.wait()
                    if not delivered_terminal:
                        errors.seek(0)
                        self.events.put((url, {'kind': 'error', 'message': errors.read()[-1200:] or f'Worker exited: {code}'}))
            except Exception as exc:
                self.events.put((url, {'kind': 'error', 'message': str(exc)}))
        threading.Thread(target=run, daemon=True).start()
    def load(self):
        url = self.url.get().strip()
        if allowed(url):
            self.start('formats', url)
    def download(self):
        if not self.known or self.known != self.url.get().strip():
            return
        value = self.choice.get()
        if value == '🎧 MP3':
            self.start('audio', self.known)
        else:
            try:
                self.start('video', self.known, int(value.split()[-1].rstrip('p')))
            except ValueError:
                self.status.config(text='⚠')
    def process_events(self):
        while True:
            try:
                url, event = self.events.get_nowait()
            except queue.Empty:
                break
            kind = event.get('kind')
            if kind == 'progress':
                value = event.get('value')
                if value is None:
                    self.bar.configure(mode='indeterminate')
                    self.bar.start(10)
                    self.status.config(text='⚙ …')
                else:
                    self.bar.stop()
                    self.bar.configure(mode='determinate', value=value)
                    self.status.config(text=('⚙ ' if event.get('phase') == 'convert' else '') + f'{int(value)}%')
            elif kind in ('formats', 'done', 'error'):
                self.busy = False
                self.entry.config(state='normal')
                self.bar.stop()
                self.bar.configure(mode='determinate')
                if kind == 'formats':
                    self.known = url
                    values = ['🎧 MP3'] + [f'▣ {h}p' for h in event['heights']]
                    self.formats.config(values=values, state='readonly')
                    self.choice.set(values[0])
                    self.button.config(state='normal')
                    self.status.config(text='')
                elif kind == 'done':
                    self.bar.configure(value=100)
                    self.status.config(text='100% ✓')
                    self.known = None
                    self.url.set('')
                else:
                    self.status.config(text='⚠ ' + event.get('message', 'Error')[:120])
                    if self.known:
                        self.formats.config(state='readonly')
                        self.button.config(state='normal')
        self.root.after(100, self.process_events)

if __name__ == '__main__':
    if len(sys.argv) >= 2 and sys.argv[1] == '--self-test':
        import yt_dlp
        for name in ('ffmpeg', 'ffprobe', 'node'):
            path = binary(name)
            argument = '--version' if name == 'node' else '-version'
            if not path or subprocess.run([path, argument], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=CREATE_NO_WINDOW).returncode:
                print(f'Self-test failed: {name}', flush=True)
                raise SystemExit(1)
        raise SystemExit(0)
    if len(sys.argv) >= 4 and sys.argv[1] == '--worker':
        worker(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else None)
    else:
        if sys.platform == 'win32':
            console = ctypes.windll.kernel32.GetConsoleWindow()
            if console:
                ctypes.windll.user32.ShowWindow(console, 0)
        App().root.mainloop()
