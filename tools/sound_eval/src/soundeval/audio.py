"""Audio laden: WAV und MP3 über libsndfile, ohne ffmpeg."""

from __future__ import annotations

import hashlib
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import soundfile as sf

SUPPORTED_SUFFIXES = {".wav", ".mp3", ".ogg", ".flac"}
CLAP_SAMPLE_RATE = 48_000


@dataclass
class Audio:
    path: Path
    samples: np.ndarray  # float32, Form (frames, channels), Werte in [-1, 1]
    sample_rate: int
    subtype: str  # z. B. PCM_16, FLOAT, MPEG_LAYER_III
    file_format: str

    @property
    def channels(self) -> int:
        return self.samples.shape[1]

    @property
    def duration(self) -> float:
        return self.samples.shape[0] / self.sample_rate

    def mono(self) -> np.ndarray:
        return self.samples.mean(axis=1)

    def resampled_mono(self, target_rate: int = CLAP_SAMPLE_RATE) -> np.ndarray:
        mono = self.mono().astype(np.float32)
        if self.sample_rate == target_rate:
            return mono
        import soxr

        return soxr.resample(mono, self.sample_rate, target_rate).astype(np.float32)


def load(path: str | Path) -> Audio:
    path = Path(path)
    if path.suffix.lower() not in SUPPORTED_SUFFIXES:
        raise ValueError(f"Format nicht unterstützt: {path.suffix} ({path})")
    info = sf.info(str(path))
    data, rate = sf.read(str(path), dtype="float32", always_2d=True)
    if data.shape[0] == 0:
        raise ValueError(f"Datei enthält keine Samples: {path}")
    return Audio(path=path, samples=data, sample_rate=rate, subtype=info.subtype, file_format=info.format)


def file_hash(path: str | Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def find_audio(paths: list[str | Path], recursive: bool = True) -> list[Path]:
    """Dateien und Verzeichnisse zu einer sortierten, doppelfreien Liste von Audiodateien."""
    found: list[Path] = []
    for p in map(Path, paths):
        if p.is_dir():
            pattern = "**/*" if recursive else "*"
            found += [f for f in p.glob(pattern) if f.is_file() and f.suffix.lower() in SUPPORTED_SUFFIXES]
        elif p.is_file():
            found.append(p)
        else:
            raise FileNotFoundError(p)
    seen: set[Path] = set()
    unique = []
    for f in sorted(found):
        key = f.resolve()
        if key not in seen:
            seen.add(key)
            unique.append(f)
    return unique
