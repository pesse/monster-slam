"""Optionale Generierung über die ElevenLabs Sound-Effects-API – mit Kostenschätzung und Limits.

Nichts wird gesendet, ohne dass der Aufrufer bestätigt (``confirmed=True``). Jede ausgeführte
Generierung landet im Ledger (``<cache>/elevenlabs-ledger.jsonl``); das Gesamtlimit gilt über
alle Läufe. Die Credit-Sätze sind Schätzungen aus der ElevenLabs-Doku (die widerspricht sich,
daher eher hoch angesetzt) und im Profil unter ``elevenlabs:`` überschreibbar.
"""

from __future__ import annotations

import json
import os
import re
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Callable

from .clap import cache_dir

API_URL = "https://api.elevenlabs.io/v1/sound-generation"
DEFAULTS = {
    "credits_per_second": 20,  # bei fester Dauer
    "credits_auto_duration": 100,  # ohne Dauer (das Modell wählt)
    "max_credits_per_run": 500,
    "max_credits_total": 5000,
    "prompt_influence": 0.5,
    "output_format": "mp3_44100_128",
    "model_id": "eleven_text_to_sound_v2",
}


class BudgetError(RuntimeError):
    pass


@dataclass
class Plan:
    prompt: str
    variants: int
    duration: float | None
    credits_each: int
    settings: dict

    @property
    def credits_total(self) -> int:
        return self.variants * self.credits_each


def settings_for(profile_settings: dict | None) -> dict:
    return {**DEFAULTS, **(profile_settings or {})}


def estimate(duration: float | None, settings: dict) -> int:
    if duration is None:
        return int(settings["credits_auto_duration"])
    return int(round(duration * settings["credits_per_second"] + 0.4999))


def ledger_path() -> Path:
    return cache_dir() / "elevenlabs-ledger.jsonl"


def spent_total(path: Path | None = None) -> int:
    path = path or ledger_path()
    if not path.exists():
        return 0
    return sum(json.loads(line).get("credits", 0) for line in path.read_text(encoding="utf-8").splitlines() if line.strip())


def make_plan(prompt: str, variants: int, duration: float | None, settings: dict, ledger: Path | None = None) -> Plan:
    if duration is not None and not 0.5 <= duration <= 30:
        raise ValueError("ElevenLabs erlaubt 0,5–30 s Dauer.")
    if not settings["output_format"].startswith("mp3_"):
        raise ValueError("Nur MP3-Ausgabe wird unterstützt (output_format mp3_…).")
    if variants < 1:
        raise ValueError("Mindestens eine Variante.")
    plan = Plan(prompt, variants, duration, estimate(duration, settings), settings)
    if plan.credits_total > settings["max_credits_per_run"]:
        raise BudgetError(
            f"Geschätzt {plan.credits_total} Credits > Limit pro Lauf {settings['max_credits_per_run']} "
            "(--max-credits oder elevenlabs.max_credits_per_run im Profil)."
        )
    spent = spent_total(ledger)
    if spent + plan.credits_total > settings["max_credits_total"]:
        raise BudgetError(
            f"Bisher {spent} Credits verbraucht; mit {plan.credits_total} weiteren wäre das Gesamtlimit "
            f"{settings['max_credits_total']} überschritten (elevenlabs.max_credits_total im Profil)."
        )
    return plan


def _slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")[:40] or "sound"


def _post(url: str, api_key: str, body: dict, timeout: float = 120) -> bytes:
    req = urllib.request.Request(
        url, data=json.dumps(body).encode(), method="POST",
        headers={"xi-api-key": api_key, "Content-Type": "application/json", "Accept": "audio/mpeg"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")[:500]
        raise RuntimeError(f"ElevenLabs antwortet {exc.code}: {detail}") from exc


def generate(
    plan: Plan,
    out_dir: Path,
    name: str | None = None,
    confirmed: bool = False,
    api_key: str | None = None,
    post: Callable[[str, str, dict], bytes] = _post,
    ledger: Path | None = None,
) -> list[Path]:
    """Führt den Plan aus. Ohne ``confirmed`` wird nichts gesendet."""
    if not confirmed:
        raise PermissionError("Kostenpflichtiger Aufruf nicht bestätigt.")
    api_key = api_key or os.environ.get("ELEVENLABS_API_KEY")
    if not api_key:
        raise RuntimeError("ELEVENLABS_API_KEY ist nicht gesetzt.")
    s = plan.settings
    out_dir.mkdir(parents=True, exist_ok=True)
    ledger = ledger or ledger_path()
    ledger.parent.mkdir(parents=True, exist_ok=True)
    stem = name or _slug(plan.prompt)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    url = f"{API_URL}?output_format={s['output_format']}"
    body = {"text": plan.prompt, "prompt_influence": s["prompt_influence"], "model_id": s["model_id"]}
    if plan.duration is not None:
        body["duration_seconds"] = plan.duration
    files = []
    for i in range(1, plan.variants + 1):
        data = post(url, api_key, body)
        path = out_dir / f"{stem}-{stamp}-v{i}.mp3"
        path.write_bytes(data)
        files.append(path)
        with ledger.open("a", encoding="utf-8") as f:
            f.write(json.dumps({"time": stamp, "file": str(path), "prompt": plan.prompt, "duration": plan.duration,
                                "credits": plan.credits_each, "estimated": True}, ensure_ascii=False) + "\n")
    return files
