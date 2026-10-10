import json

import numpy as np
import pytest

from conftest import FakeEmbedder, tone
from soundeval import report
from soundeval.evaluate import DISCLAIMER, Evaluator
from soundeval.profile import load_profile

E = np.eye(8)
TEXTS = {"ice": E[0], "mud": E[1], "thunder": E[2], "fantasy": E[3], "chiptune": E[4]}
AUDIO = {
    "ref_ice": E[0] + E[3], "ref_mud": E[1] + E[3], "ref_thunder": E[2] + E[3],
    "ice_good": E[0] + 1.1 * E[3] + 0.5 * E[5], "ice_mud": E[1] + 0.3 * E[3], "ice_chip": E[0] + 2 * E[4],
    "copy_of_ref": E[0] + E[3],
}


@pytest.fixture
def setup(profile_file, write_wav):
    for name in ("ref_ice", "ref_mud", "ref_thunder"):
        write_wav(f"refs/{name}.wav", tone(seconds=0.6))
    profile = load_profile(profile_file("""
        name: Test
        references: [refs]
        style: {prompts: [fantasy], avoid: [chiptune]}
        technical: {loudness_lufs: [-40, -5]}
        effects:
          ice: {prompts: [ice], duration: [0.5, 1.0], files: ["ice_*", "ref_ice*"]}
          mud: {prompts: [mud], files: ["ref_mud*"]}
          thunder: {prompts: [thunder], files: ["ref_thunder*"]}
    """))
    ev = Evaluator(profile, FakeEmbedder(TEXTS, AUDIO))

    def run(*names, effect=None, data=None):
        paths = [write_wav(f"cand/{n}.wav", data if data is not None else tone(seconds=0.7)) for n in names]
        return ev.evaluate(paths, effect)

    return ev, run


def test_matching_sound_scores_high_with_reasons(setup):
    _, run = setup
    (r,) = run("ice_good")
    assert r.effect == "ice" and r.effect_source == "filename"
    assert r.semantic["rank"] == 1
    assert r.scores["semantic"] > 80 and r.scores["technical"] == 100
    assert r.verdict == "passt gut", r.scores
    assert any("Platz 1 von 3" in x for x in r.reasons)
    assert r.reference["effect_references"][0]["file"] == "ref_ice.wav"


def test_wrong_character_ranks_low_and_names_closer_effect(setup):
    _, run = setup
    good, wrong = run("ice_good", "ice_mud")
    assert wrong.semantic["best_matches"][0]["effect"] == "mud"
    assert wrong.scores["semantic"] < 40 < good.scores["semantic"]
    assert any("'mud'" in x for x in wrong.reasons)


def test_avoid_prompt_is_flagged(setup):
    _, run = setup
    (r,) = run("ice_chip")
    assert r.style["closest_avoid"] == "chiptune"
    assert any("chiptune" in x for x in r.suggestions)


def test_duplicate_of_reference_is_excluded(setup):
    _, run = setup
    (r,) = run("copy_of_ref")
    assert r.reference["duplicate_of"] == ["ref_ice.wav"]
    assert all(c["file"] != "ref_ice.wav" for c in r.reference["closest"])


def test_unknown_effect_reports_best_guess(setup):
    _, run = setup
    (r,) = run("mystery")
    assert r.effect is None and r.scores["semantic"] is None
    assert r.scores["total"] is not None
    assert any("Kein Ziel-Effekt" in x for x in r.reasons)


def test_explicit_effect_and_unknown_name(setup):
    ev, run = setup
    (r,) = run("ice_mud", effect="mud")
    assert r.effect_source == "argument" and r.semantic["rank"] == 1
    with pytest.raises(KeyError):
        run("ice_good", effect="lava")


def test_broken_file_does_not_stop_batch(setup, tmp_path):
    ev, run = setup
    bad = tmp_path / "cand" / "broken.wav"
    bad.parent.mkdir(exist_ok=True)
    bad.write_bytes(b"not audio")
    good = run("ice_good")[0]
    results = ev.evaluate([bad, __import__("pathlib").Path(good.file)])
    assert results[0].error and results[1].error is None


def test_ranking_demotes_hard_failures_and_marks_ties(setup):
    _, run = setup
    clean = run("ice_good")[0]
    clipped = run("ice_chip", data=np.clip(tone(amp=1.0) * 4, -1, 1))[0]
    clipped.scores["total"] = 99.0  # selbst mit Spitzenscore nicht empfehlen
    weak = run("ice_mud")[0]
    weak.scores["total"] = clean.total - 1
    ranked = report.rank([clipped, weak, clean], top=1)
    assert [r["file"] for r in ranked][-1] == clipped.file
    assert ranked[0]["file"] == clean.file and ranked[0]["recommended"]
    assert ranked[1]["tie_with_previous"] and not ranked[1]["recommended"]
    assert not ranked[-1]["recommended"]


def test_nothing_recommended_below_threshold(setup):
    _, run = setup
    (r,) = run("ice_mud")
    r.scores["total"] = 30.0
    assert not report.rank([r])[0]["recommended"]


def test_report_files(setup, tmp_path):
    _, run = setup
    results = run("ice_good", "ice_mud")
    rep = report.build(results, "Test", "fake", "rank", report.rank(results))
    j, md = report.write(rep, tmp_path / "out", "rank-ice")
    data = json.loads(j.read_text(encoding="utf-8"))
    assert data["disclaimer"] == DISCLAIMER and len(data["results"]) == 2
    text = md.read_text(encoding="utf-8")
    assert "## Ranking" in text and "★" in text and DISCLAIMER in text
