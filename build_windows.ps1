#Requires -Version 5.1
<#
Windows x64 release build, mirroring .github/workflows/flutter-build-windows.yml.
No parameters. RENDEZVOUS_SERVERS and RS_PUB_KEY are exported from .\.env (see .env.example).

One-time prereqs, run from a "Developer PowerShell for VS" (MSVC C++ tools on PATH):
  - Rust 1.75 via rustup            https://rustup.rs
  - Flutter 3.24.5 on PATH          https://docs.flutter.dev/get-started/install/windows
  - LLVM 15 at C:\Program Files\LLVM (or set $env:LLVM_PATH)
  - vcpkg at C:\vcpkg (or set $env:VCPKG_ROOT), bootstrapped, at commit 9e593bb1
  - Python 3, git, CMake, Ninja, NASM on PATH
Output: flutter\build\windows\x64\runner\Release\
#>
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$FlutterVersion = '3.24.5'
$FlutterRustBridgeVersion = '1.80.1'
$CargoExpandVersion = '1.0.95'
$Triplet = 'x64-windows-static'

if (-not $env:VCPKG_ROOT) { $env:VCPKG_ROOT = 'C:\vcpkg' }
if (-not $env:LLVM_PATH)  { $env:LLVM_PATH  = 'C:\Program Files\LLVM' }
if (-not $env:LIBCLANG_PATH) { $env:LIBCLANG_PATH = Join-Path $env:LLVM_PATH 'bin' }
$env:VCPKG_DEFAULT_HOST_TRIPLET = $Triplet
$env:PATH = "$($env:LLVM_PATH)\bin;$env:USERPROFILE\.cargo\bin;$env:PATH"

function Need([string]$Cmd, [string]$Hint) {
    if (-not (Get-Command $Cmd -ErrorAction SilentlyContinue)) { throw "'$Cmd' not found. $Hint" }
}
function Run([string]$Cmd, [string[]]$CmdArgs) {
    & $Cmd @CmdArgs
    if ($LASTEXITCODE -ne 0) { throw "$Cmd $($CmdArgs -join ' ') failed with exit code $LASTEXITCODE" }
}
# Run a native command whose stderr/non-zero exit must not abort the script.
function Quiet([scriptblock]$Block) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $Block 2>$null } finally { $ErrorActionPreference = $prev }
}

Need cargo   'Install Rust 1.75 with rustup.'
Need flutter "Install Flutter $FlutterVersion and add flutter\bin to PATH."
Need git     'Install git.'
$Python = if (Get-Command python3 -ErrorAction SilentlyContinue) { 'python3' } else { 'python' }
Need $Python 'Install Python 3.'
if (-not (Test-Path "$env:VCPKG_ROOT\vcpkg.exe")) { throw "vcpkg.exe not found at VCPKG_ROOT=$env:VCPKG_ROOT" }
if (-not (Test-Path "$env:LLVM_PATH\bin\libclang.dll")) { throw "libclang.dll not found under LLVM_PATH=$env:LLVM_PATH" }

Write-Host '==> submodules'
Run git @('submodule', 'update', '--init', '--recursive')

# Server and key are compiled in via option_env!() in libs/hbb_common/src/config.rs.
# Export them from .env, exactly like CI exports its secrets. Variables already set
# in the environment take precedence over the file.
if (Test-Path '.env') {
    foreach ($raw in Get-Content '.env') {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        if ($line.StartsWith('export ')) { $line = $line.Substring(7) }
        $eq = $line.IndexOf('=')
        if ($eq -lt 1) { continue }
        $key = $line.Substring(0, $eq).Trim()
        if ($key -notin @('RENDEZVOUS_SERVERS', 'RS_PUB_KEY')) { continue }
        if ([Environment]::GetEnvironmentVariable($key)) { continue }
        $value = $line.Substring($eq + 1).Trim()
        if ($value.Length -ge 2 -and (($value[0] -eq '"' -and $value[-1] -eq '"') -or ($value[0] -eq "'" -and $value[-1] -eq "'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        if ($value) { [Environment]::SetEnvironmentVariable($key, $value, 'Process') }
    }
}
if (-not $env:RENDEZVOUS_SERVERS -or -not $env:RS_PUB_KEY) {
    Write-Warning 'RENDEZVOUS_SERVERS / RS_PUB_KEY not set; the build will default to the public rustdesk server.'
    Write-Warning 'Copy .env.example to .env and fill them in.'
} else {
    Write-Host "==> server: $env:RENDEZVOUS_SERVERS"
}

if (-not (Test-Path "$env:VCPKG_ROOT\installed\$Triplet\lib\opus.lib")) {
    Write-Host "==> vcpkg install ($Triplet), this builds ffmpeg and takes a while"
    Run "$env:VCPKG_ROOT\vcpkg.exe" @('install', '--triplet', $Triplet, "--x-install-root=$env:VCPKG_ROOT\installed")
}

Write-Host '==> rust helper tools'
Quiet { rustup component add rustfmt } | Out-Null
if (-not (Get-Command cargo-expand -ErrorAction SilentlyContinue)) {
    Run cargo @('install', 'cargo-expand', '--version', $CargoExpandVersion, '--locked')
}
if (-not (Get-Command flutter_rust_bridge_codegen -ErrorAction SilentlyContinue)) {
    Run cargo @('install', 'flutter_rust_bridge_codegen', '--version', $FlutterRustBridgeVersion, '--features', 'uuid', '--locked')
}

# CI patches Flutter 3.24.5's DropdownMenu; apply once, idempotently.
$FlutterDir = Split-Path (Split-Path (Get-Command flutter).Source)
$FlutterPatch = Join-Path $PSScriptRoot '.github\patches\flutter_3.24.4_dropdown_menu_enableFilter.diff'
$FlutterBanner = (Quiet { flutter --version } | Select-Object -First 1)
if ($FlutterBanner -match "Flutter $([regex]::Escape($FlutterVersion))") {
    Quiet { git -C $FlutterDir apply --check $FlutterPatch } | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "==> patching Flutter $FlutterVersion"
        Run git @('-C', $FlutterDir, 'apply', $FlutterPatch)
    }
}

Write-Host '==> flutter pub get'
Push-Location flutter
try { Run flutter @('pub', 'get') } finally { Pop-Location }

$Bridge = 'src\bridge_generated.rs'
if (-not (Test-Path $Bridge) -or (Get-Item 'src\flutter_ffi.rs').LastWriteTime -gt (Get-Item $Bridge).LastWriteTime) {
    Write-Host '==> generating flutter_rust_bridge glue'
    Run flutter_rust_bridge_codegen @(
        '--llvm-path', $env:LLVM_PATH,
        '--rust-input', '.\src\flutter_ffi.rs',
        '--dart-output', '.\flutter\lib\generated_bridge.dart',
        '--c-output', '.\flutter\macos\Runner\bridge_generated.h')
    Copy-Item '.\flutter\macos\Runner\bridge_generated.h' '.\flutter\ios\Runner\bridge_generated.h' -Force
}

Write-Host '==> building (cargo + flutter)'
Run $Python @('.\build.py', '--portable', '--hwcodec', '--flutter', '--vram', '--skip-portable-pack')

Write-Host ''
Write-Host 'Built: flutter\build\windows\x64\runner\Release\'
Write-Host 'For the self-extracting installer, rerun build.py without --skip-portable-pack.'
