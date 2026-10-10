import json

import pytest

from soundeval import cli
from soundeval import elevenlabs as el
from soundeval.cli import EXIT_NEEDS_CONFIRMATION, main


@pytest.fixture(autouse=True)
def isolated_cache(tmp_path, monkeypatch):
    monkeypatch.setenv("SOUND_EVAL_CACHE", str(tmp_path / "cache"))
    monkeypatch.delenv("ELEVENLABS_API_KEY", raising=False)


def test_estimate():
    s = el.settings_for({})
    assert el.estimate(1.0, s) == 20 and el.estimate(0.75, s) == 15
    assert el.estimate(None, s) == 100


def test_budget_limits(tmp_path):
    s = el.settings_for({"max_credits_per_run": 50, "max_credits_total": 100})
    with pytest.raises(el.BudgetError, match="pro Lauf"):
        el.make_plan("x", 3, 1.0, s)
    ledger = tmp_path / "ledger.jsonl"
    ledger.write_text(json.dumps({"credits": 90}) + "\n")
    with pytest.raises(el.BudgetError, match="Gesamtlimit"):
        el.make_plan("x", 1, 1.0, s, ledger)
    with pytest.raises(ValueError):
        el.make_plan("x", 1, 40.0, s)
    with pytest.raises(ValueError, match="MP3"):
        el.make_plan("x", 1, 1.0, {**s, "output_format": "pcm_44100"})


def test_generate_requires_confirmation_and_logs(tmp_path):
    plan = el.make_plan("ice spell", 2, 1.0, el.settings_for({}))
    calls = []

    def fake_post(url, key, body):
        calls.append((url, key, body))
        return b"ID3fake"

    with pytest.raises(PermissionError):
        el.generate(plan, tmp_path, post=fake_post, api_key="k")
    assert calls == []
    ledger = tmp_path / "l.jsonl"
    files = el.generate(plan, tmp_path / "gen", name="spell_freeze", confirmed=True, api_key="k", post=fake_post, ledger=ledger)
    assert len(files) == 2 and all(f.suffix == ".mp3" and f.read_bytes() == b"ID3fake" for f in files)
    assert calls[0][2]["duration_seconds"] == 1.0 and "output_format=mp3_44100_128" in calls[0][0]
    assert el.spent_total(ledger) == 40


def test_cli_generate_without_yes_sends_nothing(monkeypatch, capsys):
    monkeypatch.setattr(el, "generate", lambda *a, **k: pytest.fail("darf ohne Bestätigung nicht senden"))
    monkeypatch.setattr("sys.stdin.isatty", lambda: False, raising=False)
    code = main(["generate", "--effect", "spell_freeze", "--variants", "2"])
    assert code == EXIT_NEEDS_CONFIRMATION
    out = capsys.readouterr().out
    assert "Geschätzte Kosten: 32 Credits" in out  # 2 × 0,8 s × 20


def test_cli_generate_dry_run_and_budget(capsys):
    assert main(["generate", "--prompt", "coin", "--auto-duration", "--variants", "1", "--dry-run"]) == 0
    assert "100 Credits" in capsys.readouterr().out
    assert main(["generate", "--effect", "spell_freeze", "--variants", "50", "--dry-run"]) == 2


def test_cli_effects(capsys):
    assert main(["effects"]) == 0
    assert "spell_thunder" in capsys.readouterr().out


def test_cli_unknown_effect(capsys):
    assert main(["generate", "--effect", "nope", "--dry-run"]) == 1
