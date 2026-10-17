extends Node2D
class_name GameScreen
## Tower defense sahnesi — simülasyon + çizim + dokunmatik HUD, tek dosyada.

var main: Node
var map_id: String = "istanbul"

# ---- iç veri sınıfları ----
class Enemy:
	var type: String
	var name: String
	var hp: float
	var max_hp: float
	var base_speed: float
	var speed: float
	var dist: float = 0.0
	var r: float
	var color: Color
	var gold: int
	var leak: int
	var boss: bool = false
	var slow_t: float = 0.0
	var hit: float = 0.0
	var alive: bool = true
	var pos: Vector2 = Vector2.ZERO

class Tower:
	var tid: String
	var c: int
	var r: int
	var pos: Vector2
	var level: int = 1
	var cd: float = 0.0
	var range_px: float
	var damage: float
	var fire_rate: float
	var splash: float
	var slow: float
	var slow_dur: float
	var invested: int

class Proj:
	var pos: Vector2
	var lpos: Vector2
	var target: Enemy
	var speed: float
	var dmg: float
	var splash: float
	var color: Color
	var kind: String
	var slow: float
	var slow_dur: float
	var dead: bool = false

class Pop:
	var pos: Vector2
	var text: String = ""
	var color: Color
	var t: float
	var ring: float = 0.0

# ---- durum ----
var mapdef: Dictionary
var path_keys: Dictionary = {}
var curve: Curve2D
var path_len: float
var start_marker: Vector2
var end_marker: Vector2

var gold: int
var life: int
var start_life: int
var wave_index: int = 0
var phase: String = "ready"   # ready | wave | won | lost
var enemies: Array = []
var towers: Array = []
var projs: Array = []
var pops: Array = []
var schedule: Array = []
var spawned: int = 0
var wave_clock: float = 0.0

var sel_type: String = ""
var sel_tower: Tower = null
var hover_cell: Vector2i = Vector2i(-99, -99)
var speed: int = 1
var paused: bool = false

var font: Font

# ---- HUD referansları ----
var hud: CanvasLayer
var gold_lbl: Label
var life_lbl: Label
var wave_lbl: Label
var start_btn: Button
var speed_btn: Button
var pause_btn: Button
var sel_row: HBoxContainer
var sel_lbl: Label
var up_btn: Button
var sell_btn: Button
var shop_btns: Dictionary = {}
var overlay: Control
var ov_title: Label
var ov_text: Label
var toast_lbl: Label
var toast_t: float = 0.0

const TILE := Defs.TILE

func _ready() -> void:
	font = ThemeDB.fallback_font
	mapdef = Defs.MAPS[map_id]
	_build_path()
	gold = int(mapdef["start_gold"]) + int(GameData.perks.get("start_gold_bonus", 0))
	start_life = int(mapdef["start_life"]) + int(GameData.perks.get("start_life_bonus", 0))
	life = start_life
	_build_hud()
	_refresh_hud()
	set_process_unhandled_input(true)

# ----------------------------------------------------- yol / harita
func _cell_center(c: int, r: int) -> Vector2:
	return Vector2(c * TILE + TILE / 2.0, r * TILE + TILE / 2.0)

func _build_path() -> void:
	var wps: Array = mapdef["path"]
	var cells: Array = []
	for i in range(wps.size() - 1):
		var a: Vector2i = wps[i]
		var b: Vector2i = wps[i + 1]
		var dc := signi(b.x - a.x)
		var dr := signi(b.y - a.y)
		var cur := a
		while cur != b:
			cells.append(cur)
			if cur.x >= 0 and cur.x < Defs.COLS and cur.y >= 0 and cur.y < Defs.ROWS:
				path_keys[cur] = true
			cur += Vector2i(dc, dr)
	cells.append(wps[wps.size() - 1])
	curve = Curve2D.new()
	for cell in cells:
		curve.add_point(_cell_center(cell.x, cell.y))
	path_len = curve.get_baked_length()
	start_marker = _cell_center(wps[0].x, wps[0].y)
	end_marker = _cell_center(wps[wps.size() - 1].x, wps[wps.size() - 1].y)

func _buildable(c: int, r: int) -> bool:
	if c < 0 or c >= Defs.COLS or r < 1 or r > 14:
		return false
	if path_keys.has(Vector2i(c, r)):
		return false
	for t in towers:
		if t.c == c and t.r == r:
			return false
	return true

func _tower_at(c: int, r: int) -> Tower:
	for t in towers:
		if t.c == c and t.r == r:
			return t
	return null

# ----------------------------------------------------- kule yardımcıları
func _make_tower(tid: String, c: int, r: int) -> Tower:
	var d: Dictionary = Defs.TOWERS[tid]
	var t := Tower.new()
	t.tid = tid; t.c = c; t.r = r; t.pos = _cell_center(c, r)
	t.level = 1; t.invested = int(d["cost"])
	t.splash = float(d["splash"]); t.slow = float(d["slow"]); t.slow_dur = float(d["slow_dur"])
	_apply_level(t)
	return t

func _apply_level(t: Tower) -> void:
	var d: Dictionary = Defs.TOWERS[t.tid]
	var L := t.level - 1
	t.damage = float(d["damage"]) * (1.0 + 0.65 * L) * GameData.damage_mult()
	t.range_px = float(d["range"]) * (1.0 + 0.12 * L)
	t.fire_rate = float(d["fire_rate"]) * (1.0 - 0.06 * L)
	if float(d["splash"]) > 0:
		t.splash = float(d["splash"]) * (1.0 + 0.1 * L)

func _up_cost(t: Tower) -> int:
	return int(round(float(Defs.TOWERS[t.tid]["cost"]) * 0.8 * t.level))

func _sell_val(t: Tower) -> int:
	return int(round(t.invested * 0.6))

# ----------------------------------------------------- simülasyon
func _spawn(type: String) -> void:
	var d: Dictionary = Defs.ENEMIES[type]
	var scale := 1.0 + 0.06 * wave_index
	var e := Enemy.new()
	e.type = type; e.name = d["name"]
	e.max_hp = float(d["hp"]) * scale; e.hp = e.max_hp
	e.base_speed = float(d["speed"]); e.speed = e.base_speed
	e.r = float(d["r"]); e.color = d["color"]
	e.gold = int(d["gold"]); e.leak = int(d["leak"])
	e.boss = bool(d.get("boss", false))
	e.pos = curve.sample_baked(0.0)
	enemies.append(e)

func _pop(p: Vector2, text: String, color: Color) -> void:
	var pop := Pop.new()
	pop.pos = p; pop.text = text; pop.color = color; pop.t = 0.9
	pops.append(pop)

func _ring(p: Vector2, radius: float, color: Color) -> void:
	var pop := Pop.new()
	pop.pos = p; pop.ring = radius; pop.color = color; pop.t = 0.28
	pops.append(pop)

func step(dt: float) -> void:
	if phase != "wave":
		return
	wave_clock += dt
	while spawned < schedule.size() and wave_clock >= schedule[spawned]["t"]:
		_spawn(schedule[spawned]["type"])
		spawned += 1
	# düşmanlar
	for e in enemies:
		if e.slow_t > 0.0:
			e.slow_t -= dt; e.speed = e.base_speed * 0.5
		else:
			e.speed = e.base_speed
		if e.hit > 0.0: e.hit -= dt
		e.dist += e.speed * dt
		if e.dist >= path_len:
			e.alive = false
			life -= e.leak
			_pop(Vector2(360, 150), "-%d sur" % e.leak, Color("d8463a"))
		else:
			e.pos = curve.sample_baked(e.dist)
	# kuleler ateş
	for t in towers:
		t.cd -= dt
		if t.cd > 0.0: continue
		var best: Enemy = null
		var bd := -1.0
		var rr = t.range_px * t.range_px
		for e in enemies:
			if not e.alive: continue
			if e.pos.distance_squared_to(t.pos) <= rr and e.dist > bd:
				best = e; bd = e.dist
		if best:
			t.cd = t.fire_rate
			_fire(t, best)
	# mermiler
	for p in projs:
		if p.dead: continue
		var tx: float; var ty: float
		if p.target and p.target.alive:
			tx = p.target.pos.x; ty = p.target.pos.y
		else:
			tx = p.lpos.x; ty = p.lpos.y
		p.lpos = Vector2(tx, ty)
		var to = Vector2(tx, ty) - p.pos
		var d = to.length()
		if d <= p.speed * dt + 5.0:
			p.pos = Vector2(tx, ty); _impact(p); p.dead = true
		else:
			p.pos += to / d * p.speed * dt
	# ölümler → altın
	for e in enemies:
		if e.alive and e.hp <= 0.0:
			e.alive = false
			gold += e.gold
			_pop(e.pos + Vector2(0, -16), "+%d" % e.gold, Color("e8b64a"))
	enemies = enemies.filter(func(e): return e.alive)
	projs = projs.filter(func(p): return not p.dead)
	for pop in pops:
		pop.t -= dt
		pop.pos.y -= 20.0 * dt
	pops = pops.filter(func(p): return p.t > 0.0)
	# kaybet / dalga tamam
	if life <= 0:
		life = 0; _lose(); return
	if spawned >= schedule.size() and enemies.is_empty():
		var b := Defs.wave_bonus(wave_index + 1)
		gold += b
		_pop(Vector2(360, 640), "Dalga temiz! +%d" % b, Color("e8b64a"))
		wave_index += 1
		if wave_index >= Defs.wave_count():
			_win()
		else:
			phase = "ready"
		_refresh_hud()

func _fire(t: Tower, e: Enemy) -> void:
	var d: Dictionary = Defs.TOWERS[t.tid]
	var p := Proj.new()
	p.pos = t.pos; p.lpos = e.pos; p.target = e
	p.dmg = t.damage; p.splash = t.splash; p.color = d["color"]
	p.kind = d["proj"]; p.slow = t.slow; p.slow_dur = t.slow_dur
	if t.splash > 0:
		p.speed = 360.0 if t.tid == "topcu" else 420.0
	else:
		p.speed = 680.0 if t.tid == "sipahi" else 760.0
	projs.append(p)

func _impact(p: Proj) -> void:
	if p.splash > 0:
		for e in enemies:
			if not e.alive: continue
			if e.pos.distance_to(p.pos) <= p.splash:
				e.hp -= p.dmg; e.hit = 0.12
				if p.slow > 0: e.slow_t = max(e.slow_t, p.slow_dur)
		_ring(p.pos, p.splash, p.color)
	else:
		var e := p.target
		if e and e.alive:
			e.hp -= p.dmg; e.hit = 0.12
			if p.slow > 0: e.slow_t = max(e.slow_t, p.slow_dur)

func _process(delta: float) -> void:
	if not paused and phase == "wave":
		for i in speed:
			if phase != "wave": break
			step(delta)
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t <= 0.0: toast_lbl.visible = false
	_refresh_stats()
	queue_redraw()

# ----------------------------------------------------- çizim
func _draw() -> void:
	# zemin
	for r in Defs.ROWS:
		for c in Defs.COLS:
			var on_path := path_keys.has(Vector2i(c, r))
			var col: Color
			if on_path:
				col = Color.BLACK
			else:
				col = mapdef["ground_b"] if (c + r) % 2 == 1 else mapdef["ground_a"]
			draw_rect(Rect2(c * TILE, r * TILE, TILE, TILE), col, true)
			if not on_path:
				draw_rect(Rect2(c * TILE, r * TILE, TILE, TILE), Color(0.91, 0.71, 0.29, 0.05), false, 1.0)
	# yol
	var pts := curve.get_baked_points()
	draw_polyline(pts, mapdef["road_edge"], TILE * 0.82, true)
	draw_polyline(pts, mapdef["road"], TILE * 0.62, true)
	# giriş / çıkış
	_label(start_marker + Vector2(0, -TILE * 0.4), "⛬ BÜKREŞ", Color("c25b40"), 20)
	_label(end_marker + Vector2(0, TILE * 0.2), "⛬ İSTANBUL", Color("e8b64a"), 22)
	# yerleştirme hayaleti
	if sel_type != "" and hover_cell.x > -50:
		var c := hover_cell.x; var r := hover_cell.y
		var ok := _buildable(c, r)
		var d: Dictionary = Defs.TOWERS[sel_type]
		var ce := _cell_center(c, r)
		draw_circle(ce, float(d["range"]), Color(0.91, 0.71, 0.29, 0.08) if ok else Color(0.85, 0.27, 0.23, 0.12))
		draw_arc(ce, float(d["range"]), 0, TAU, 48, Color(0.91, 0.71, 0.29, 0.4) if ok else Color(0.85, 0.27, 0.23, 0.5), 1.5)
		_draw_tower_glyph(ce, sel_type, 1, 0.65)
	# seçili kule menzili
	if sel_tower:
		draw_circle(sel_tower.pos, sel_tower.range_px, Color(0.91, 0.71, 0.29, 0.07))
		draw_arc(sel_tower.pos, sel_tower.range_px, 0, TAU, 48, Color(0.91, 0.71, 0.29, 0.45), 1.5)
	# kuleler
	for t in towers:
		_draw_tower(t)
	# mermiler
	for p in projs:
		_draw_proj(p)
	# düşmanlar
	for e in enemies:
		_draw_enemy(e)
	# pop / ring
	for pop in pops:
		if pop.ring > 0:
			var a: float = clamp(pop.t / 0.28, 0.0, 1.0)
			draw_arc(pop.pos, pop.ring * (1.0 - pop.t / 0.28), 0, TAU, 32, Color(pop.color.r, pop.color.g, pop.color.b, a), 2.0)
		else:
			var a2: float = clamp(pop.t / 0.9, 0.0, 1.0)
			_label(pop.pos, pop.text, Color(pop.color.r, pop.color.g, pop.color.b, a2), 20)

func _draw_tower(t: Tower) -> void:
	_draw_tower_glyph(t.pos, t.tid, t.level, 1.0)

func _draw_tower_glyph(pos: Vector2, tid: String, level: int, alpha: float) -> void:
	var d: Dictionary = Defs.TOWERS[tid]
	var col: Color = d["color"]
	draw_rect(Rect2(pos.x - 26, pos.y - 26, 52, 52), Color(0.1, 0.07, 0.05, alpha), true)
	draw_rect(Rect2(pos.x - 26, pos.y - 26, 52, 52), Color(0.23, 0.17, 0.11, alpha), false, 2.5)
	draw_circle(pos, 18, Color(col.r, col.g, col.b, alpha))
	_label(pos + Vector2(0, 2), d["glyph"], Color(0.09, 0.05, 0.03, alpha), 26, true)
	if level > 1:
		for i in (level - 1):
			draw_circle(pos + Vector2(-9 + i * 9, -32), 3.2, Color("e8b64a"))

func _draw_enemy(e: Enemy) -> void:
	if e.slow_t > 0.0:
		draw_arc(e.pos, e.r + 4, 0, TAU, 24, Color(0.35, 0.7, 0.9, 0.8), 2.5)
	var body := Color.WHITE if e.hit > 0.0 else e.color
	draw_circle(e.pos, e.r, body)
	draw_arc(e.pos, e.r, 0, TAU, 28, Color(0, 0, 0, 0.5), 2.5)
	if e.boss:
		_label(e.pos + Vector2(0, -e.r - 12), "♛", Color("e8b64a"), 20, true)
	var w := e.r * 2.0
	var hp: float = clampf(e.hp / e.max_hp, 0.0, 1.0)
	draw_rect(Rect2(e.pos.x - w / 2, e.pos.y - e.r - 11, w, 5), Color(0, 0, 0, 0.6), true)
	var hpc := Color("6bbf59") if hp > 0.5 else (Color("e0a53c") if hp > 0.25 else Color("d8463a"))
	draw_rect(Rect2(e.pos.x - w / 2, e.pos.y - e.r - 11, w * hp, 5), hpc, true)

func _draw_proj(p: Proj) -> void:
	match p.kind:
		"arrow":
			var dir := (p.lpos - p.pos)
			if dir.length() > 0.1: dir = dir.normalized()
			draw_line(p.pos, p.pos - dir * 12, Color("e8d08a"), 2.5)
		"cannon":
			draw_circle(p.pos, 6, Color(0.16, 0.11, 0.07))
			draw_arc(p.pos, 6, 0, TAU, 16, p.color, 2.0)
		"magic", "wisp":
			draw_circle(p.pos, 5, p.color)
		_:
			draw_circle(p.pos, 4, Color("fff6d8"))

func _label(pos: Vector2, text: String, color: Color, size: int, center := true) -> void:
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var at := pos
	if center:
		at = Vector2(pos.x - sz.x / 2, pos.y + sz.y * 0.32)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

# ----------------------------------------------------- girdi
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var m := get_global_mouse_position()
		hover_cell = Vector2i(int(m.x / TILE), int(m.y / TILE))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if phase == "won" or phase == "lost":
			return
		var m := get_global_mouse_position()
		var c := int(m.x / TILE); var r := int(m.y / TILE)
		if c < 0 or c >= Defs.COLS or r < 0 or r >= Defs.ROWS:
			return
		var existing := _tower_at(c, r)
		if sel_type != "":
			if existing:
				sel_tower = existing; sel_type = ""
			elif _buildable(c, r):
				var d: Dictionary = Defs.TOWERS[sel_type]
				if gold >= int(d["cost"]):
					gold -= int(d["cost"])
					towers.append(_make_tower(sel_type, c, r))
				else:
					_toast("Yeterli altın yok!")
		else:
			sel_tower = existing
		_refresh_hud()

# ----------------------------------------------------- HUD
func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	# üst bar
	var top := _panel(Color(0.12, 0.06, 0.08, 0.92))
	top.anchor_right = 1.0
	top.offset_bottom = 96
	hud.add_child(top)
	var th := HBoxContainer.new()
	th.set_anchors_preset(Control.PRESET_FULL_RECT)
	th.alignment = BoxContainer.ALIGNMENT_CENTER
	th.add_theme_constant_override("separation", 26)
	top.add_child(th)
	gold_lbl = _stat_label(th, "Altın", Color("e8b64a"))
	life_lbl = _stat_label(th, "Surlar", Color("c6362b"))
	wave_lbl = _stat_label(th, "Dalga", Color("f4e6cc"))

	# alt alan
	var bottom := VBoxContainer.new()
	bottom.anchor_left = 0; bottom.anchor_right = 1; bottom.anchor_top = 1; bottom.anchor_bottom = 1
	bottom.offset_left = 10; bottom.offset_right = -10; bottom.offset_top = -244; bottom.offset_bottom = -10
	bottom.add_theme_constant_override("separation", 8)
	hud.add_child(bottom)

	# seçili kule satırı
	sel_row = HBoxContainer.new()
	sel_row.add_theme_constant_override("separation", 8)
	sel_row.visible = false
	bottom.add_child(sel_row)
	sel_lbl = Label.new()
	sel_lbl.add_theme_font_size_override("font_size", 18)
	sel_lbl.add_theme_color_override("font_color", Color("f4e6cc"))
	sel_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_row.add_child(sel_lbl)
	up_btn = _mk_button("Yükselt", Color("d79b2b"), Color("1a0d08"))
	up_btn.pressed.connect(_on_upgrade)
	sel_row.add_child(up_btn)
	sell_btn = _mk_button("Sat", Color("4a4a54"), Color.WHITE)
	sell_btn.pressed.connect(_on_sell)
	sel_row.add_child(sell_btn)

	# kontrol satırı
	var ctrl := HBoxContainer.new()
	ctrl.add_theme_constant_override("separation", 8)
	bottom.add_child(ctrl)
	start_btn = _mk_button("Dalgayı Başlat", Color("c0362b"), Color.WHITE)
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.pressed.connect(_on_start)
	ctrl.add_child(start_btn)
	speed_btn = _mk_button("1×", Color("2a1620"), Color("f4e6cc"))
	speed_btn.custom_minimum_size = Vector2(72, 0)
	speed_btn.pressed.connect(_on_speed)
	ctrl.add_child(speed_btn)
	pause_btn = _mk_button("⏸", Color("2a1620"), Color("f4e6cc"))
	pause_btn.custom_minimum_size = Vector2(72, 0)
	pause_btn.pressed.connect(_on_pause)
	ctrl.add_child(pause_btn)

	# dükkân satırı
	var shop := HBoxContainer.new()
	shop.add_theme_constant_override("separation", 7)
	bottom.add_child(shop)
	for tid in Defs.SHOP_ORDER:
		if not GameData.unlocked.has(tid): continue
		var d: Dictionary = Defs.TOWERS[tid]
		var b := _mk_button("%s\n✦%d" % [d["name"], d["cost"]], Color("241320"), Color("f4e6cc"))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 62)
		b.add_theme_font_size_override("font_size", 16)
		var tid_local = tid
		b.pressed.connect(func(): _on_shop(tid_local))
		shop.add_child(b)
		shop_btns[tid] = b

	# toast
	toast_lbl = Label.new()
	toast_lbl.anchor_left = 0.5; toast_lbl.anchor_right = 0.5; toast_lbl.anchor_top = 0.0
	toast_lbl.offset_top = 108
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.add_theme_font_size_override("font_size", 20)
	toast_lbl.add_theme_color_override("font_color", Color("f4e6cc"))
	toast_lbl.visible = false
	hud.add_child(toast_lbl)

	# overlay (kazan/kaybet)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	hud.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.03, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var ov := VBoxContainer.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.alignment = BoxContainer.ALIGNMENT_CENTER
	ov.add_theme_constant_override("separation", 20)
	overlay.add_child(ov)
	ov_title = Label.new()
	ov_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov_title.add_theme_font_size_override("font_size", 46)
	ov.add_child(ov_title)
	ov_text = Label.new()
	ov_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ov_text.custom_minimum_size = Vector2(560, 0)
	ov_text.add_theme_font_size_override("font_size", 22)
	ov_text.add_theme_color_override("font_color", Color("c3a488"))
	ov.add_child(ov_text)
	var again := _mk_button("Yeniden Sefere Çık", Color("c0362b"), Color.WHITE)
	again.pressed.connect(func(): main.goto_game(map_id))
	ov.add_child(again)
	var menu := _mk_button("Ana Menü", Color("2a1620"), Color("f4e6cc"))
	menu.pressed.connect(func(): main.goto_menu())
	ov.add_child(menu)

func _panel(col: Color) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	p.add_theme_stylebox_override("panel", sb)
	return p

func _stat_label(parent: Node, key: String, col: Color) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	parent.add_child(box)
	var k := Label.new()
	k.text = key
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.add_theme_font_size_override("font_size", 13)
	k.add_theme_color_override("font_color", Color("8a6c5c"))
	box.add_child(k)
	var v := Label.new()
	v.text = "0"
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_theme_font_size_override("font_size", 30)
	v.add_theme_color_override("font_color", col)
	box.add_child(v)
	return v

func _mk_button(text: String, bg: Color, fg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 19)
	b.custom_minimum_size = Vector2(0, 54)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(11)
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate(); sh.bg_color = bg.lightened(0.12)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	return b

func _toast(msg: String) -> void:
	toast_lbl.text = msg
	toast_lbl.visible = true
	toast_t = 1.4

# ---- HUD olayları
func _on_shop(tid: String) -> void:
	sel_type = "" if sel_type == tid else tid
	sel_tower = null
	_refresh_hud()

func _on_start() -> void:
	if phase != "ready" or wave_index >= Defs.wave_count(): return
	schedule = Defs.build_schedule(wave_index)
	spawned = 0; wave_clock = 0.0; phase = "wave"
	_refresh_hud()

func _on_speed() -> void:
	speed = 2 if speed == 1 else 1
	speed_btn.text = "%d×" % speed

func _on_pause() -> void:
	paused = not paused
	pause_btn.text = "▶" if paused else "⏸"

func _on_upgrade() -> void:
	if not sel_tower or sel_tower.level >= 3: return
	var cost := _up_cost(sel_tower)
	if gold >= cost:
		gold -= cost; sel_tower.invested += cost
		sel_tower.level += 1; _apply_level(sel_tower)
		_refresh_hud()
	else:
		_toast("Yeterli altın yok!")

func _on_sell() -> void:
	if not sel_tower: return
	gold += _sell_val(sel_tower)
	towers.erase(sel_tower)
	sel_tower = null
	_refresh_hud()

# ---- HUD yenileme
func _refresh_stats() -> void:
	gold_lbl.text = str(gold)
	life_lbl.text = str(life)
	wave_lbl.text = "%d/%d" % [wave_index, Defs.wave_count()]
	var in_wave := phase == "wave"
	start_btn.disabled = in_wave or phase == "won" or phase == "lost"
	if phase == "won": start_btn.text = "Zafer!"
	elif phase == "lost": start_btn.text = "Mağlup"
	elif in_wave: start_btn.text = "Dalga Sürüyor…"
	else: start_btn.text = "Dalgayı Başlat ▸ %d" % (wave_index + 1)

func _refresh_hud() -> void:
	_refresh_stats()
	# dükkân seçili vurgusu
	for tid in shop_btns:
		var b: Button = shop_btns[tid]
		var selected = tid == sel_type
		var affordable = gold >= int(Defs.TOWERS[tid]["cost"])
		var sb: StyleBoxFlat = b.get_theme_stylebox("normal")
		sb.border_width_left = 2 if selected else 0
		sb.border_width_right = 2 if selected else 0
		sb.border_width_top = 2 if selected else 0
		sb.border_width_bottom = 2 if selected else 0
		sb.border_color = Color("e8b64a")
		b.modulate = Color(1,1,1,1) if affordable else Color(0.55,0.55,0.55,1)
	# seçili kule paneli
	if sel_tower:
		sel_row.visible = true
		var d: Dictionary = Defs.TOWERS[sel_tower.tid]
		sel_lbl.text = "%s  Sv.%d  •  Hasar %d  •  Menzil %d" % [d["name"], sel_tower.level, int(sel_tower.damage), int(sel_tower.range_px)]
		if sel_tower.level >= 3:
			up_btn.text = "Azami"; up_btn.disabled = true
		else:
			up_btn.text = "Yükselt ✦%d" % _up_cost(sel_tower); up_btn.disabled = false
		sell_btn.text = "Sat ✦%d" % _sell_val(sel_tower)
	else:
		sel_row.visible = false

# ---- bitiş
func _stars() -> int:
	if life >= start_life: return 3
	if life >= int(start_life * 0.6): return 2
	return 1

func _win() -> void:
	phase = "won"
	var stars := _stars()
	var earned := 50 + gold / 2
	GameData.record_result(map_id, stars, earned)
	overlay.visible = true
	ov_title.text = "İSTANBUL AYAKTA"
	ov_title.add_theme_color_override("font_color", Color("e8b64a"))
	ov_text.text = "Vlad Dracul kırıldı! %s  •  +✦%d hazine kazandın, gazi." % ["★".repeat(stars) + "☆".repeat(3 - stars), earned]
	_refresh_stats()

func _lose() -> void:
	phase = "lost"
	overlay.visible = true
	ov_title.text = "SURLAR DÜŞTÜ"
	ov_title.add_theme_color_override("font_color", Color("c6362b"))
	ov_text.text = "Düşman İstanbul kapılarını aştı. Toparlan ve hattı yeniden kur."
	_refresh_stats()
