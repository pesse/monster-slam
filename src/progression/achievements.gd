class_name Achievements
extends RefCounted
## Die Erfolge (Issue #74): was einmal für immer erreicht ist, im Gegensatz zu den Plaketten
## des Tages (Badges). Reine Regeln über einem Fakten-Dictionary; freigeschaltet und
## gespeichert wird in `AchievementBook`. Ein abgeleiteter Erfolg nennt einen Fakt und die
## Zahl, die er braucht, ein Moment-Erfolg (`moment`) wird vom Kampf gemeldet.

## Bilder der Erfolge: <icon>.webp, quadratisch; HIDDEN_ICON steht für noch versteckte.
const ICON_DIR := "res://assets/ui/achievements/icons/"
const HIDDEN_ICON := "hidden"
## Ab so vielen richtig übersetzten Wörtern einer Sprache.
const WORD_STEPS := [50, 100, 500, 1000]
const WORD_TITLES := ["Wortschnüffler", "Vokabeljäger", "Wörterdrache", "Sprachmonster"]
## „Am seidenen Faden“: höchstens so viele HP nach der gewonnenen Welle.
const THREAD_HP := 5
## „Unberührt“: so viele gewonnene Wellen eines Laufs ohne Schaden.
const UNTOUCHED_WAVES := 3
## „Dreifache Revanche“: so viele Revanchen in einer Welle (Badges.revenges_this_wave).
const REVENGES := 3
## Spielzeuge der Gebietskarte (EventBus.secret_found), die AchievementBook zählt; jedes ist
## ein Fakt gleichen Namens.
const SECRETS := ["fish", "stone7", "volcano_rage", "torch_out", "birds"]

## Ein Erfolg: id, fact (Schlüssel in den Fakten, leer bei `moment`), need, title, body,
## hidden, dazu `icon`, wo das Bild nicht wie die Id heißt. Die Wort-Erfolge je Sprache
## kommen in `catalog` dazu.
const FIXED := [
	{"id": "mastered_first", "fact": "mastered", "need": 1,
			"title": "Das erste Wort sitzt", "body": "Ein Wort in allen Richtungen gemeistert."},
	{"id": "mastered_100", "fact": "mastered", "need": 100,
			"title": "Hundert sitzen", "body": "100 Wörter gemeistert."},
	{"id": "mastered_250", "fact": "mastered", "need": 250,
			"title": "Zweihundertfünfzig sitzen", "body": "250 Wörter gemeistert."},
	{"id": "mastered_500", "fact": "mastered", "need": 500,
			"title": "Fünfhundert sitzen", "body": "500 Wörter gemeistert."},
	{"id": "mastered_1000", "fact": "mastered", "need": 1000,
			"title": "Tausend sitzen", "body": "1000 Wörter gemeistert."},
	{"id": "elephant", "fact": "elephant", "need": 1,
			"title": "Elefantengedächtnis",
			"body": "Ein Wort richtig gewusst, das du 30 Tage nicht mehr gesehen hattest."},
	{"id": "irregular_unit", "fact": "irregular_units", "need": 1,
			"title": "Unregelmäßig? Na und!",
			"body": "Alle unregelmäßigen Verben einer Unit samt ihren Formen gemeistert."},
	{"id": "unit_tier_4", "fact": "best_unit_tier", "need": 4,
			"title": "Uneinnehmbar", "body": "Eine Unit auf Festungsstufe 4."},
	{"id": "book_tier_2", "fact": "best_book_tier", "need": 2,
			"title": "Das ganze Buch", "body": "Jede Unit eines Buchs mindestens auf Festungsstufe 2."},
	{"id": "boss_first", "fact": "boss_wins", "need": 1,
			"title": "Bossbezwinger", "body": "Einen Boss besiegt."},
	{"id": "boss_gold", "fact": "best_medal", "need": 3,
			"title": "Goldener Bezwinger", "body": "Einen Boss so oft besiegt, dass es Gold gibt."},
	{"id": "boss_5", "fact": "boss_wins", "need": 5,
			"title": "Bossjäger", "body": "5 Bosskämpfe gewonnen."},
	{"id": "boss_10", "fact": "boss_wins", "need": 10,
			"title": "Bossschreck", "body": "10 Bosskämpfe gewonnen."},
	{"id": "boss_book", "fact": "boss_books", "need": 1,
			"title": "Kein Boss mehr übrig", "body": "Jeden Boss eines Buchs besiegt."},
	{"id": "boss_book_gold", "fact": "boss_books_gold", "need": 1,
			"title": "Goldenes Buch", "body": "Jeden Boss eines Buchs so oft besiegt, dass es Gold gibt."},
	{"id": "streak_7", "fact": "best_streak", "need": 7,
			"title": "Eine Woche dabei", "body": "7 Tage in Folge gespielt."},
	{"id": "streak_30", "fact": "best_streak", "need": 30,
			"title": "Ein Monat dabei", "body": "30 Tage in Folge gespielt."},
	{"id": "days_50", "fact": "play_days", "need": 50,
			"title": "Stammgast", "body": "An 50 Tagen gespielt, egal ob in Folge."},
	{"id": "days_100", "fact": "play_days", "need": 100,
			"title": "Hundert Spieltage", "body": "An 100 Tagen gespielt, egal ob in Folge."},
	{"id": "days_200", "fact": "play_days", "need": 200,
			"title": "Festungsurgestein", "body": "An 200 Tagen gespielt, egal ob in Folge."},
	{"id": "level_5", "fact": "level", "need": 5,
			"title": "Level 5", "body": "Level 5 erreicht."},
	{"id": "level_10", "fact": "level", "need": 10,
			"title": "Level 10", "body": "Level 10 erreicht."},
	{"id": "level_20", "fact": "level", "need": 20,
			"title": "Level 20", "body": "Level 20 erreicht."},
	{"id": "level_30", "fact": "level", "need": 30,
			"title": "Level 30", "body": "Level 30 erreicht."},
	{"id": "level_40", "fact": "level", "need": 40,
			"title": "Level 40", "body": "Level 40 erreicht."},
	{"id": "level_50", "fact": "level", "need": 50,
			"title": "Level 50", "body": "Level 50 erreicht."},
	{"id": "level_60", "fact": "level", "need": 60,
			"title": "Level 60", "body": "Level 60 erreicht."},
	{"id": "level_70", "fact": "level", "need": 70,
			"title": "Level 70", "body": "Level 70 erreicht."},
	{"id": "level_80", "fact": "level", "need": 80,
			"title": "Level 80", "body": "Level 80 erreicht."},
	{"id": "level_90", "fact": "level", "need": 90,
			"title": "Level 90", "body": "Level 90 erreicht."},
	{"id": "level_100", "fact": "level", "need": 100,
			"title": "Level 100", "body": "Level 100 erreicht."},
	{"id": "chests_10", "fact": "chests", "need": 10,
			"title": "Schatzsucher", "body": "10 Schatzkisten geöffnet."},
	{"id": "chests_100", "fact": "chests", "need": 100,
			"title": "Schatzjäger", "body": "100 Schatzkisten geöffnet."},
	{"id": "chests_1000", "fact": "chests", "need": 1000,
			"title": "Drachenhort", "body": "1000 Schatzkisten geöffnet."},
	{"id": "skill_first", "fact": "skills", "need": 1,
			"title": "Erste Fähigkeit", "body": "Eine Fähigkeit gelernt."},
	{"id": "skill_branch", "fact": "branches", "need": 1,
			"title": "Ast ausgebaut", "body": "Einen Ast eines Fähigkeitsbaums bis ans Ende gelernt."},
	{"id": "badges_all", "fact": "badge_kinds", "need": 8,
			"title": "Plakettensammler", "body": "Jede Plakette des Tages mindestens einmal verdient."},
	{"id": "wave_last_hp", "moment": true, "hidden": true,
			"title": "Am seidenen Faden", "body": "Eine Welle gewonnen, als die Festung nur noch 5 HP oder weniger hatte."},
	{"id": "run_untouched", "moment": true, "hidden": true,
			"title": "Unberührt", "body": "Drei Wellen eines Laufs ohne einen Kratzer an der Festung."},
	{"id": "boss_flawless", "moment": true, "hidden": true,
			"title": "Kein einziger Fehler", "body": "Einen Boss ohne falsche Antwort besiegt."},
	{"id": "revenge_3", "moment": true, "hidden": true,
			"title": "Dreifache Revanche", "body": "Drei Wörter in einer Welle getroffen, die dir zuletzt entwischt sind."},
	{"id": "fish_10", "fact": "fish", "need": 10, "hidden": true,
			"title": "Petri Heil", "body": "10 Fische auf der Karte gefangen."},
	{"id": "stone_7", "fact": "stone7", "need": 1, "hidden": true,
			"title": "Sieben Hüpfer", "body": "Einen Stein siebenmal über das Wasser der Karte hüpfen lassen."},
	{"id": "volcano_rage", "fact": "volcano_rage", "need": 1, "hidden": true,
			"title": "Unruhestifter", "body": "Einen Vulkan auf der Karte zum Riesenausbruch gereizt."},
	{"id": "torch_out", "fact": "torch_out", "need": 1, "hidden": true,
			"title": "Ausgepustet", "body": "Eine Fackel auf der Karte ausgepustet."},
	{"id": "birds_20", "fact": "birds", "need": 20, "hidden": true,
			"title": "Vogelscheuche", "body": "20 Vogelschwärme auf der Karte aufgescheucht."},
]


## Alle Erfolge in der Reihenfolge der Ansicht: zuerst die Wörter je Sprache aus `languages`.
static func catalog(languages: Array) -> Array:
	var out: Array = []
	for lang: String in languages:
		var language := Lexeme.language_name(lang)
		for i in WORD_STEPS.size():
			out.append({"id": "words_%s_%d" % [lang, WORD_STEPS[i]], "fact": "words_" + lang,
					"need": WORD_STEPS[i], "icon": "words_%d" % WORD_STEPS[i],
					"title": "%s-%s" % [language, WORD_TITLES[i]],
					"body": "%d %s-Vokabeln schon einmal richtig übersetzt." % [WORD_STEPS[i], language]})
	for entry: Dictionary in FIXED:
		out.append(entry.duplicate())
	return out


## Bild eines Erfolgs (`entry` wie in `catalog`) oder eines Namens wie HIDDEN_ICON.
static func icon(entry_or_name: Variant) -> Texture2D:
	var name := str(entry_or_name) if entry_or_name is String \
			else str((entry_or_name as Dictionary).get("icon", entry_or_name.get("id", "")))
	var path := ICON_DIR + name + ".webp"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func find(languages: Array, id: String) -> Dictionary:
	for entry: Dictionary in catalog(languages):
		if str(entry["id"]) == id:
			return entry
	return {}


## Wert eines Fakts. Ein Callable wird erst bei Bedarf gerufen und das Ergebnis behalten:
## Erfolge, die schon freigeschaltet sind, kosten so keine Rechnung.
static func fact(facts: Dictionary, key: String) -> int:
	var value: Variant = facts.get(key, 0)
	if value is Callable:
		value = (value as Callable).call()
		facts[key] = value
	return int(value)


## Stand eines abgeleiteten Erfolgs: [erreicht, nötig], erreicht höchstens `need`. Ein
## Moment-Erfolg hat keinen Stand ([0, 0]).
static func progress(entry: Dictionary, facts: Dictionary) -> Array:
	if bool(entry.get("moment", false)):
		return [0, 0]
	var need := int(entry["need"])
	return [mini(fact(facts, str(entry["fact"])), need), need]


static func reached(entry: Dictionary, facts: Dictionary) -> bool:
	var p := progress(entry, facts)
	return int(p[1]) > 0 and int(p[0]) >= int(p[1])


# --- Fakten -------------------------------------------------------------------

## Längste Folge aufeinanderfolgender Tage in `days` (lokale Tagesindizes, beliebig sortiert).
static func longest_run(days: Array) -> int:
	var sorted := days.duplicate()
	sorted.sort()
	var best := 0
	var run := 0
	var last := -2
	for day: int in sorted:
		if day == last:
			continue
		run = run + 1 if day == last + 1 else 1
		best = maxi(best, run)
		last = day
	return best


## Höchste Stufe einer Unit und, je Buch die schwächste Unit, die beste davon.
## `units` wie FortressTier.unit_tiers.
static func unit_facts(units: Dictionary) -> Dictionary:
	var best_unit := 0
	var weakest := {}
	for key: String in units:
		var unit: Dictionary = units[key]
		var tier := int(unit["tier"])
		var book := str(unit["book"])
		best_unit = maxi(best_unit, tier)
		weakest[book] = mini(int(weakest.get(book, tier)), tier)
	var best_book := 0
	for book: String in weakest:
		best_book = maxi(best_book, int(weakest[book]))
	return {"best_unit_tier": best_unit, "best_book_tier": best_book}


## Bücher, in denen jede Unit aus `units` (wie FortressTier.unit_tiers) mindestens
## `min_wins` Boss-Siege hat. `wins` wie BossRecord.wins.
static func boss_books(units: Dictionary, wins: Dictionary, min_wins: int) -> int:
	var complete := {}
	for key: String in units:
		var book := str((units[key] as Dictionary)["book"])
		complete[book] = bool(complete.get(book, true)) and int(wins.get(key, 0)) >= min_wins
	return complete.values().count(true)


## Units, deren unregelmäßige Verben (`irregular: true`) alle in `mastered` stehen; Units
## ohne solche zählen nicht. `mastered` wie PlayerProgress.mastered_lexemes, das die
## Formaufgaben schon verlangt (ADR 0009).
static func irregular_units(lexemes: Array, mastered: Dictionary) -> int:
	var complete := {}
	for entry: Dictionary in lexemes:
		var key := FortressTier.unit_key(entry)
		if key.is_empty() or not bool(entry.get("irregular", false)) \
				or not PlayerProgress.masterable(entry):
			continue
		complete[key] = bool(complete.get(key, true)) and mastered.has(str(entry.get("id", "")))
	return complete.values().count(true)


## Gelernte Knoten, an denen nichts mehr hängt, ab Stufe 2: ein Ast bis ans Ende.
static func finished_branches(entries: Array, unlocked: PackedStringArray) -> int:
	var required := {}
	for entry: Dictionary in entries:
		for id in entry.get("requires", []):
			required[str(id)] = true
	var n := 0
	for entry: Dictionary in entries:
		var id := str(entry.get("id", ""))
		if str(entry.get("kind", "")) == "skill" and int(entry.get("tier", 0)) >= 2 \
				and not required.has(id) and id in unlocked:
			n += 1
	return n


## Arten der Tages-Plaketten (Badges.DAY_ORDER), die es an mindestens einem Tag gab.
## `tally` wie Badges.tally.
static func badge_kinds(tally: Dictionary) -> int:
	var n := 0
	for id: String in tally:
		if int((tally[id] as Dictionary).get("days", 0)) > 0:
			n += 1
	return n


## Die Sprachen der Bücher im Katalog.
static func languages() -> Array:
	var out: Array = []
	for book in ContentRegistry.all_books():
		var lang := ContentRegistry.book_language(book)
		if not lang.is_empty() and not lang in out:
			out.append(lang)
	out.sort()
	return out


## Die Fakten des aktiven Profils, jeder erst bei Bedarf gerechnet (siehe `fact`).
static func live_facts(languages: Array) -> Dictionary:
	var units := {}
	var unit_stats := func() -> Dictionary:
		if units.is_empty():
			var tiers := FortressTier.unit_tiers(ContentRegistry.lexemes.values(),
					PlayerProgress.mastered_lexemes(), FortressTier.drop_of(SkillBook.bonuses()))
			units.merge(unit_facts(tiers))
			units["units"] = tiers
		return units
	var tally := {}
	var badge_tally := func() -> Dictionary:
		if tally.is_empty():
			tally.merge(Badges.tally(Badges.new(PlayerProgress.player_id).all_days(),
					SessionLog.correct_by_day()))
		return tally
	var facts := {
		"mastered": func() -> int: return PlayerProgress.mastered_lexemes().size(),
		"irregular_units": func() -> int:
			return irregular_units(ContentRegistry.lexemes.values(), PlayerProgress.mastered_lexemes()),
		"best_unit_tier": func() -> int: return int(unit_stats.call()["best_unit_tier"]),
		"best_book_tier": func() -> int: return int(unit_stats.call()["best_book_tier"]),
		"boss_wins": func() -> int: return BossRecord.entries(PlayerProgress.player_id).size(),
		"best_medal": func() -> int:
			var best := 0
			for count: int in BossRecord.wins(PlayerProgress.player_id).values():
				best = maxi(best, BossRecord.medal(count))
			return best,
		"boss_books": func() -> int:
			return boss_books(unit_stats.call()["units"], BossRecord.wins(PlayerProgress.player_id),
					BossRecord.MEDAL_WINS[0]),
		"boss_books_gold": func() -> int:
			return boss_books(unit_stats.call()["units"], BossRecord.wins(PlayerProgress.player_id),
					BossRecord.MEDAL_WINS[-1]),
		"best_streak": func() -> int:
			return longest_run(SessionLog.played_days(0, int(Time.get_unix_time_from_system()))),
		"play_days": func() -> int:
			return SessionLog.played_days(0, int(Time.get_unix_time_from_system())).size(),
		"level": func() -> int: return PlayerLevel.level,
		"chests": func() -> int: return Wallet.chests_opened,
		"skills": func() -> int: return SkillBook.unlocked.size(),
		"branches": func() -> int:
			return finished_branches(ContentRegistry.skills.values(), SkillBook.unlocked),
		"badge_kinds": func() -> int: return badge_kinds(badge_tally.call()),
		"elephant": func() -> int:
			return int((badge_tally.call()["elephant"] as Dictionary)["days"]),
	}
	for lang: String in languages:
		facts["words_" + lang] = func() -> int: return PlayerProgress.lexemes_answered(lang)
	for secret: String in SECRETS:
		facts[secret] = AchievementBook.secret_count(secret)
	return facts
