# Free Video Downloader

Download YouTube and Instagram videos as MP4 or audio as MP3 from a compact desktop app. Choose from the available video resolutions and save files directly to your Downloads folder.

## Downloads

- [macOS — Apple Silicon & Intel (Beta)](https://github.com/atakanvass/free-video-downloader/releases/download/v0.1.0-beta/FreeVideoDownloader-macOS-beta.zip)
- [Windows x64 (Beta)](https://github.com/atakanvass/free-video-downloader/releases/download/v0.1.0-beta/FreeVideoDownloader-Windows-beta.zip)
- [Release notes and limitations](https://github.com/atakanvass/free-video-downloader/releases/tag/v0.1.0-beta)

Extract the ZIP and open the app. These beta builds are not Apple-notarized or Windows code-signed; your operating system may display a security warning.

## How to use

1. Open the app from the macOS menu bar or the Windows system tray.
2. Paste a video link and wait for the available formats.
3. Choose MP3 or a video resolution and click the download icon.
4. The progress bar shows the download and conversion stages. Your file is saved in Downloads.

MP4 videos are converted to H.264/AAC for playback compatibility.

## Build from source

### macOS

Install Xcode Command Line Tools, `yt-dlp` and `ffmpeg`:

```sh
xcode-select --install
brew install yt-dlp ffmpeg
bash build.sh
open build/Kaydet.app
```

### Windows

Install Python with Tkinter, Node.js 24 and FFmpeg/FFprobe. FFmpeg must include the `libx264`, `aac` and `libmp3lame` encoders.

```powershell
cd windows
python -m pip install -r requirements.txt
python kaydet.py
```

To build a standalone Windows executable, make FFmpeg, FFprobe and Node.js available on PATH, then run:

```powershell
powershell -ExecutionPolicy Bypass -File windows/build.ps1
```

The output is `windows/dist/Free Video Downloader.exe`.

## Notes

Platform access restrictions and changes may affect downloads. Download only content you have permission to save and follow the relevant platform terms.

No distribution license has yet been selected for this project's source code. yt-dlp, FFmpeg and other bundled components have their own licenses.
