"""Specialized Reporting — Auto-Updater & Force-Update Engine

Handles GitHub release checking, version manifest parsing, background download of new binaries,
and seamless zero-downtime process swapping while strictly preserving all local configuration
files (config.env, .env, .admin_auth).
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Optional, Tuple

CURRENT_VERSION = "1.3.0"
DEFAULT_GITHUB_REPO = "0784harshil/specializedreporting"
MANIFEST_RAW_URL = "https://raw.githubusercontent.com/{repo}/main/version.json"
RELEASE_API_URL = "https://api.github.com/repos/{repo}/releases/latest"


def parse_version_tuple(v_str: str) -> Tuple[int, ...]:
    """Converts '1.2.3' into (1, 2, 3) for accurate semver comparisons."""
    clean = v_str.strip().lstrip("vV")
    parts = []
    for chunk in clean.split("."):
        try:
            parts.append(int(chunk))
        except ValueError:
            parts.append(0)
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts)


@dataclass
class UpdateInfo:
    available: bool
    latest_version: str
    current_version: str
    is_forced: bool
    download_url: str
    changelog: str
    release_date: str


def check_for_updates(github_repo: str = DEFAULT_GITHUB_REPO, timeout: int = 8) -> UpdateInfo:
    """Checks the remote GitHub repository for the latest version via Releases API & version.json.
    
    Returns UpdateInfo with comparison status and force-update directive.
    """
    repo = github_repo.strip() or DEFAULT_GITHUB_REPO
    headers = {
        "User-Agent": f"SpecializedReporting-Updater/{CURRENT_VERSION}",
        "Accept": "application/json",
    }

    manifest_data = {}
    release_tag = ""
    release_exe_url = ""
    release_changelog = ""
    release_date = ""

    # 1. Check GitHub Release API first (fastest source of published releases)
    try:
        req = urllib.request.Request(RELEASE_API_URL.format(repo=repo), headers=headers)
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            if resp.status == 200:
                rel = json.loads(resp.read().decode("utf-8"))
                release_tag = rel.get("tag_name", "").lstrip("vV").strip()
                release_date = (rel.get("published_at", "") or "")[:10]
                release_changelog = rel.get("body", "Latest update with improvements and fixes.") or ""
                for a in rel.get("assets", []):
                    if a.get("name", "").endswith(".exe"):
                        release_exe_url = a.get("browser_download_url", "")
                        break
    except Exception:
        pass

    # 2. Check version.json on main branch
    try:
        req = urllib.request.Request(MANIFEST_RAW_URL.format(repo=repo), headers=headers)
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            if resp.status == 200:
                manifest_data = json.loads(resp.read().decode("utf-8"))
    except Exception:
        pass

    # Pick the highest version between Release tag and version.json
    manifest_v = manifest_data.get("version", "").strip().lstrip("vV")
    target_v = release_tag
    if manifest_v and parse_version_tuple(manifest_v) > parse_version_tuple(target_v):
        target_v = manifest_v

    if not target_v:
        target_v = manifest_v or release_tag or CURRENT_VERSION

    download_url = (
        manifest_data.get("download_url") or
        release_exe_url or
        f"https://github.com/{repo}/releases/latest/download/Specialized_Reporting.exe"
    )
    is_forced = manifest_data.get("force_update", False)
    min_required = manifest_data.get("min_required_version", "1.0.0")

    curr_tuple = parse_version_tuple(CURRENT_VERSION)
    latest_tuple = parse_version_tuple(target_v)
    min_tuple = parse_version_tuple(min_required)

    is_available = latest_tuple > curr_tuple
    is_mandatory = is_available and (is_forced or (min_tuple > curr_tuple))

    changelog = manifest_data.get("changelog") or release_changelog or "Latest updates and enhancements."
    rel_date = manifest_data.get("release_date") or release_date or time.strftime("%Y-%m-%d")

    return UpdateInfo(
        available=is_available,
        latest_version=target_v,
        current_version=CURRENT_VERSION,
        is_forced=is_mandatory,
        download_url=download_url,
        changelog=changelog,
        release_date=rel_date,
    )


def download_update_binary(
    download_url: str,
    target_path: Path,
    progress_callback: Optional[Callable[[int, int], None]] = None,
    timeout: int = 60,
) -> bool:
    """Downloads the new executable binary to a temporary path (.new) with progress tracking."""
    headers = {"User-Agent": f"SpecializedReporting-Updater/{CURRENT_VERSION}"}
    req = urllib.request.Request(download_url, headers=headers)

    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            total_size = int(response.headers.get("Content-Length", 0))
            downloaded = 0
            block_size = 65536

            with open(target_path, "wb") as f_out:
                while True:
                    chunk = response.read(block_size)
                    if not chunk:
                        break
                    f_out.write(chunk)
                    downloaded += len(chunk)
                    if progress_callback:
                        progress_callback(downloaded, total_size)
        return True
    except Exception as e:
        if target_path.exists():
            try:
                target_path.unlink()
            except Exception:
                pass
        raise e


def apply_update_and_restart(app_dir: Path, target_exe_name: str = "Specialized_Reporting.exe") -> None:
    """Generates apply_update.bat, spawns it detached, and terminates current process to swap the executable."""
    current_pid = os.getpid()
    target_exe = app_dir / target_exe_name
    new_exe = app_dir / f"{target_exe_name}.new"

    if not new_exe.exists():
        raise FileNotFoundError(f"Update payload not found at: {new_exe}")

    bat_path = app_dir / "apply_update.bat"
    
    bat_content = f"""@echo off
setlocal
echo ===================================================
echo   Specialized Reporting — Seamless Process Swapper
echo ===================================================
echo Waiting for existing process (PID {current_pid}) to terminate...
timeout /t 2 /nobreak >nul

set RETRIES=0
:RETRY_LOOP
tasklist /fi "PID eq {current_pid}" 2>nul | find "{current_pid}" >nul
if %ERRORLEVEL% equ 0 (
    timeout /t 1 /nobreak >nul
    set /a RETRIES+=1
    if %RETRIES% lss 10 goto RETRY_LOOP
    taskkill /f /pid {current_pid} >nul 2>&1
)

echo Replacing {target_exe_name}...
copy /y "{new_exe}" "{target_exe}" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Retrying binary replacement in 1 second...
    timeout /t 1 /nobreak >nul
    copy /y "{new_exe}" "{target_exe}" >nul 2>&1
)

if exist "{new_exe}" (
    del /f /q "{new_exe}" >nul 2>&1
)

echo Relaunching updated Specialized Reporting...
start "" "{target_exe}"

timeout /t 1 /nobreak >nul
(goto) 2>nul & del "%~f0"
"""
    bat_path.write_text(bat_content, encoding="ansi")

    # Spawn updater batch file completely detached
    if sys.platform == "win32":
        DETACHED_PROCESS = 0x00000008
        CREATE_NEW_PROCESS_GROUP = 0x00000200
        subprocess.Popen(
            [str(bat_path)],
            creationflags=DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP,
            close_fds=True,
            shell=True,
        )
    else:
        subprocess.Popen(["cmd.exe", "/c", str(bat_path)])

    # Immediately exit current Python / Qt process
    sys.exit(0)
