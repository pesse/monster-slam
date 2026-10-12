"""Technische Analyse: Pegel, Clipping, Lautheit, Dauer, Stille – reine Signalverarbeitung."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field

import numpy as np

from .audio import Audio

CLIP_LEVEL = 0.999  # ab hier gilt ein Sample als am Anschlag
CLIP_RUN = 3  # so viele Samples in Folge am Anschlag = Clipping (ein einzelnes darf es sein)
PHASE_ALERT = -0.3  # erst deutlich negative Korrelation ist gegenphasig; um 0 ist nur breites Stereo
PENALTY = {"error": 30, "warn": 10, "info": 0}


def _db(x: float) -> float:
    return float(20 * np.log10(max(x, 1e-10)))


@dataclass
class Metrics:
    duration_s: float
    sample_rate: int
    channels: int
    subtype: str
    peak_dbfs: float
    true_peak_dbfs: float
    rms_dbfs: float
    loudness_lufs: float
    clipped_runs: int
    clipped_fraction: float
    leading_silence_ms: float
    trailing_silence_ms: float
    dc_offset: float
    channel_correlation: float | None  # nur bei Stereo; ~1.0 = Dual-Mono


@dataclass
class Issue:
    severity: str  # error | warn | info
    code: str
    message: str
    suggestion: str = ""


@dataclass
class TechnicalResult:
    metrics: Metrics
    issues: list[Issue] = field(default_factory=list)

    @property
    def score(self) -> float:
        return float(max(0, 100 - sum(PENALTY[i.severity] for i in self.issues)))

    def to_dict(self) -> dict:
        return {"score": self.score, "metrics": asdict(self.metrics), "issues": [asdict(i) for i in self.issues]}


def _clip_runs(samples: np.ndarray) -> int:
    runs = 0
    for ch in samples.T:
        hot = np.abs(ch) >= CLIP_LEVEL
        if not hot.any():
            continue
        # Lauflängen der True-Abschnitte
        edges = np.diff(np.concatenate(([0], hot.astype(np.int8), [0])))
        starts, ends = np.flatnonzero(edges == 1), np.flatnonzero(edges == -1)
        runs += int(np.sum((ends - starts) >= CLIP_RUN))
    return runs


def _silence_ms(mono: np.ndarray, rate: int, threshold_db: float) -> tuple[float, float]:
    threshold = 10 ** (threshold_db / 20)
    loud = np.flatnonzero(np.abs(mono) > threshold)
    if loud.size == 0:
        total = len(mono) / rate * 1000
        return total, total
    return loud[0] / rate * 1000, (len(mono) - 1 - loud[-1]) / rate * 1000


def _true_peak(samples: np.ndarray, rate: int) -> float:
    import soxr

    up = soxr.resample(samples, rate, rate * 4)
    return float(np.max(np.abs(up))) if up.size else 0.0


def _loudness(samples: np.ndarray, rate: int) -> float:
    import pyloudnorm

    block = 0.4
    if samples.shape[0] < block * rate:  # pyloudnorm braucht mindestens einen 400-ms-Block
        pad = np.zeros((int(block * rate) - samples.shape[0] + 1, samples.shape[1]), dtype=samples.dtype)
        samples = np.vstack([samples, pad])
    value = pyloudnorm.Meter(rate, block_size=block).integrated_loudness(samples)
    return float(value) if np.isfinite(value) else -70.0


def measure(audio: Audio, silence_threshold_db: float = -50.0) -> Metrics:
    s, rate = audio.samples, audio.sample_rate
    mono = audio.mono()
    lead, trail = _silence_ms(mono, rate, silence_threshold_db)
    corr = None
    if audio.channels == 2:
        left, right = s[:, 0], s[:, 1]
        if np.std(left) > 0 and np.std(right) > 0:
            corr = float(np.corrcoef(left, right)[0, 1])
        else:
            corr = 1.0 if np.allclose(left, right) else 0.0
    return Metrics(
        duration_s=round(audio.duration, 3),
        sample_rate=rate,
        channels=audio.channels,
        subtype=audio.subtype,
        peak_dbfs=round(_db(float(np.max(np.abs(s)))), 2),
        true_peak_dbfs=round(_db(_true_peak(s, rate)), 2),
        rms_dbfs=round(_db(float(np.sqrt(np.mean(s**2)))), 2),
        loudness_lufs=round(_loudness(s, rate), 2),
        clipped_runs=_clip_runs(s),
        clipped_fraction=round(float(np.mean(np.abs(s) >= CLIP_LEVEL)), 5),
        leading_silence_ms=round(lead, 1),
        trailing_silence_ms=round(trail, 1),
        dc_offset=round(float(np.mean(mono)), 5),
        channel_correlation=None if corr is None else round(corr, 4),
    )


def check(m: Metrics, rules: dict, duration_range: tuple[float, float] | None = None) -> list[Issue]:
    """Prüft Messwerte gegen die technischen Vorgaben des Profils."""
    issues: list[Issue] = []
    add = lambda *a: issues.append(Issue(*a))  # noqa: E731

    if m.clipped_runs > 0:
        add("error", "clipping", f"{m.clipped_runs} Clipping-Stelle(n) (≥{CLIP_RUN} Samples am Anschlag).",
            "Quelle ohne Übersteuerung neu exportieren oder vor der Verstärkung limitieren; Clipping lässt sich nicht sauber zurückrechnen.")
    max_peak = rules.get("max_true_peak_dbfs", -0.5)
    if m.true_peak_dbfs > max_peak and m.clipped_runs == 0:
        add("warn", "peak", f"True Peak {m.true_peak_dbfs:.1f} dBTP über der Grenze {max_peak} dBTP.",
            f"Mit einem True-Peak-Limiter auf {max_peak} dBTP begrenzen.")

    lo, hi = rules.get("loudness_lufs", (-24, -10))
    if m.loudness_lufs < lo:
        add("warn", "too_quiet", f"Lautheit {m.loudness_lufs:.1f} LUFS unter dem Zielbereich {lo}…{hi}.",
            f"Um etwa {lo + (hi - lo) / 2 - m.loudness_lufs:.0f} dB anheben (Peak im Blick behalten).")
    elif m.loudness_lufs > hi:
        add("warn", "too_loud", f"Lautheit {m.loudness_lufs:.1f} LUFS über dem Zielbereich {lo}…{hi}.",
            f"Um etwa {m.loudness_lufs - (lo + (hi - lo) / 2):.0f} dB absenken.")

    if duration_range:
        dmin, dmax = duration_range
        tol = rules.get("duration_tolerance", 0.25)  # ab dieser relativen Abweichung heißt es „deutlich"
        if m.duration_s < dmin:
            far = m.duration_s < dmin * (1 - tol)
            add("warn", "too_short", f"Dauer {m.duration_s:.2f} s kürzer als gewünscht ({dmin}–{dmax} s){' – deutlich' if far else ''}.",
                "Längere Variante wählen oder Ausklang/Hall verlängern.")
        elif m.duration_s > dmax:
            far = m.duration_s > dmax * (1 + tol)
            add("warn", "too_long", f"Dauer {m.duration_s:.2f} s länger als gewünscht ({dmin}–{dmax} s){' – deutlich' if far else ''}.",
                f"Auf {dmax} s kürzen und mit kurzem Fade-out (20–80 ms) enden lassen.")

    max_lead = rules.get("max_leading_silence_ms", 30)
    if m.leading_silence_ms > max_lead:
        add("warn", "leading_silence", f"{m.leading_silence_ms:.0f} ms Stille am Anfang (erlaubt {max_lead} ms).",
            "Anfang bis zum Transienten abschneiden – der Ton soll direkt auf die Aktion fallen.")
    max_trail = rules.get("max_trailing_silence_ms", 500)
    if m.trailing_silence_ms > max_trail:
        add("info", "trailing_silence", f"{m.trailing_silence_ms:.0f} ms Stille am Ende.",
            "Stille am Ende kürzen; spart Speicher und Polyphonie.")

    rates = rules.get("sample_rates", [44100, 48000])
    if rates and m.sample_rate not in rates:
        add("warn", "sample_rate", f"Abtastrate {m.sample_rate} Hz nicht in {rates}.", f"Nach {rates[0]} Hz wandeln.")
    if abs(m.dc_offset) > 0.01:
        add("warn", "dc_offset", f"Gleichspannungsanteil {m.dc_offset:+.3f}.", "Hochpass (~20 Hz) oder DC-Removal anwenden.")
    if m.channel_correlation is not None and m.channel_correlation > 0.999:
        add("info", "dual_mono", "Stereo-Datei mit identischen Kanälen.", "Als Mono speichern halbiert die Größe.")
    if m.channel_correlation is not None and m.channel_correlation < PHASE_ALERT:
        add("warn", "phase", f"Kanäle gegenphasig korreliert ({m.channel_correlation:.2f}); in Mono droht Auslöschung.",
            "Phase eines Kanals prüfen oder als Mono summieren und gegenhören.")
    if m.peak_dbfs < -60:
        add("error", "silent", "Datei ist praktisch stumm.", "Export prüfen.")
    return issues


def analyze(audio: Audio, rules: dict, duration_range: tuple[float, float] | None = None) -> TechnicalResult:
    m = measure(audio, rules.get("silence_threshold_db", -50.0))
    return TechnicalResult(metrics=m, issues=check(m, rules, duration_range))
