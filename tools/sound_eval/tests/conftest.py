"""Gemeinsame Helfer: synthetische Töne und ein Fake-Embedder ohne CLAP-Modell."""

from __future__ import annotations

import hashlib
import textwrap

import numpy as np
import pytest
import soundfile as sf

RATE = 44100


def tone(freq=440.0, seconds=0.8, amp=0.3, rate=RATE, channels=1, lead=0.0):
    t = np.arange(int(seconds * rate)) / rate
    x = (amp * np.sin(2 * np.pi * freq * t)).astype(np.float32)
    x *= np.minimum(1, np.minimum(t, t[::-1]) / 0.005).astype(np.float32)  # 5-ms-Rampen gegen Klicks
    x = np.concatenate([np.zeros(int(lead * rate), np.float32), x])
    return np.stack([x] * channels, axis=1)


@pytest.fixture
def write_wav(tmp_path):
    def _write(name, data, rate=RATE, **kw):
        path = tmp_path / name
        path.parent.mkdir(parents=True, exist_ok=True)
        sf.write(str(path), data, rate, **kw)
        return path

    return _write


def _unit(v):
    v = np.asarray(v, dtype=np.float32)
    return v / np.linalg.norm(v)


class FakeEmbedder:
    """Ordnet Texten und Dateien feste Vektoren zu; Unbekanntes bekommt einen Zufallsvektor je Name."""

    model_id = "fake"

    def __init__(self, texts: dict[str, list[float]], audio: dict[str, list[float]], dim=8):
        self.texts, self.audio, self.dim = texts, audio, dim

    def _fallback(self, key):
        seed = int(hashlib.md5(key.encode()).hexdigest()[:8], 16)
        return _unit(np.random.default_rng(seed).normal(size=self.dim)) * 0.1

    def _vec(self, table, key):
        return _unit(table[key]) if key in table else self._fallback(key)

    def embed_text(self, texts):
        return np.stack([self._vec(self.texts, t) for t in texts])

    def embed_audio(self, audios):
        return np.stack([self._vec(self.audio, a.path.stem) for a in audios])


@pytest.fixture
def profile_file(tmp_path):
    def _make(body: str, name="test.yaml"):
        path = tmp_path / name
        path.write_text(textwrap.dedent(body), encoding="utf-8")
        return path

    return _make
