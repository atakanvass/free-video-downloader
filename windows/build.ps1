$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$ffmpeg = (Get-Command ffmpeg.exe -ErrorAction Stop).Source
$ffprobe = (Get-Command ffprobe.exe -ErrorAction Stop).Source
python -m pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed' }
python -m PyInstaller --noconfirm --clean --onefile --console --name Kaydet --collect-all yt_dlp --collect-all yt_dlp_ejs --add-binary "$ffmpeg;." --add-binary "$ffprobe;." kaydet.py
if ($LASTEXITCODE -ne 0) { throw 'Windows build failed' }
Write-Host 'Ready: windows/dist/Kaydet.exe'
