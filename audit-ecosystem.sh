#!/usr/bin/env bash
# ==============================================================================
# ECOSYSTEM DEVSECOPS AUDIT RUNNER (Bash / Linux / macOS / WSL)
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

export PYTHONIOENCODING="utf-8"

# Resolve Python executable
if [[ -f "${ROOT_DIR}/cloudsec-cli/.venv/bin/python" ]]; then
    PYTHON_CMD="${ROOT_DIR}/cloudsec-cli/.venv/bin/python"
elif [[ -f "${ROOT_DIR}/cloudsec-cli/.venv/Scripts/python.exe" ]]; then
    PYTHON_CMD="${ROOT_DIR}/cloudsec-cli/.venv/Scripts/python.exe"
elif [[ -f "${ROOT_DIR}/Developer- Platform -CLI Tool/.venv/Scripts/python.exe" ]]; then
    PYTHON_CMD="${ROOT_DIR}/Developer- Platform -CLI Tool/.venv/Scripts/python.exe"
else
    PYTHON_CMD="python3"
fi

echo -e "\033[1;36mIniciando auditoria DevSecOps no ecossistema via CloudSec CLI...\033[0m"
"${PYTHON_CMD}" "${ROOT_DIR}/scripts/audit_ecosystem.py"
