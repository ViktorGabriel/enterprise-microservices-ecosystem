# ==============================================================================
# ECOSYSTEM DEVSECOPS AUDIT RUNNER (PowerShell)
# ==============================================================================
$ErrorActionPreference = "Stop"
$env:PYTHONIOENCODING = "utf-8"

$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $RootDir

$PythonPath = Join-Path $RootDir "cloudsec-cli\.venv\Scripts\python.exe"
if (-not (Test-Path $PythonPath)) {
    $PythonPath = Join-Path $RootDir "Developer- Platform -CLI Tool\.venv\Scripts\python.exe"
}
if (-not (Test-Path $PythonPath)) {
    $PythonPath = "python"
}

Write-Host "Iniciando auditoria DevSecOps no ecossistema..." -ForegroundColor Cyan
& $PythonPath (Join-Path $RootDir "scripts\audit_ecosystem.py")
