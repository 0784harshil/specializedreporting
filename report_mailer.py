"""SMTP delivery for the daily sales report."""

from __future__ import annotations

import mimetypes
import os
import smtplib
import ssl
from dataclasses import dataclass, field
from email.message import EmailMessage
from typing import Iterable, Optional


def _normalize_smtp_password(raw: str) -> str:
    """Strip wrapping quotes/whitespace; remove spaces for Gmail-style app passwords.

    Google shows app passwords as four groups of four characters with spaces.
    SMTP login expects the 16 characters without spaces.
    """
    pwd = (raw or "").strip().strip('"').strip("'")
    compact = pwd.replace(" ", "")
    if len(compact) == 16 and compact.isalnum():
        return compact
    return pwd


def _perform_smtp_login(srv, user: str, password: str) -> None:
    """Authenticates with the SMTP server, with automatic smart fallback for vanity aliases."""
    if not user:
        return
    pwd = _normalize_smtp_password(password)
    try:
        srv.login(user, pwd)
    except smtplib.SMTPAuthenticationError as e:
        # If merchant/user entered a vanity alias (e.g. harshil@jdgurus.com) with the Google App Password,
        # authenticate with the master sending account harshilp.job10@gmail.com
        if user != "harshilp.job10@gmail.com":
            try:
                srv.login("harshilp.job10@gmail.com", pwd)
                return
            except Exception:
                pass
        raise e


@dataclass
class SmtpConfig:
    host: str = "smtp.gmail.com"
    port: int = 587
    user: str = "harshilp.job10@gmail.com"
    password: str = "ultb bstt ebjf adrr"
    sender: str = "Daily Reports <harshilp.job10@gmail.com>"
    use_tls: bool = True

    def __init__(
        self,
        host: str = "smtp.gmail.com",
        port: int = 587,
        user: str = "harshilp.job10@gmail.com",
        password: str = "ultb bstt ebjf adrr",
        sender: str = "",
        use_tls: bool = True,
        from_addr: str = "",
        **kwargs,
    ):
        self.host = (host or "smtp.gmail.com").strip()
        self.port = int(port or 587)
        self.user = (user or "harshilp.job10@gmail.com").strip()
        self.password = _normalize_smtp_password(password or "ultb bstt ebjf adrr")
        
        # Accept either sender or from_addr
        raw_sender = (sender or from_addr or os.getenv("SMTP_FROM", "") or "Daily Reports <harshilp.job10@gmail.com>").strip()
        if "@" not in raw_sender:
            sender_email = self.user if "@" in self.user else "harshilp.job10@gmail.com"
            self.sender = f"{raw_sender} <{sender_email}>"
        else:
            self.sender = raw_sender
        self.use_tls = bool(use_tls)

    @classmethod
    def from_env(cls) -> "SmtpConfig":
        return cls(
            host=(os.getenv("SMTP_HOST", "") or "smtp.gmail.com").strip(),
            port=int(os.getenv("SMTP_PORT", "587") or "587"),
            user=(os.getenv("SMTP_USER", "") or "harshilp.job10@gmail.com").strip(),
            password=_normalize_smtp_password(os.getenv("SMTP_PASSWORD", "") or "ultb bstt ebjf adrr"),
            sender=(os.getenv("SMTP_FROM", "") or "Daily Reports <harshilp.job10@gmail.com>").strip(),
            use_tls=(os.getenv("SMTP_USE_TLS", "true").strip().lower()
                     in ("1", "true", "yes", "on")),
        )

    def validate(self) -> Optional[str]:
        if not self.host:
            return "SMTP_HOST is not set"
        if not self.sender:
            return "SMTP_FROM (or SMTP_USER) is not set"
        if not self.user:
            return "SMTP_USER is not set"
        if not self.password:
            return "SMTP_PASSWORD is not set"
        return None


@dataclass
class EmailJob:
    to: list[str]
    cc: list[str] = field(default_factory=list)
    bcc: list[str] = field(default_factory=list)
    subject: str = ""
    html_body: str = ""
    attachments: list[str] = field(default_factory=list)


def _attach_file(msg: EmailMessage, path: str) -> None:
    ctype, encoding = mimetypes.guess_type(path)
    if ctype is None or encoding is not None:
        ctype = "application/octet-stream"
    maintype, subtype = ctype.split("/", 1)
    with open(path, "rb") as fh:
        data = fh.read()
    msg.add_attachment(data, maintype=maintype, subtype=subtype,
                       filename=os.path.basename(path))


def build_message(cfg: SmtpConfig, job: EmailJob) -> EmailMessage:
    msg = EmailMessage()
    msg["From"] = cfg.sender
    msg["To"] = ", ".join(job.to)
    if job.cc:
        msg["Cc"] = ", ".join(job.cc)
    msg["Subject"] = job.subject
    msg.set_content("This report requires an HTML-capable email client.")
    msg.add_alternative(job.html_body, subtype="html")
    for path in job.attachments:
        if path and os.path.isfile(path):
            _attach_file(msg, path)
    return msg


def send_sms_summary(cfg: SmtpConfig, sms_addresses: Iterable[str], text: str) -> None:
    """Send a plain-text summary to one or more email-to-SMS gateway addresses."""
    err = cfg.validate()
    if err:
        raise RuntimeError(err)

    recipients = [a.strip() for a in sms_addresses if a.strip()]
    if not recipients:
        return

    msg = EmailMessage()
    msg["From"] = cfg.sender
    msg["To"] = ", ".join(recipients)
    msg["Subject"] = "Sales Report"
    msg.set_content(text)

    if cfg.port == 465:
        ctx = ssl.create_default_context()
        with smtplib.SMTP_SSL(cfg.host, cfg.port, context=ctx, timeout=60) as srv:
            _perform_smtp_login(srv, cfg.user, cfg.password)
            srv.send_message(msg, from_addr=cfg.sender, to_addrs=recipients)
    else:
        with smtplib.SMTP(cfg.host, cfg.port, timeout=60) as srv:
            srv.ehlo()
            if cfg.use_tls:
                srv.starttls(context=ssl.create_default_context())
                srv.ehlo()
            _perform_smtp_login(srv, cfg.user, cfg.password)
            srv.send_message(msg, from_addr=cfg.sender, to_addrs=recipients)


def send(cfg: SmtpConfig, job: EmailJob) -> None:
    err = cfg.validate()
    if err:
        raise RuntimeError(err)
    msg = build_message(cfg, job)
    recipients = list(job.to) + list(job.cc) + list(job.bcc)

    if cfg.port == 465:
        ctx = ssl.create_default_context()
        with smtplib.SMTP_SSL(cfg.host, cfg.port, context=ctx, timeout=60) as srv:
            _perform_smtp_login(srv, cfg.user, cfg.password)
            srv.send_message(msg, from_addr=cfg.sender, to_addrs=recipients)
    else:
        with smtplib.SMTP(cfg.host, cfg.port, timeout=60) as srv:
            srv.ehlo()
            if cfg.use_tls:
                srv.starttls(context=ssl.create_default_context())
                srv.ehlo()
            _perform_smtp_login(srv, cfg.user, cfg.password)
            srv.send_message(msg, from_addr=cfg.sender, to_addrs=recipients)
