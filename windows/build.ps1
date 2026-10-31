$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$chocoTools = Join-Path $env:ProgramData 'chocolatey\lib\ffmpeg\tools'
$realFfmpeg = if (Test-Path $chocoTools) { Get-ChildItem $chocoTools -Filter ffmpeg.exe -File -Recurse | Select-Object -First 1 } else { $null }
$ffmpeg = if ($realFfmpeg) { $realFfmpeg.FullName } else { (Get-Command ffmpeg.exe -ErrorAction Stop).Source }
$node = (Get-Command node.exe -ErrorAction Stop).Source
$ffprobePath = Join-Path (Split-Path $ffmpeg) 'ffprobe.exe'
$ffprobe = if (Test-Path $ffprobePath) { $ffprobePath } else { (Get-Command ffprobe.exe -ErrorAction Stop).Source }
python -m pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed' }
python -m PyInstaller --noconfirm --clean --onefile --console --name "Free Video Downloader" --collect-all yt_dlp --collect-all yt_dlp_ejs --add-binary "$ffmpeg;." --add-binary "$ffprobe;." --add-binary "$node;." kaydet.py
if ($LASTEXITCODE -ne 0) { throw 'Windows build failed' }
Write-Host 'Ready: windows/dist/Free Video Downloader.exe'
