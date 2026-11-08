#!/usr/bin/env python3
"""
Ecosystem Security & Compliance Auditor.
Uses the CloudSec CLI engine to perform DevSecOps static analysis across
all microservice Dockerfiles and configuration files.
Outputs:
  - AUDIT_REPORT.md  (Human-readable executive Markdown report)
  - AUDIT_REPORT.sarif (GitHub Code Scanning SARIF v2.1.0 standard)
"""

import os
import sys
import time
from pathlib import Path

# Add cloudsec package from cloudsec-cli/src to sys.path
SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parent
os.chdir(ROOT_DIR)

CLOUDSEC_SRC = ROOT_DIR / "cloudsec-cli" / "src"
if not CLOUDSEC_SRC.exists():
    CLOUDSEC_SRC = ROOT_DIR / "Developer- Platform -CLI Tool" / "src"

sys.path.insert(0, str(CLOUDSEC_SRC))

from cloudsec import __version__
from cloudsec.models.finding import AuditSummary, Finding, RuleCategory, Severity
from cloudsec.models.report import AuditReport
from cloudsec.parsers.config import ConfigEntry
from cloudsec.reporters.markdown_reporter import MarkdownReporter
from cloudsec.reporters.sarif_reporter import SarifReporter
from cloudsec.reporters.terminal_reporter import TerminalReporter
from cloudsec.scanners.dockerfile_rules import DockerfileScanner
from cloudsec.scanners.secrets_rules import SecretsScanner
from rich.console import Console

console = Console(force_terminal=True)


def scan_env_file(path: Path) -> list[Finding]:
    """Parse .env or .env.example lines into ConfigEntry items and scan for secrets."""
    entries: list[ConfigEntry] = []
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    for idx, line in enumerate(lines, start=1):
        line_clean = line.strip()
        if not line_clean or line_clean.startswith("#"):
            continue
        if "=" in line_clean:
            key, val = line_clean.split("=", 1)
            key = key.strip()
            val = val.strip().strip("'\"")
            entries.append(
                ConfigEntry(
                    key_path=key,
                    value=val,
                    line_number=idx,
                    raw_line=line,
                )
            )
    return SecretsScanner.scan_entries(entries, target=path.as_posix())


def main() -> int:
    console.print("\n[bold cyan]╔══════════════════════════════════════════════════════════════════╗[/bold cyan]")
    console.print("[bold cyan]║          ECOSYSTEM DEVSECOPS SECURITY & COMPLIANCE AUDIT         ║[/bold cyan]")
    console.print("[bold cyan]╚══════════════════════════════════════════════════════════════════╝[/bold cyan]\n")

    start_time = time.perf_counter()
    findings: list[Finding] = []
    targets_scanned = 0

    # 1. Target Dockerfiles (relative paths for SARIF compatibility)
    dockerfiles = [
        Path("enterprise-financial-api/Dockerfile"),
        Path("notification-event-engine/Dockerfile"),
        Path("cloudsec-cli/Dockerfile"),
    ]

    console.print("[bold yellow]▶ Varrendo Dockerfiles dos Microsserviços...[/bold yellow]")
    for df in dockerfiles:
        if df.exists():
            targets_scanned += 1
            console.print(f"  • Inspecionando: [dim]{df.as_posix()}[/dim]")
            findings.extend(DockerfileScanner.scan_file(df))
        else:
            console.print(f"  [yellow]⚠ Aviso: Dockerfile não encontrado: {df}[/yellow]")

    # 2. Target Configuration Files (relative paths for SARIF compatibility)
    config_files = [
        Path("enterprise-financial-api/src/main/resources/application.yml"),
        Path("enterprise-financial-api/.env.example"),
        Path("notification-event-engine/.env.example"),
        Path("docker-compose.yml"),
    ]

    console.print("\n[bold yellow]▶ Varrendo Arquivos de Configuração e Variáveis de Ambiente...[/bold yellow]")
    for cfg in config_files:
        if cfg.exists():
            targets_scanned += 1
            console.print(f"  • Inspecionando: [dim]{cfg.as_posix()}[/dim]")
            if cfg.name.startswith(".env") or cfg.name.endswith(".env"):
                findings.extend(scan_env_file(cfg))
            else:
                findings.extend(SecretsScanner.scan_file(cfg))
        else:
            console.print(f"  [yellow]⚠ Aviso: Arquivo de configuração não encontrado: {cfg}[/yellow]")

    duration = time.perf_counter() - start_time

    # Build Unified Report
    summary = AuditSummary.from_findings(
        findings=findings,
        targets_scanned=targets_scanned,
        duration=duration,
    )
    report = AuditReport(
        version=__version__,
        summary=summary,
        findings=findings,
    )

    # Output Terminal Summary
    TerminalReporter(console=console).print_report(report)

    # Generate Markdown Report
    md_content = MarkdownReporter.render(report)
    md_path = ROOT_DIR / "AUDIT_REPORT.md"
    md_path.write_text(md_content, encoding="utf-8")
    console.print(f"[bold green]✔ Relatório Markdown gerado em:[/bold green] {md_path.name}")

    # Generate SARIF Report
    sarif_content = SarifReporter.render(report)
    sarif_path = ROOT_DIR / "AUDIT_REPORT.sarif"
    sarif_path.write_text(sarif_content, encoding="utf-8")
    console.print(f"[bold green]✔ Relatório SARIF v2.1.0 gerado em:[/bold green] {sarif_path.name}\n")

    has_critical = any(f.severity in (Severity.CRITICAL, Severity.HIGH) for f in findings)
    if has_critical:
        console.print("[yellow]⚠ Apontamentos de segurança registrados no relatório para revisão de hardening.[/yellow]")

    return 0


if __name__ == "__main__":
    sys.exit(main())
