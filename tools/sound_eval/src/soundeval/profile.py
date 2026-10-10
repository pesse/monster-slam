"""Setting-Profile: Spiel, Atmosphäre, Soundstil und gewünschte Effekte als YAML."""

from __future__ import annotations

import fnmatch
from dataclasses import dataclass, field
from pathlib import Path

import yaml

DEFAULT_WEIGHTS = {"semantic": 0.40, "style": 0.20, "reference": 0.25, "technical": 0.15}
DEFAULT_TECHNICAL = {
    "sample_rates": [44100, 48000],
    "max_true_peak_dbfs": -0.5,
    "loudness_lufs": [-24, -10],
    "max_leading_silence_ms": 30,
    "max_trailing_silence_ms": 500,
    "silence_threshold_db": -50,
    "duration_tolerance": 0.25,
}


@dataclass
class Effect:
    name: str
    prompts: list[str]  # englische CLAP-Beschreibungen, was der Ton sein soll
    description: str = ""  # für Menschen (und Claude), frei
    avoid: list[str] = field(default_factory=list)  # was er ausdrücklich nicht sein soll
    duration: tuple[float, float] | None = None
    files: list[str] = field(default_factory=list)  # Glob-Muster für die automatische Zuordnung
    references: list[Path] = field(default_factory=list)  # akzeptierte Töne genau dieses Effekts
    generation_prompt: str = ""  # Text für ElevenLabs; leer = erster Prompt + Stil


@dataclass
class Profile:
    name: str
    path: Path
    game: str
    atmosphere: str
    style_description: str
    style_prompts: list[str]
    style_avoid: list[str]
    technical: dict
    weights: dict
    references: list[Path]
    effects: dict[str, Effect]
    model: str = "laion/larger_clap_general"
    elevenlabs: dict = field(default_factory=dict)  # Credit-Sätze, Limits, Format (soundeval.elevenlabs.DEFAULTS)

    def effect_for_file(self, path: Path) -> Effect | None:
        name = path.name
        for effect in self.effects.values():
            if any(fnmatch.fnmatch(name, pat) for pat in effect.files):
                return effect
        return None

    def generation_prompt(self, effect: Effect) -> str:
        if effect.generation_prompt:
            return effect.generation_prompt
        style = self.style_prompts[0] if self.style_prompts else ""
        return f"{effect.prompts[0]}, {style}".strip(", ")


def _paths(base: Path, items) -> list[Path]:
    return [(base / p).resolve() for p in (items or [])]


def _range(value) -> tuple[float, float] | None:
    if value is None:
        return None
    lo, hi = value
    return float(lo), float(hi)


def load_profile(path: str | Path) -> Profile:
    path = Path(path).resolve()
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    base = path.parent
    style = data.get("style") or {}
    effects = {}
    for name, e in (data.get("effects") or {}).items():
        e = e or {}
        prompts = e.get("prompts") or []
        if isinstance(prompts, str):
            prompts = [prompts]
        if not prompts:
            raise ValueError(f"Profil {path.name}: Effekt '{name}' braucht mindestens einen Eintrag unter 'prompts'.")
        effects[name] = Effect(
            name=name,
            prompts=prompts,
            description=(e.get("description") or "").strip(),
            avoid=e.get("avoid") or [],
            duration=_range(e.get("duration")),
            files=e.get("files") or [],
            references=_paths(base, e.get("references")),
            generation_prompt=(e.get("generation_prompt") or "").strip(),
        )
    weights = {**DEFAULT_WEIGHTS, **(data.get("weights") or {})}
    return Profile(
        name=data.get("name") or path.stem,
        path=path,
        game=(data.get("game") or "").strip(),
        atmosphere=(data.get("atmosphere") or "").strip(),
        style_description=(style.get("description") or "").strip(),
        style_prompts=style.get("prompts") or [],
        style_avoid=style.get("avoid") or [],
        technical={**DEFAULT_TECHNICAL, **(data.get("technical") or {})},
        weights=weights,
        references=_paths(base, data.get("references")),
        effects=effects,
        model=data.get("model") or "laion/larger_clap_general",
        elevenlabs=data.get("elevenlabs") or {},
    )
