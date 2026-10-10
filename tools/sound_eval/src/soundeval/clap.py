"""CLAP-Einbettungen (LAION-CLAP über transformers) mit Festplatten-Cache für Audio."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Protocol

import numpy as np

from .audio import CLAP_SAMPLE_RATE, Audio, file_hash

WINDOW_S = 10.0  # CLAP sieht 10-s-Fenster; längere Töne werden fensterweise gemittelt
TRIM_DB = -60.0  # Ränder leiser als Peak minus so viel dB gelten als Stille
PREP_VERSION = "v2"  # bei Änderung an prepare() hochzählen, damit der Cache neu rechnet


def prepare(wave: np.ndarray) -> np.ndarray:
    """Pegel und Stille bewertet die technische Analyse; CLAP soll nur den Inhalt sehen.

    Daher: Ränder unter Peak −60 dB abschneiden und auf Peak 0,9 normalisieren. Sonst
    bekommt dieselbe Aufnahme leiser oder mit Stille davor andere Ähnlichkeiten.
    """
    peak = float(np.max(np.abs(wave))) if wave.size else 0.0
    if peak < 1e-5:
        return wave
    loud = np.flatnonzero(np.abs(wave) > peak * 10 ** (TRIM_DB / 20))
    wave = wave[loud[0] : loud[-1] + 1]
    return (wave * (0.9 / peak)).astype(np.float32)


def model_cached(model_id: str) -> bool:
    """Liegt das Modell im Hugging-Face-Cache? (ohne huggingface_hub zu importieren)"""
    hub = os.environ.get("HF_HUB_CACHE") or Path(os.environ.get("HF_HOME") or Path.home() / ".cache" / "huggingface") / "hub"
    return (Path(hub) / f"models--{model_id.replace('/', '--')}" / "snapshots").is_dir()


def cache_dir() -> Path:
    root = os.environ.get("SOUND_EVAL_CACHE") or Path.home() / ".cache" / "sound-eval"
    return Path(root)


class Embedder(Protocol):
    model_id: str

    def embed_audio(self, audios: list[Audio]) -> np.ndarray: ...
    def embed_text(self, texts: list[str]) -> np.ndarray: ...


def _normalize(x: np.ndarray) -> np.ndarray:
    return x / np.maximum(np.linalg.norm(x, axis=-1, keepdims=True), 1e-12)


def pick_device(requested: str = "auto") -> str:
    import torch

    if requested != "auto":
        return requested
    return "cuda" if torch.cuda.is_available() else "cpu"


class ClapEmbedder:
    def __init__(self, model_id: str = "laion/larger_clap_general", device: str = "auto", use_cache: bool = True):
        if model_cached(model_id):  # vor dem Import setzen: huggingface_hub liest es nur einmal
            os.environ.setdefault("HF_HUB_OFFLINE", "1")
        import torch
        from transformers import ClapModel, ClapProcessor

        self.model_id = model_id
        self.device = pick_device(device)
        self._torch = torch
        # liegt das Modell im Cache, lädt es ohne Netz; nur der erste Lauf lädt herunter (~800 MB)
        self.processor = ClapProcessor.from_pretrained(model_id)
        self.model = ClapModel.from_pretrained(model_id).to(self.device).eval()
        self.use_cache = use_cache
        self._cache = cache_dir() / "embeddings" / f"{model_id.replace('/', '__')}-{PREP_VERSION}"

    @staticmethod
    def _tensor(out):
        # transformers < 5 liefert einen Tensor, neuere Versionen ein Output-Objekt
        return out if hasattr(out, "shape") else out.pooler_output

    def _windows(self, audio: Audio) -> list[np.ndarray]:
        wave = prepare(audio.resampled_mono(CLAP_SAMPLE_RATE))
        size = int(WINDOW_S * CLAP_SAMPLE_RATE)
        if len(wave) <= size:
            return [wave]
        chunks = [wave[i : i + size] for i in range(0, len(wave), size)]
        return [c for c in chunks if len(c) >= CLAP_SAMPLE_RATE] or chunks[:1]  # Rest unter 1 s weglassen

    def _embed_waves(self, waves: list[np.ndarray]) -> np.ndarray:
        fe = self.processor.feature_extractor
        inputs = fe(waves, sampling_rate=CLAP_SAMPLE_RATE, return_tensors="pt")
        inputs = {k: v.to(self.device) for k, v in inputs.items()}
        with self._torch.no_grad():
            out = self._tensor(self.model.get_audio_features(**inputs))
        return out.float().cpu().numpy()

    def embed_audio(self, audios: list[Audio]) -> np.ndarray:
        result: list[np.ndarray | None] = [None] * len(audios)
        todo = []
        for i, a in enumerate(audios):
            cached = self._cache / f"{file_hash(a.path)}.npy" if self.use_cache else None
            if cached is not None and cached.exists():
                result[i] = np.load(cached)
            else:
                todo.append((i, cached))
        for i, cached in todo:
            emb = _normalize(self._embed_waves(self._windows(audios[i])).mean(axis=0))
            result[i] = emb
            if cached is not None:
                cached.parent.mkdir(parents=True, exist_ok=True)
                np.save(cached, emb)
        return np.stack(result)

    def embed_text(self, texts: list[str]) -> np.ndarray:
        inputs = self.processor.tokenizer(texts, padding=True, return_tensors="pt")
        inputs = {k: v.to(self.device) for k, v in inputs.items()}
        with self._torch.no_grad():
            out = self._tensor(self.model.get_text_features(**inputs))
        return _normalize(out.float().cpu().numpy())
