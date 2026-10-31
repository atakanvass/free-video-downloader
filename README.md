# Free Video Downloader

## Download · İndir

- [macOS — Apple Silicon & Intel (Beta)](https://github.com/atakanvass/free-video-downloader/releases/download/v0.1.0-beta/FreeVideoDownloader-macOS-beta.zip)
- [Windows x64 (Beta)](https://github.com/atakanvass/free-video-downloader/releases/download/v0.1.0-beta/FreeVideoDownloader-Windows-beta.zip)
- [Release notes and limitations](https://github.com/atakanvass/free-video-downloader/releases/tag/v0.1.0-beta)

Extract the ZIP and open the application. These beta builds are not Apple-notarized or Windows code-signed. Intel Mac and complete Windows download flows have not yet been tested.

Kaynak kodda macOS ve Windows sürümleri yer alır. Windows sürümü henüz Windows üzerinde test edilmemiştir.

Mac menü çubuğundan YouTube ve Instagram bağlantılarını MP4 video veya MP3 ses olarak indirmek için kişisel bir uygulama. Dosyalar macOS İndirilenler klasörüne kaydedilir. MP4 videolar H.264/AAC biçimine dönüştürülür.

## Gereksinimler

- macOS ve Xcode Command Line Tools (`xcode-select --install`)
- Homebrew ile kurulu `yt-dlp` ve `ffmpeg`: `brew install yt-dlp ffmpeg`

Uygulama araçları `/opt/homebrew/bin` veya `/usr/local/bin` altında arar. Platform erişim kısıtlamaları ve araç güncellemeleri indirme başarısını etkileyebilir.

## Derleme ve çalıştırma

```sh
bash build.sh
open build/Kaydet.app
```

Üst menü çubuğundaki video simgesine tıklayıp bağlantıyı yapıştırın. Formatlar otomatik yüklendikten sonra MP3 veya istediğiniz çözünürlüğü seçip indirme simgesine tıklayın. Dönüştürme sırasında çubuk bu aşamanın yüzdesini gösterir; dosya kaydedildiğinde %100 olur.

Yalnızca indirme hakkına sahip olduğunuz içerikleri indirin ve platform koşullarını dikkate alın. Bu kaynak kod için henüz bir dağıtım lisansı belirlenmemiştir; yt-dlp ve FFmpeg kendi lisanslarıyla dağıtılır.

## Windows

Windows 10 veya 11 üzerinde Python (Tkinter dahil), Node.js 24 ve FFmpeg/FFprobe gereklidir. FFmpeg derlemesi `libx264`, `aac` ve `libmp3lame` kodlayıcılarını içermelidir. PowerShell üzerinden:

```powershell
cd windows
python -m pip install -r requirements.txt
python kaydet.py
```

Uygulama sistem tepsisinde çalışır. Pencereyi kapatmak uygulamayı tepsiye küçültür; simgenin menüsünden çıkılabilir.

Tek dosyalık Windows uygulamasını bir Windows bilgisayarda oluşturmak için FFmpeg ve FFprobe PATH üzerinde bulunurken `powershell -ExecutionPolicy Bypass -File windows/build.ps1` çalıştırın. Çıktı `windows/dist/Free Video Downloader.exe` olur. Bu derleme, bağımlılıkları ve FFmpeg araçlarını içerir. Bu projede henüz imzalı bir kurulum paketi veya Windows üzerinde doğrulanmış sürüm yoktur.
