extends GdUnitTestSuite
## Der Nutzerteil muss genau die Form haben, die in der Werkstatt gemessen wurde
## (`prompt-eval`, `summary-v3/user.txt`): Tags in dieser Reihenfolge, je Kernpunkt eine
## Zeile `- kp1 (required): …`.

const TASK := {
	"title": "The Lighthouse Cat",
	"author": "Mara Linden",
	"genre": "short story",
	"text": "Every evening, old Tom climbed the steps.\n\nOne night the lamp did not work.",
	"key_points": [
		{"id": "kp1", "text": "Tom looks after a lighthouse.", "required": true},
		{"id": "kp2", "text": "The cat helps.", "required": false},
	],
}


func test_the_user_part_has_the_measured_form() -> void:
	var user := WritingPrompts.summary_user(TASK, "  Tom looks after a lighthouse.  ")
	assert_str(user).is_equal("\n".join([
		"<source>",
		"Title: The Lighthouse Cat",
		"Author: Mara Linden",
		"Genre: short story",
		"",
		"Every evening, old Tom climbed the steps.\n\nOne night the lamp did not work.",
		"</source>",
		"",
		"<key_points>",
		"- kp1 (required): Tom looks after a lighthouse.",
		"- kp2 (optional): The cat helps.",
		"</key_points>",
		"",
		"<summary>",
		"Tom looks after a lighthouse.",
		"</summary>",
	]))


func test_the_system_prompt_forbids_giving_the_solution() -> void:
	assert_str(WritingPrompts.SUMMARY_SYSTEM).contains("A hint never gives the solution.")
