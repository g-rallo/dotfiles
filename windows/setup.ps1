#Requires -Version 5
<#
  Windows-side setup for the WSL agentic-workspace environment.

  Installs WezTerm and links %USERPROFILE%\.wezterm.lua to the config that lives
  in the WSL clone of this repo. Run from an elevated PowerShell, or from a
  normal one when Windows Developer Mode is enabled:

    powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1
    powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1 -Distro Ubuntu
#>
param(
  [string]$Distro = "Ubuntu"
)

$ErrorActionPreference = "Stop"

Write-Host "==> Installing WezTerm (if missing)"
if (Get-Command wezterm -ErrorAction SilentlyContinue) {
  Write-Host "WezTerm already installed"
} else {
  winget install --id wez.wezterm -e --accept-source-agreements --accept-package-agreements
}

Write-Host "==> Resolving the WSL home directory for '$Distro'"
$wslHome = (wsl -d $Distro -e sh -lc 'printf %s "$HOME"').Trim()
if ([string]::IsNullOrWhiteSpace($wslHome)) {
  throw "Could not resolve the WSL home. Is '$Distro' installed? Pass -Distro <name>."
}

$wslPath = "\\wsl$\$Distro" + ($wslHome -replace '/', '\')
$configTarget = Join-Path $wslPath "github\agentic-workspace\home\.config\wezterm\wezterm.lua"
$linkPath = Join-Path $env:USERPROFILE ".wezterm.lua"

if (-not (Test-Path $configTarget)) {
  throw "WezTerm config not found at $configTarget. Clone this repo at ~/github/agentic-workspace inside WSL first."
}

if (Test-Path $linkPath) {
  $existing = Get-Item $linkPath -Force
  if ($existing.LinkType) {
    Write-Host "==> Replacing the existing symlink"
    Remove-Item $linkPath -Force
  } else {
    Write-Host "==> Backing up the existing config to $linkPath.bak"
    Move-Item $linkPath "$linkPath.bak" -Force
  }
}

Write-Host "==> Linking $linkPath -> $configTarget"
New-Item -ItemType SymbolicLink -Path $linkPath -Target $configTarget | Out-Null

Write-Host "Done. Launch WezTerm from the Start menu."
