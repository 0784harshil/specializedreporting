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

CURRENT_VERSION = "1.1.0"
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
    """Checks the remote GitHub repository for the latest version manifest.
    
    Returns UpdateInfo with comparison status and force-update directive.
    """
    repo = github_repo.strip() or DEFAULT_GITHUB_REPO
    urls_to_try = [
        MANIFEST_RAW_URL.format(repo=repo),
        RELEASE_API_URL.format(repo=repo),
    ]

    headers = {
        "User-Agent": f"SpecializedReporting-Updater/{CURRENT_VERSION}",
        "Accept": "application/json",
    }

    last_error = None
    manifest_data = None

    # 1. Try fetching raw version.json
    for url in urls_to_try:
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                if resp.status == 200:
                    raw = resp.read().decode("utf-8")
                    data = json.loads(raw)
                    # If this is GitHub Release API response
                    if "tag_name" in data:
                        tag = data.get("tag_name", "").lstrip("vV")
                        assets = data.get("assets", [])
                        exe_url = ""
                        for a in assets:
                            if a.get("name", "").endswith(".exe"):
                                exe_url = a.get("browser_download_url", "")
                                break
                        manifest_data = {
                            "version": tag,
                            "min_required_version": "1.0.0",
                            "force_update": False,
                            "release_date": data.get("published_at", "")[:10],
                            "changelog": data.get("body", "General improvements and fixes."),
                            "download_url": exe_url or f"https://github.com/{repo}/releases/latest/download/Specialized_Reporting.exe",
                        }
                    else:
                        manifest_data = data
                    break
        except Exception as ex:
            last_error = ex
            continue

    if not manifest_data:
        return UpdateInfo(
            available=False,
            latest_version=CURRENT_VERSION,
            current_version=CURRENT_VERSION,
            is_forced=False,
            download_url="",
            changelog=f"Could not connect to update server ({last_error})",
            release_date="",
        )

    remote_ver_str = str(manifest_data.get("version", CURRENT_VERSION)).strip()
    min_req_str = str(manifest_data.get("min_required_version", "1.0.0")).strip()
    raw_force = manifest_data.get("force_update", False)
    
    remote_tuple = parse_version_tuple(remote_ver_str)
    curr_tuple = parse_version_tuple(CURRENT_VERSION)
    min_req_tuple = parse_version_tuple(min_req_str)

    has_new_version = remote_tuple > curr_tuple
    is_mandatory = has_new_version and (raw_force or (curr_tuple < min_req_tuple))

    download_url = manifest_data.get("download_url", f"https://github.com/{repo}/releases/latest/download/Specialized_Reporting.exe")
    changelog = manifest_data.get("changelog", "Bug fixes and performance enhancements.")
    release_date = manifest_data.get("release_date", "")

    return UpdateInfo(
        available=has_new_version,
        latest_version=remote_ver_str,
        current_version=CURRENT_VERSION,
        is_forced=is_mandatory,
        download_url=download_url,
        changelog=changelog,
        release_date=release_date,
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
echo Specialized Reporting — Applying Software Update...
echo ===================================================
echo Waiting for existing application process (PID: {current_pid}) to close...

:: Give the running process 2 seconds to gracefully exit
timeout /t 2 /nobreak >nul

:: Ensure old process is killed
taskkill /F /PID {current_pid} >nul 2>&1

:: Loop until the old exe is unlocked and can be replaced
:RETRY_REPLACE
if exist "{target_exe}" (
    del /F /Q "{target_exe}" >nul 2>&1
    if exist "{target_exe}" (
        echo File in use, retrying in 1 second...
        timeout /t 1 /nobreak >nul
        goto RETRY_REPLACE
    )
)

:: Move the downloaded .new file into place
move /Y "{new_exe}" "{target_exe}" >nul 2>&1

if exist "{target_exe}" (
    echo Update applied successfully!
    echo Restarting Specialized Reporting...
    start "" "{target_exe}"
) else (
    echo Update replacement error!
    pause
)

:: Clean up updater script
del "%~f0" >nul 2>&1
exit
"""
    bat_path.write_text(bat_content, encoding="utf-8")

    # Launch detached batch script
    if sys.platform == "win32":
        subprocess.Popen(
            ["cmd.exe", "/c", str(bat_path)],
            creationflags=subprocess.CREATE_NO_WINDOW if hasattr(subprocess, "CREATE_NO_WINDOW") else 0,
            cwd=str(app_dir),
            close_fds=True,
        )
    else:
        subprocess.Popen(["bash", str(bat_path)], cwd=str(app_dir))

    # Terminate Python process immediately to release file lock
    sys.exit(0)
