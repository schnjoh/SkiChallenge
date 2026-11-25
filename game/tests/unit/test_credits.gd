extends GutTest
## credits.json must exist, parse, and contain the mandatory data attributions.


func test_credits_json_has_required_attributions() -> void:
	var text: String = FileAccess.get_file_as_string("res://data/credits.json")
	assert_ne(text, "", "credits.json missing")
	var data: Variant = JSON.parse_string(text)
	assert_typeof(data, TYPE_DICTIONARY)
	assert_string_contains(text, "Land Tirol")
	assert_string_contains(text, "OpenStreetMap")
