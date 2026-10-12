"""Bewertung: CLAP-Ähnlichkeiten + technische Analyse → Teil-Scores, Begründungen, Vorschläge.

Alle semantischen Werte sind Kosinus-Ähnlichkeiten zwischen CLAP-Einbettungen. Sie sagen,
wie nah ein Ton einer Beschreibung oder einem anderen Ton im Modellraum liegt – nicht, wie
gut er objektiv ist. Die Abbildung auf 0–100 ist eine Heuristik:

- semantic: Abstand der Ziel-Beschreibung zum Mittel der übrigen Effekte und zum besten
  anderen Effekt (fest skaliert, an echten Spielsounds abgelesen) sowie Rang unter allen
  Effekten des Profils.
- style / reference: relativ zum akzeptierten Bestand (Referenzen). Gibt es akzeptierte Töne
  genau dieses Effekts, zählt die Nähe zu ihnen zur Hälfte in den Referenz-Score. Ein Ton, der so typisch
  ist wie der Durchschnitt der Referenzen, bekommt ~69; eine Standardabweichung darunter ~31.
  Ohne Referenzen greift eine feste Skala.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

from . import technical
from .audio import Audio, file_hash, find_audio, load
from .clap import Embedder
from .profile import Effect, Profile

DISCLAIMER = (
    "Semantische Werte sind CLAP-Ähnlichkeiten (Modellraum), keine Hörprüfung und keine "
    "Qualitätswahrscheinlichkeit. Technische Werte sind gemessen. Endgültig entscheidet das Gehör."
)
REF_TOP_K = 3
SEM_CENTER, SEM_SCALE = 0.08, 0.06  # Ziel minus Mittel der anderen Effekte; gute Treffer liegen bei 0,2–0,5
GAP_CENTER, GAP_SCALE = -0.05, 0.05  # Ziel minus bester anderer Effekt; deutlich negativ = klingt nach etwas anderem
DUPLICATE_SIM = 0.98  # darüber gilt eine Referenz als derselbe Ton (z. B. neu kodierte Kopie)
STYLE_FALLBACK_CENTER, STYLE_FALLBACK_SCALE = -0.05, 0.06
MIN_STD = 0.03  # Mindest-Streuung des Bestands; sonst kippt die relative Skala bei sehr ähnlichen Referenzen
AVOID_ALERT = 0.15  # ab hier wird eine Nähe zu einem „avoid"-Prompt erwähnt


def _phi(z: float) -> float:
    return 0.5 * (1 + math.erf(z / math.sqrt(2)))


def _sigmoid(x: float) -> float:
    return 1 / (1 + math.exp(-x))


def _relative(x: float, mean: float, std: float) -> float:
    """0–100 relativ zu einer Verteilung: Mittelwert → ~69, eine Std. darunter → ~31."""
    return 100 * _phi((x - mean) / max(std, MIN_STD) + 0.5)


def _centroid(emb: np.ndarray) -> np.ndarray:
    m = emb.mean(axis=0)
    return m / max(np.linalg.norm(m), 1e-12)


@dataclass
class Evaluation:
    file: str
    effect: str | None
    effect_source: str | None  # argument | filename | None
    scores: dict
    semantic: dict
    style: dict
    reference: dict
    technical: dict
    verdict: str = ""
    reasons: list[str] = field(default_factory=list)
    suggestions: list[str] = field(default_factory=list)
    error: str | None = None
    hard_fail: bool = False  # technischer Fehler (Clipping, stumm): nicht empfehlen, egal wie hoch der Score

    @property
    def total(self) -> float:
        return self.scores.get("total") or 0.0

    def to_dict(self) -> dict:
        return {k: v for k, v in self.__dict__.items()}


class Evaluator:
    def __init__(self, profile: Profile, embedder: Embedder, use_references: bool = True):
        self.profile = profile
        self.embedder = embedder
        self.effect_names = list(profile.effects)
        enc = embedder.embed_text
        self.effect_emb = (
            np.stack([_centroid(enc(e.prompts)) for e in profile.effects.values()])
            if profile.effects else np.zeros((0, 1))
        )
        self.effect_avoid = {n: enc(e.avoid) for n, e in profile.effects.items() if e.avoid}
        self.style_emb = enc(profile.style_prompts) if profile.style_prompts else None
        self.avoid_emb = enc(profile.style_avoid) if profile.style_avoid else None
        self._load_references(use_references)

    # --- Referenzen -------------------------------------------------------------------
    def _load_references(self, enabled: bool) -> None:
        self.ref_files: list[Path] = []
        self.ref_hashes: list[str] = []
        self.ref_emb = None
        self.ref_baseline = None  # (mean, std) der Top-k-Ähnlichkeit jeder Referenz zu den übrigen
        self.style_baseline = None
        if not enabled or not self.profile.references:
            return
        files = [f for f in find_audio(self.profile.references) if not self.profile.is_excluded_reference(f)]
        if not files:
            return
        audios = [load(f) for f in files]
        self.ref_files = files
        self.ref_hashes = [file_hash(f) for f in files]
        self.ref_emb = self.embedder.embed_audio(audios)
        if len(files) >= 3:
            sims = self.ref_emb @ self.ref_emb.T
            np.fill_diagonal(sims, -np.inf)
            k = min(REF_TOP_K, len(files) - 1)
            tops = np.sort(sims, axis=1)[:, -k:].mean(axis=1)
            self.ref_baseline = (float(tops.mean()), float(tops.std()))
            margins = [self._style_raw(e)["margin"] for e in self.ref_emb]
            if margins[0] is not None:
                self.style_baseline = (float(np.mean(margins)), float(np.std(margins)))

    def _effect_ref_emb(self, effect: Effect) -> tuple[list[Path], np.ndarray | None]:
        """Ausdrückliche Effekt-Referenzen plus Bestandsdateien, die zum Dateimuster des Effekts passen."""
        files = find_audio(effect.references) if effect.references else []
        pool = [f for f in self.ref_files if self.profile.effect_for_file(f) is effect]
        files = list(dict.fromkeys([*files, *pool]))
        return files, self.embedder.embed_audio([load(f) for f in files]) if files else None

    # --- Teil-Analysen ----------------------------------------------------------------
    def _style_raw(self, emb: np.ndarray) -> dict:
        style = float((self.style_emb @ emb).mean()) if self.style_emb is not None else None
        avoid_sims = (self.avoid_emb @ emb) if self.avoid_emb is not None else None
        avoid = float(avoid_sims.max()) if avoid_sims is not None else None
        top_avoid = self.profile.style_avoid[int(np.argmax(avoid_sims))] if avoid_sims is not None else None
        margin = None if style is None else style - (avoid if avoid is not None else 0.0)
        return {"style_similarity": style, "avoid_similarity": avoid, "closest_avoid": top_avoid, "margin": margin}

    def _semantic(self, emb: np.ndarray, effect: Effect | None) -> dict:
        if not self.effect_names:
            return {"score": None}
        sims = self.effect_emb @ emb
        order = np.argsort(-sims)
        best = [{"effect": self.effect_names[i], "similarity": round(float(sims[i]), 4)} for i in order[:3]]
        out = {"best_matches": best, "n_effects": len(self.effect_names), "score": None}
        if effect is None:
            return out
        t = self.effect_names.index(effect.name)
        others = np.delete(sims, t)
        rank = int(np.flatnonzero(order == t)[0]) + 1
        contrast = float(sims[t] - (others.mean() if others.size else 0.0))
        gap = float(sims[t] - (others.max() if others.size else 0.0))
        n = len(self.effect_names)
        rank_score = 1 - (rank - 1) / (n - 1) if n > 1 else 1.0
        score = 100 * (
            0.4 * _sigmoid((contrast - SEM_CENTER) / SEM_SCALE)
            + 0.3 * _sigmoid((gap - GAP_CENTER) / GAP_SCALE)
            + 0.3 * rank_score
        )
        out.update(target_similarity=round(float(sims[t]), 4), rank=rank, contrast=round(contrast, 4),
                   gap_to_best_other=round(gap, 4), score=round(score, 1))
        if effect.name in self.effect_avoid:
            a = self.effect_avoid[effect.name] @ emb
            i = int(np.argmax(a))
            out["effect_avoid"] = {"prompt": effect.avoid[i], "similarity": round(float(a[i]), 4)}
        return out

    def _style(self, emb: np.ndarray) -> dict:
        raw = self._style_raw(emb)
        if raw["margin"] is None:
            return {**raw, "score": None}
        if self.style_baseline:
            score, basis = _relative(raw["margin"], *self.style_baseline), "references"
        else:
            score, basis = 100 * _sigmoid((raw["margin"] - STYLE_FALLBACK_CENTER) / STYLE_FALLBACK_SCALE), "fixed"
        rounded = {k: (round(v, 4) if isinstance(v, float) else v) for k, v in raw.items()}
        return {**rounded, "score": round(score, 1), "basis": basis}

    def _reference(self, emb: np.ndarray, digest: str, effect: Effect | None) -> dict:
        out: dict = {"score": None}
        if self.ref_emb is not None:
            all_sims = self.ref_emb @ emb
            # sich selbst (gleicher Hash) und Fast-Duplikate nicht mitzählen
            dupes = [i for i, h in enumerate(self.ref_hashes) if h == digest or all_sims[i] >= DUPLICATE_SIM]
            if dupes:
                out["duplicate_of"] = [self.ref_files[i].name for i in dupes]
            keep = [i for i in range(len(self.ref_files)) if i not in dupes]
            if keep:
                sims = self.ref_emb[keep] @ emb
                order = np.argsort(-sims)
                k = min(REF_TOP_K, len(keep))
                top = float(np.sort(sims)[-k:].mean())
                out.update(
                    top_k_similarity=round(top, 4),
                    closest=[{"file": self.ref_files[keep[i]].name, "similarity": round(float(sims[i]), 4)} for i in order[:3]],
                )
                if self.ref_baseline:
                    out["baseline"] = {"mean": round(self.ref_baseline[0], 4), "std": round(self.ref_baseline[1], 4)}
                    out["score"] = round(_relative(top, *self.ref_baseline), 1)
                else:
                    out["score"] = round(100 * max(0.0, min(1.0, top)), 1)
        if effect is not None:
            files, eref = self._effect_ref_emb(effect)
            if eref is not None:
                pairs = [(f, float(s)) for f, s, h in zip(files, eref @ emb, map(file_hash, files))
                         if h != digest and s < DUPLICATE_SIM]
                if pairs:
                    out["effect_references"] = [{"file": f.name, "similarity": round(s, 4)} for f, s in pairs]
                    if out["score"] is not None and self.ref_baseline:
                        # Nähe zu den akzeptierten Tönen genau dieses Effekts zählt zur Hälfte
                        best = max(s for _, s in pairs)
                        out["pool_score"] = out["score"]
                        out["effect_score"] = round(_relative(best, *self.ref_baseline), 1)
                        out["score"] = round((out["pool_score"] + out["effect_score"]) / 2, 1)
        return out

    # --- Gesamtbewertung --------------------------------------------------------------
    def resolve_effect(self, path: Path, effect_name: str | None) -> tuple[Effect | None, str | None]:
        if effect_name:
            if effect_name not in self.profile.effects:
                raise KeyError(f"Effekt '{effect_name}' steht nicht im Profil. Vorhanden: {', '.join(self.effect_names)}")
            return self.profile.effects[effect_name], "argument"
        effect = self.profile.effect_for_file(path)
        return (effect, "filename") if effect else (None, None)

    def evaluate(self, paths: list[Path], effect_name: str | None = None) -> list[Evaluation]:
        audios, results, slots = [], [], []
        for p in paths:
            try:
                audios.append(load(p))
                slots.append(len(results))
                results.append(None)
            except Exception as exc:  # defekte Datei soll den Batch nicht abbrechen
                results.append(Evaluation(str(p), None, None, {}, {}, {}, {}, {}, verdict="Fehler", error=str(exc)))
        embs = self.embedder.embed_audio(audios) if audios else []
        for audio, emb, slot in zip(audios, embs, slots):
            results[slot] = self._evaluate_one(audio, emb, effect_name)
        return results

    def _evaluate_one(self, audio: Audio, emb: np.ndarray, effect_name: str | None) -> Evaluation:
        effect, source = self.resolve_effect(audio.path, effect_name)
        tech = technical.analyze(audio, self.profile.technical, effect.duration if effect else None)
        sem = self._semantic(emb, effect)
        sty = self._style(emb)
        ref = self._reference(emb, file_hash(audio.path), effect)
        scores = {"semantic": sem.get("score"), "style": sty.get("score"), "reference": ref.get("score"), "technical": tech.score}
        w = {k: self.profile.weights.get(k, 0) for k, v in scores.items() if v is not None}
        total = sum(scores[k] * w[k] for k in w) / sum(w.values()) if sum(w.values()) else None
        scores["total"] = None if total is None else round(total, 1)
        ev = Evaluation(str(audio.path), effect.name if effect else None, source, scores, sem, sty, ref, tech.to_dict())
        _explain(ev, effect, self.profile, tech)
        return ev


def _explain(ev: Evaluation, effect: Effect | None, profile: Profile, tech: technical.TechnicalResult) -> None:
    r, s = ev.reasons, ev.suggestions
    sem, sty, ref = ev.semantic, ev.style, ev.reference

    if effect is None:
        if sem.get("best_matches"):
            guess = ", ".join(f"{b['effect']} ({b['similarity']:.2f})" for b in sem["best_matches"])
            r.append(f"Kein Ziel-Effekt zugeordnet; am ähnlichsten im Profil: {guess}.")
            s.append("Mit --effect <name> bewerten oder ein Dateimuster unter effects.<name>.files ergänzen.")
    elif sem.get("rank") is not None:
        best = sem["best_matches"][0]
        r.append(
            f"Beschreibung '{effect.name}' liegt auf Platz {sem['rank']} von {sem['n_effects']} Effekten "
            f"(Ähnlichkeit {sem['target_similarity']:.2f}, Abstand zum Mittel der anderen {sem['contrast']:+.2f})."
        )
        if best["effect"] != effect.name:
            other = profile.effects[best["effect"]]
            r.append(f"Im CLAP-Raum näher an '{best['effect']}' ({best['similarity']:.2f}): {other.description or other.prompts[0]}")
            if sem["rank"] > 3:
                s.append(
                    f"Charakter gegen die Vorgabe prüfen: {effect.description or effect.prompts[0]} "
                    "Passt der Ton nach Gehör trotzdem, ist eher die Profil-Beschreibung zu unscharf als der Ton falsch."
                )
        ea = sem.get("effect_avoid")
        if ea and ea["similarity"] > AVOID_ALERT:
            r.append(f"Ähnelt dem Unerwünschten '{ea['prompt']}' ({ea['similarity']:.2f}).")

    if sty.get("closest_avoid") and (sty.get("avoid_similarity") or 0) > max(AVOID_ALERT, sty.get("style_similarity") or 0):
        r.append(f"Stilistisch näher an '{sty['closest_avoid']}' ({sty['avoid_similarity']:.2f}) als an den Stil-Prompts ({sty['style_similarity']:.2f}).")
        s.append(f"Variante ohne Anklang an '{sty['closest_avoid']}' suchen; bei Generierung ausdrücklich ausschließen.")
    elif sty.get("score") is not None:
        r.append(f"Stil-Nähe {sty['style_similarity']:.2f} zu den Stil-Prompts ({'relativ zum Bestand' if sty.get('basis') == 'references' else 'feste Skala'}).")

    if ref.get("closest"):
        close = ", ".join(f"{c['file']} ({c['similarity']:.2f})" for c in ref["closest"])
        r.append(f"Nächste akzeptierte Töne: {close}.")
        if ref.get("score") is not None and ref["score"] < 31:
            s.append("Weicht deutlich vom akzeptierten Bestand ab – gewollt (neue Klangfarbe) oder Ausreißer? Neben den nächsten Referenzen gegenhören.")
    if ref.get("duplicate_of"):
        r.append(f"Praktisch identisch mit der Referenz {', '.join(ref['duplicate_of'])} (beim Abgleich ausgelassen).")
    for er in ref.get("effect_references", []):
        r.append(f"Ähnlichkeit zur Effekt-Referenz {er['file']}: {er['similarity']:.2f}.")

    for issue in tech.issues:
        r.append(f"Technik ({issue.severity}): {issue.message}")
        if issue.suggestion:
            s.append(issue.suggestion)

    total = ev.scores.get("total")
    hard = ev.hard_fail = any(i.severity == "error" for i in tech.issues)
    if total is None:
        ev.verdict = "keine Bewertung"
    elif hard:
        ev.verdict = "technisch nachbessern"
    elif total >= 70:
        ev.verdict = "passt gut"
    elif total >= 50:
        ev.verdict = "prüfen"
    else:
        ev.verdict = "passt eher nicht"
