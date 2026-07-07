class_name WordTypePalette
extends RefCounted
## Ordnet jeder Wortart (Lexem-Feld "type") eine gut unterscheidbare Outline-Farbe zu.
## Die Farbe kodiert die Wortart eines Monsters (siehe monster_outline.gdshader), damit
## z. B. Nomen/Verben/Adjektive auch bei mehrdeutigen Vokabeln optisch trennbar sind.
## Bewusst isolierte Klasse: testbar und später für eine UI-Legende wiederverwendbar.

const COLORS := {
	"noun":       Color(0.23, 0.51, 0.96),  # Blau
	"verb":       Color(0.94, 0.27, 0.27),  # Rot
	"adjective":  Color(0.13, 0.77, 0.37),  # Grün
	"adverb":     Color(0.66, 0.33, 0.97),  # Violett
	"phrase":     Color(0.97, 0.52, 0.09),  # Orange
	"connector":  Color(0.96, 0.82, 0.18),  # Gelb (deutlich getrennt von Nomen-Blau)
	"expression": Color(0.93, 0.28, 0.60),  # Magenta
}
const FALLBACK := Color(0.8, 0.8, 0.8)      # Grau: unbekannte/leere Wortart

## Deutsche Anzeigenamen je Wortart für die UI-Legende. Reihenfolge = Anzeigereihenfolge.
const LABELS := {
	"noun":       "Nomen",
	"verb":       "Verb",
	"adjective":  "Adjektiv",
	"adverb":     "Adverb",
	"phrase":     "Phrase",
	"connector":  "Bindewort",
	"expression": "Ausdruck",
}


static func color_for(lexeme_type: String) -> Color:
	return COLORS.get(lexeme_type, FALLBACK)
