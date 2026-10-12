"""Echtes CLAP-Modell gegen echte Spielsounds. Läuft nur, wenn das Modell schon im Cache liegt."""

from pathlib import Path

import pytest

from soundeval.profile import load_profile

pytestmark = pytest.mark.clap
REPO_PROFILE = Path(__file__).resolve().parents[1] / "profiles" / "monster_slam.yaml"
SFX = Path(__file__).resolve().parents[3] / "assets" / "audio" / "sfx"


@pytest.fixture(scope="module")
def evaluator():
    profile = load_profile(REPO_PROFILE)
    from soundeval.clap import model_cached

    if not model_cached(profile.model) or not SFX.exists():
        pytest.skip("CLAP-Modell nicht im Cache oder Spielsounds fehlen")
    from soundeval.clap import ClapEmbedder
    from soundeval.evaluate import Evaluator

    return Evaluator(profile, ClapEmbedder(profile.model, use_cache=False))


def test_thunder_beats_other_spells_for_thunder(evaluator):
    from soundeval import report

    files = sorted(SFX.glob("spell_*.wav"))
    ranked = report.rank(evaluator.evaluate(files, "spell_thunder"))
    assert Path(ranked[0]["file"]).name == "spell_thunder.wav"


def test_known_matches_rank_first(evaluator):
    for name in ("spell_slow.wav", "spell_thunder.wav", "wave_cleared.wav"):
        (r,) = evaluator.evaluate([SFX / name])
        assert r.semantic["rank"] == 1, name
