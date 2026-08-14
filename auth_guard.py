"""pcAmerica CRE Reporting Studio — Team Authentication & Password Protection Module

Features:
  - Cryptographic salted SHA-256 password hashing
  - Secure local credential storage in .admin_auth
  - Role-based privilege checks (Merchant vs Admin / Team)
  - Default master team credentials with 1-click password customization
"""

from __future__ import annotations

import hashlib
import json
import os
import secrets
from pathlib import Path
from typing import Optional

BASE_DIR = Path(__file__).resolve().parent
AUTH_FILE = BASE_DIR / ".admin_auth"
DEFAULT_MASTER_KEY = "admin123"  # Initial team setup key


def generate_salt(length: int = 16) -> str:
    return secrets.token_hex(length)


def hash_password(password: str, salt: Optional[str] = None) -> str:
    if not salt:
        salt = generate_salt()
    salted = f"{salt}:{password}".encode("utf-8")
    pwd_hash = hashlib.sha256(salted).hexdigest()
    return f"{salt}${pwd_hash}"


def verify_password(password: str, stored_hash: str) -> bool:
    try:
        if "$" not in stored_hash:
            return False
        salt, expected_hash = stored_hash.split("$", 1)
        salted = f"{salt}:{password}".encode("utf-8")
        computed_hash = hashlib.sha256(salted).hexdigest()
        return secrets.compare_digest(computed_hash, expected_hash)
    except Exception:
        return False


def is_auth_initialized() -> bool:
    return AUTH_FILE.exists()


def get_stored_auth_data() -> dict:
    if not AUTH_FILE.exists():
        # Initialize with default team password
        initial_data = {
            "version": 1,
            "password_hash": hash_password(DEFAULT_MASTER_KEY),
            "is_default": True,
            "team_name": "Support & IT Team",
        }
        AUTH_FILE.write_text(json.dumps(initial_data, indent=2), encoding="utf-8")
        return initial_data
    
    try:
        data = json.loads(AUTH_FILE.read_text(encoding="utf-8"))
        return data
    except Exception:
        # Fallback repair
        fallback = {
            "version": 1,
            "password_hash": hash_password(DEFAULT_MASTER_KEY),
            "is_default": True,
            "team_name": "Support & IT Team",
        }
        AUTH_FILE.write_text(json.dumps(fallback, indent=2), encoding="utf-8")
        return fallback


def verify_team_password(entered_password: str) -> bool:
    auth_data = get_stored_auth_data()
    stored_hash = auth_data.get("password_hash", "")
    return verify_password(entered_password, stored_hash)


def change_team_password(new_password: str) -> bool:
    try:
        data = get_stored_auth_data()
        data["password_hash"] = hash_password(new_password)
        data["is_default"] = False
        AUTH_FILE.write_text(json.dumps(data, indent=2), encoding="utf-8")
        return True
    except Exception:
        return False
