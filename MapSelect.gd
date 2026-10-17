extends Control
class_name MapSelect
## Sefer/harita seçim ekranı — kampanya ilerlemesiyle açılır.

var main: Node

const BIOME_COL := {
	"Şehir": Color("8a4a3a"), "Orman": Color("2f6b3a"),
	"Bataklık": Color("3a5a4a"), "Step": Color("8a7a3a"),
}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("140a10")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var tex := load("res://sprites/menu_bg.jpg")
	if tex:
		var art := TextureRect.new()
		art.texture = tex
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.modulate = Color(1, 1, 1, 0.35)
		add_child(art)
		var ov := ColorRect.new()
		ov.color = Color(0.08, 0.04, 0.06, 0.72)
		ov.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(ov)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	v.offset_left = 24; v.offset_right = -24
	add_child(v)

	var title := Label.new()
	title.text = "SEFER HARİTASI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("e8b64a"))
	v.add_child(title)

	var hz := Label.new()
	hz.text = "Hazine: ✦%d" % GameData.meta_gold
	hz.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hz.add_theme_font_size_override("font_size", 18)
	hz.add_theme_color_override("font_color", Color("c3a488"))
	v.add_child(hz)

	var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 10)
	v.add_child(sp)

	for map_id in Defs.CAMPAIGN:
		v.add_child(_map_card(map_id))

	var sp2 := Control.new(); sp2.custom_minimum_size = Vector2(0, 10)
	v.add_child(sp2)
	var back := _button("Ana Menü", Color("2a1620"), Color("f4e6cc"))
	back.pressed.connect(func(): main.goto_menu())
	v.add_child(back)

func _map_card(map_id: String) -> Button:
	var d: Dictionary = Defs.MAPS[map_id]
	var unlocked: bool = GameData.is_map_unlocked(map_id)
	var stars: int = GameData.map_stars(map_id)
	var biome: String = d["biome"]
	var col: Color = BIOME_COL.get(biome, Color("5a3a2a"))
	var b := Button.new()
	b.custom_minimum_size = Vector2(380, 78)
	b.add_theme_font_size_override("font_size", 22)
	if unlocked:
		var star_txt := "★".repeat(stars) + "☆".repeat(3 - stars)
		b.text = "%s\n%s  ·  %s" % [d["name"], biome, star_txt]
	else:
		b.text = "🔒 %s\n%s  ·  Önceki seferi tamamla" % [d["name"], biome]
	var bgc := col if unlocked else Color("2a2228")
	var sb := StyleBoxFlat.new()
	sb.bg_color = bgc; sb.set_corner_radius_all(14)
	sb.content_margin_left = 18; sb.content_margin_right = 18
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	sb.border_width_left = 3; sb.border_color = Color("e8b64a") if (unlocked and stars == 0) else col.lightened(0.2)
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate(); sh.bg_color = bgc.lightened(0.1)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_stylebox_override("disabled", sb)
	b.add_theme_color_override("font_color", Color("f4e6cc") if unlocked else Color("8a7a70"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("6a5a50"))
	b.disabled = not unlocked
	if unlocked:
		var mid = map_id
		b.pressed.connect(func(): main.goto_game(mid))
	return b

func _button(text: String, bg: Color, fg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 54)
	b.add_theme_font_size_override("font_size", 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg; sb.set_corner_radius_all(12)
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate(); sh.bg_color = bg.lightened(0.12)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	return b
