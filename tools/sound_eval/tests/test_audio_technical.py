import numpy as np
import pytest

from conftest import RATE, tone
from soundeval import technical
from soundeval.audio import find_audio, load
from soundeval.profile import DEFAULT_TECHNICAL


def codes(issues):
    return {i.code for i in issues}


def analyze(path, duration=None, **rules):
    return technical.analyze(load(path), {**DEFAULT_TECHNICAL, **rules}, duration)


def test_loads_wav_and_mp3(write_wav):
    wav = write_wav("a.wav", tone())
    mp3 = write_wav("b.mp3", tone(), format="MP3")
    assert load(wav).duration == pytest.approx(0.8, abs=0.01)
    m = load(mp3)
    assert m.file_format == "MP3" and m.duration == pytest.approx(0.8, abs=0.1)


def test_unsupported_format(tmp_path):
    p = tmp_path / "x.txt"
    p.write_text("nope")
    with pytest.raises(ValueError):
        load(p)


def test_find_audio_recursive_and_dedup(write_wav, tmp_path):
    a = write_wav("sub/a.wav", tone())
    write_wav("b.wav", tone())
    (tmp_path / "notes.md").write_text("x")
    found = find_audio([tmp_path, a])
    assert [f.name for f in found] == ["b.wav", "a.wav"] or sorted(f.name for f in found) == ["a.wav", "b.wav"]
    assert len(found) == 2
    assert [f.name for f in find_audio([tmp_path], recursive=False)] == ["b.wav"]


def test_clean_tone_has_no_issues(write_wav):
    r = analyze(write_wav("clean.wav", tone(amp=0.3)), duration=(0.5, 1.0))
    assert r.issues == []
    assert r.score == 100
    assert -0.1 < r.metrics.leading_silence_ms < 1


def test_clipping_is_error_single_peak_is_not(write_wav):
    clipped = np.clip(tone(amp=1.0) * 3, -1, 1)
    r = analyze(write_wav("clip.wav", clipped))
    assert "clipping" in codes(r.issues)
    assert any(i.severity == "error" for i in r.issues)
    single = tone(amp=0.3)
    single[1000] = 1.0
    assert "clipping" not in codes(analyze(write_wav("one.wav", single)).issues)


def test_leading_silence_and_duration(write_wav):
    r = analyze(write_wav("late.wav", tone(seconds=0.5, lead=0.2)), duration=(1.0, 1.5))
    assert {"leading_silence", "too_short"} <= codes(r.issues)
    assert r.metrics.leading_silence_ms == pytest.approx(200, abs=10)
    too_long = analyze(write_wav("long.wav", tone(seconds=3)), duration=(0.5, 1.0))
    assert "deutlich" in next(i.message for i in too_long.issues if i.code == "too_long")


def test_loudness_window(write_wav):
    quiet = analyze(write_wav("quiet.wav", tone(amp=0.001)))
    assert "too_quiet" in codes(quiet.issues)
    loud = analyze(write_wav("loud.wav", tone(amp=0.3)), loudness_lufs=[-40, -30])
    assert "too_loud" in codes(loud.issues)


def test_silent_file(write_wav):
    r = analyze(write_wav("silent.wav", np.zeros((RATE, 1), np.float32)))
    assert "silent" in codes(r.issues)


def test_dc_offset_sample_rate_and_dual_mono(write_wav):
    r = analyze(write_wav("odd.wav", tone(channels=2) + 0.05, rate=22050))
    assert {"dc_offset", "sample_rate", "dual_mono"} <= codes(r.issues)


def test_inverted_stereo_warns_about_phase(write_wav):
    t = tone()
    r = analyze(write_wav("phase.wav", np.concatenate([t, -t], axis=1)))
    assert "phase" in codes(r.issues)
