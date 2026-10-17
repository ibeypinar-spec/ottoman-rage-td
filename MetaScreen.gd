extends Control
class_name MetaScreen
## OCAK — seferler arası kalıcı hazineyle yükseltme satın alma ekranı.

var main: Node
var meta_lbl: Label
var list: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("140a10")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	v.offset_left = 20; v.offset_right = -20
	add_child(v)

	var title := Label.new()
	title.text = "OCAK · HAZİNE DİVANI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("e8b64a"))
	v.add_child(title)

	meta_lbl = Label.new()
	meta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta_lbl.add_theme_font_size_override("font_size", 22)
	meta_lbl.add_theme_color_override("font_color", Color("f4e6cc"))
	v.add_child(meta_lbl)

	var hint := Label.new()
	hint.text = "Sefer kazandıkça hazine birikir — kalıcı güç satın al."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("8a6c5c"))
	v.add_child(hint)

	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 9)
	v.add_child(list)

	var back := Button.new()
	back.text = "Ana Menü"
	back.custom_minimum_size = Vector2(360, 52)
	back.add_theme_font_size_override("font_size", 22)
	var bsb := StyleBoxFlat.new(); bsb.bg_color = Color("2a1620"); bsb.set_corner_radius_all(12)
	bsb.content_margin_top = 10; bsb.content_margin_bottom = 10
	back.add_theme_stylebox_override("normal", bsb)
	back.add_theme_color_override("font_color", Color("f4e6cc"))
	back.pressed.connect(func(): main.goto_menu())
	v.add_child(back)

	_rebuild()

func _rebuild() -> void:
	meta_lbl.text = "Hazine: ✦%d" % GameData.meta_gold
	for ch in list.get_children():
		ch.queue_free()
	for key in Defs.PERK_ORDER:
		list.add_child(_perk_row(key))

func _perk_row(key: String) -> Control:
	var cat: Dictionary = Defs.PERKS[key]
	var lvl: int = GameData.perk_level(key)
	var maxl: int = int(cat["max"])
	var cost: int = GameData.perk_cost(key)

	var panel := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color("1f1119"); psb.set_corner_radius_all(12)
	psb.content_margin_left = 14; psb.content_margin_right = 14
	psb.content_margin_top = 10; psb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", psb)
	panel.custom_minimum_size = Vector2(0, 86)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var nm := Label.new()
	nm.text = "%s  %s   Lv.%d/%d" % [cat["icon"], cat["name"], lvl, maxl]
	nm.add_theme_font_size_override("font_size", 19)
	nm.add_theme_color_override("font_color", Color("f4e6cc"))
	info.add_child(nm)

	var ds := Label.new()
	ds.text = "%s  (%s)" % [cat["desc"], cat["unit"]]
	ds.add_theme_font_size_override("font_size", 13)
	ds.add_theme_color_override("font_color", Color("c3a488"))
	info.add_child(ds)

	var pips := Label.new()
	pips.text = "◆".repeat(lvl) + "◇".repeat(maxl - lvl)
	pips.add_theme_font_size_override("font_size", 16)
	pips.add_theme_color_override("font_color", Color("e8b64a"))
	info.add_child(pips)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(118, 58)
	buy.add_theme_font_size_override("font_size", 19)
	var affordable := cost >= 0 and GameData.meta_gold >= cost
	var bg := Color("d79b2b") if affordable else Color("3a3038")
	if cost < 0:
		buy.text = "AZAMİ"; buy.disabled = true; bg = Color("2f3a2f")
	else:
		buy.text = "✦%d" % cost; buy.disabled = not affordable
	var sb := StyleBoxFlat.new(); sb.bg_color = bg; sb.set_corner_radius_all(10)
	buy.add_theme_stylebox_override("normal", sb)
	buy.add_theme_stylebox_override("disabled", sb)
	var sh := sb.duplicate(); sh.bg_color = bg.lightened(0.12)
	buy.add_theme_stylebox_override("hover", sh)
	buy.add_theme_stylebox_override("pressed", sh)
	buy.add_theme_color_override("font_color", Color("1a0d08") if affordable else Color("8a7a70"))
	buy.add_theme_color_override("font_disabled_color", Color("8a7a70"))
	var k = key
	buy.pressed.connect(func():
		if GameData.buy_perk(k):
			_rebuild())
	row.add_child(buy)
	return panel
