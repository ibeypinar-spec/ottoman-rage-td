extends Control
class_name MainMenu
## Ana menü — kodla kurulan arayüz.

var main: Node

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# arka plan
	var bg := ColorRect.new()
	bg.color = Color("140a10")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# konsept görsel arka plan + koyu katman
	var tex := load("res://sprites/menu_bg.jpg")
	if tex:
		var art := TextureRect.new()
		art.texture = tex
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.modulate = Color(1, 1, 1, 0.5)
		add_child(art)
		var ov := ColorRect.new()
		ov.color = Color(0.08, 0.04, 0.06, 0.66)
		ov.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(ov)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 18)
	add_child(center)

	var crest := Label.new()
	crest.text = "☾"
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest.add_theme_font_size_override("font_size", 86)
	crest.add_theme_color_override("font_color", Color("e8b64a"))
	center.add_child(crest)

	var title := Label.new()
	title.text = "OTTOMAN RAGE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("f4e6cc"))
	center.add_child(title)

	var sub := Label.new()
	sub.text = "K U Ş A T M A"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color("c6362b"))
	center.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	center.add_child(spacer)

	var play := _button("SEFERE BAŞLA", Color("c0362b"), Color.WHITE)
	play.pressed.connect(func(): main.goto_mapselect())
	center.add_child(play)

	var ocak := _button("OCAK · YÜKSELTMELER", Color("2a1620"), Color("e8b64a"))
	ocak.pressed.connect(func(): main.goto_meta())
	center.add_child(ocak)

	var stars := GameData.map_stars("istanbul")
	var info := Label.new()
	info.text = "Hazine: ✦%d    İstanbul Yolu: %s" % [GameData.meta_gold, "★".repeat(stars) + "☆".repeat(3 - stars)]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 20)
	info.add_theme_color_override("font_color", Color("c3a488"))
	center.add_child(info)

func _button(text: String, bg: Color, fg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 64)
	b.add_theme_font_size_override("font_size", 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 20; sb.content_margin_right = 20
	sb.content_margin_top = 12; sb.content_margin_bottom = 12
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate(); sh.bg_color = bg.lightened(0.12)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	return b
