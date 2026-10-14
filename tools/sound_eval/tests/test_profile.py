from pathlib import Path

import pytest

from soundeval.profile import load_profile

REPO_PROFILE = Path(__file__).resolve().parents[1] / "profiles" / "monster_slam.yaml"


def test_repo_profile_loads():
    p = load_profile(REPO_PROFILE)
    assert p.name == "Monster Slam"
    assert "spell_freeze" in p.effects
    assert p.effect_for_file(Path("spell_freeze_v2.wav")).name == "spell_freeze"
    assert p.effect_for_file(Path("spell_thunder.wav")).name == "spell_thunder"
    assert p.effect_for_file(Path("spell_thunder_windup.wav")).name == "spell_thunder_windup"
    assert p.effect_for_file(Path("random.wav")) is None
    assert all(r.is_absolute() for r in p.references)


def test_defaults_and_generation_prompt(profile_file):
    p = load_profile(profile_file("""
        name: X
        style: {prompts: [cozy fantasy]}
        effects:
          coin: {prompts: coin pickup, duration: [0.2, 0.5]}
    """))
    assert p.weights["semantic"] == 0.40 and p.technical["max_leading_silence_ms"] == 30
    assert p.effects["coin"].prompts == ["coin pickup"]
    assert p.effects["coin"].duration == (0.2, 0.5)
    assert p.generation_prompt(p.effects["coin"]) == "coin pickup, cozy fantasy"


def test_effect_without_prompt_fails(profile_file):
    with pytest.raises(ValueError, match="prompts"):
        load_profile(profile_file("effects:\n  coin: {description: x}\n"))
