extends Node2D
class_name GameScreen
## Tower defense sahnesi — simülasyon + çizim + dokunmatik HUD, tek dosyada.
## Dallanan yükseltme ağacı, durum etkileri (zehir/yavaşlat/sersemlet), Ozan aura'sı.

var main: Node
var map_id: String = "istanbul"

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
	var slow_factor: float = 1.0
	var poison_t: float = 0.0
	var poison_dps: float = 0.0
	var stun_t: float = 0.0
	var hit: float = 0.0
	var alive: bool = true
	var pos: Vector2 = Vector2.ZERO
	var armor: float = 0.0
	var flying: bool = false
	var regen: float = 0.0
	var last_dmg_t: float = 99.0
	var ph1: bool = false
	var ph2: bool = false

class Tower:
	var tid: String
	var c: int
	var r: int
	var pos: Vector2
	var level: int = 1
	var branch: String = ""
	var cd: float = 0.0
	var range_px: float
	var damage: float
	var fire_rate: float
	var splash: float
	var slow: float
	var slow_dur: float
	var poison_dps: float = 0.0
	var poison_dur: float = 0.0
	var stun_dur: float = 0.0
	var multishot: int = 1
	var is_support: bool = false
	var aura_dmg: float = 0.0
	var aura_fr: float = 0.0
	var ramp: float = 0.0
	var ramp_stacks: float = 0.0
	var idle: float = 0.0
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
	var poison_dps: float
	var poison_dur: float
	var stun_dur: float
	var air: bool = true
	var dead: bool = false

class Pop:
	var pos: Vector2
	var text: String = ""
	var color: Color
	var t: float
	var ring: float = 0.0

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
var phase: String = "ready"
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

var sel_spell: String = ""
var spell_cd: Dictionary = {"okyagmuru": 0.0, "don": 0.0}
var mouse_pos: Vector2 = Vector2.ZERO
var spell_btns: Dictionary = {}
var decor_seed: int = 0

const SPELLS := {
	"okyagmuru": {"name":"Ok Yağmuru","icon":"☄","cd":18.0,"radius":120.0,"dmg":75.0,"targeted":true},
	"don":       {"name":"Don Büyüsü","icon":"❄","cd":28.0,"freeze":2.5,"targeted":false},
}

var hud: CanvasLayer
var gold_lbl: Label
var life_lbl: Label
var wave_lbl: Label
var start_btn: Button
var speed_btn: Button
var pause_btn: Button
var sel_box: VBoxContainer
var sel_lbl: Label
var sel_desc: Label
var up1_btn: Button
var up2_btn: Button
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
	decor_seed = abs(hash(map_id))
	_build_path()
	gold = int(mapdef["start_gold"]) + int(GameData.perks.get("start_gold_bonus", 0))
	start_life = int(mapdef["start_life"]) + int(GameData.perks.get("start_life_bonus", 0))
	life = start_life
	_build_hud()
	_refresh_hud()
	set_process_unhandled_input(true)

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

# ------------------------------------------------- kule stat hesaplama
func _make_tower(tid: String, c: int, r: int) -> Tower:
	var t := Tower.new()
	t.tid = tid; t.c = c; t.r = r; t.pos = _cell_center(c, r)
	t.level = 1; t.branch = ""; t.invested = int(Defs.TOWERS[tid]["cost"])
	_recalc(t)
	return t

func _recalc(t: Tower) -> void:
	var d: Dictionary = Defs.TOWERS[t.tid]
	t.damage = float(d["damage"]); t.range_px = float(d["range"]); t.fire_rate = float(d["fire_rate"])
	t.splash = float(d["splash"]); t.slow = float(d["slow"]); t.slow_dur = float(d["slow_dur"])
	t.poison_dps = 0.0; t.poison_dur = 0.0; t.stun_dur = 0.0; t.multishot = 1; t.ramp = 0.0
	t.is_support = bool(d.get("support", false))
	t.aura_dmg = float(d.get("aura_dmg", 0.0)); t.aura_fr = float(d.get("aura_fr", 0.0))
	if t.branch != "" and t.level >= 2:
		var tier: Dictionary = d["branches"][t.branch]["t2" if t.level >= 3 else "t1"]
		if tier.has("damage"): t.damage *= float(tier["damage"])
		if tier.has("range"): t.range_px *= float(tier["range"])
		if tier.has("fire_rate"): t.fire_rate *= float(tier["fire_rate"])
		if tier.has("splash"): t.splash *= float(tier["splash"])
		if tier.has("splash_abs"): t.splash = float(tier["splash_abs"])
		if tier.has("slow"): t.slow = float(tier["slow"])
		if tier.has("slow_dur"): t.slow_dur = float(tier["slow_dur"])
		if tier.has("poison_dps"): t.poison_dps = float(tier["poison_dps"])
		if tier.has("poison_dur"): t.poison_dur = float(tier["poison_dur"])
		if tier.has("stun_dur"): t.stun_dur = float(tier["stun_dur"])
		if tier.has("multishot"): t.multishot = int(tier["multishot"])
		if tier.has("ramp"): t.ramp = float(tier["ramp"])
		if tier.has("aura_dmg"): t.aura_dmg = float(tier["aura_dmg"])
		if tier.has("aura_fr"): t.aura_fr = float(tier["aura_fr"])
	t.damage *= GameData.damage_mult()

func _branch_keys(tid: String) -> Array:
	return Defs.TOWERS[tid]["branches"].keys()

func _up_cost(t: Tower, slot: int) -> int:
	var d: Dictionary = Defs.TOWERS[t.tid]
	if t.level == 1:
		var br: String = _branch_keys(t.tid)[slot]
		return int(d["branches"][br]["t1"]["cost"])
	elif t.level == 2:
		return int(d["branches"][t.branch]["t2"]["cost"])
	return 0

func _sell_val(t: Tower) -> int:
	return int(round(t.invested * 0.6))

# ------------------------------------------------- simülasyon
func _make_enemy(type: String) -> Enemy:
	var d: Dictionary = Defs.ENEMIES[type]
	var scale := (1.0 + 0.06 * wave_index) * float(mapdef.get("diff", 1.0))
	var e := Enemy.new()
	e.type = type; e.name = d["name"]
	e.max_hp = float(d["hp"]) * scale; e.hp = e.max_hp
	e.base_speed = float(d["speed"]); e.speed = e.base_speed
	e.r = float(d["r"]); e.color = d["color"]
	e.gold = int(d["gold"]); e.leak = int(d["leak"])
	e.boss = bool(d.get("boss", false))
	e.armor = float(d.get("armor", 0.0))
	e.flying = bool(d.get("flying", false))
	e.regen = float(d.get("regen", 0.0))
	e.last_dmg_t = 99.0
	e.pos = curve.sample_baked(0.0)
	return e

func _spawn(type: String) -> void:
	enemies.append(_make_enemy(type))

func _summon(into: Array, boss: Enemy, n: int) -> void:
	for i in n:
		var e := _make_enemy("yarasa")
		e.dist = max(0.0, boss.dist - 20.0 - i * 8.0)
		e.pos = curve.sample_baked(e.dist)
		into.append(e)

func _pop(p: Vector2, text: String, color: Color) -> void:
	var pop := Pop.new(); pop.pos = p; pop.text = text; pop.color = color; pop.t = 0.9
	pops.append(pop)

func _ring(p: Vector2, radius: float, color: Color) -> void:
	var pop := Pop.new(); pop.pos = p; pop.ring = radius; pop.color = color; pop.t = 0.28
	pops.append(pop)

func step(dt: float) -> void:
	if phase != "wave":
		return
	wave_clock += dt
	while spawned < schedule.size() and wave_clock >= schedule[spawned]["t"]:
		_spawn(schedule[spawned]["type"]); spawned += 1
	# düşmanlar + durum etkileri
	var summons: Array = []
	for e in enemies:
		e.last_dmg_t += dt
		if e.stun_t > 0.0:
			e.stun_t -= dt; e.speed = 0.0
		elif e.slow_t > 0.0:
			e.slow_t -= dt; e.speed = e.base_speed * e.slow_factor
			if e.slow_t <= 0.0: e.slow_factor = 1.0
		else:
			e.speed = e.base_speed
		if e.poison_t > 0.0:
			e.poison_t -= dt; e.hp -= e.poison_dps * dt; e.last_dmg_t = 0.0
			if e.poison_t <= 0.0: e.poison_dps = 0.0
		if e.regen > 0.0 and e.last_dmg_t > 2.0 and e.hp < e.max_hp:
			e.hp = min(e.max_hp, e.hp + e.regen * dt)
		if e.type == "vlad" and e.alive:
			if not e.ph1 and e.hp <= e.max_hp * 0.66:
				e.ph1 = true; e.base_speed *= 1.3; _summon(summons, e, 4)
				_pop(e.pos + Vector2(0, -36), "Yarasa Sürüsü!", Color("caa6e2"))
			if not e.ph2 and e.hp <= e.max_hp * 0.33:
				e.ph2 = true; e.base_speed *= 1.3; _summon(summons, e, 6)
				_pop(e.pos + Vector2(0, -36), "Kan Çağrısı!", Color("c6362b"))
		if e.hit > 0.0: e.hit -= dt
		e.dist += e.speed * dt
		if e.dist >= path_len:
			e.alive = false; life -= e.leak
			_pop(Vector2(360, 150), "-%d sur" % e.leak, Color("d8463a"))
		else:
			e.pos = curve.sample_baked(e.dist)
	if not summons.is_empty():
		enemies.append_array(summons)
	# destek aura kuleleri topla
	var supports: Array = []
	for t in towers:
		if t.is_support:
			supports.append(t)
	# kuleler ateş
	for t in towers:
		if t.is_support:
			continue
		t.cd -= dt
		t.idle += dt
		# öfke yığını sönümlemesi
		if t.ramp > 0.0 and t.idle > 1.5 and t.ramp_stacks > 0.0:
			t.ramp_stacks = max(0.0, t.ramp_stacks - dt * 2.0)
		if t.cd > 0.0:
			continue
		# aura katkıları
		var adm := 0.0; var afr := 0.0
		for s in supports:
			if t.pos.distance_to(s.pos) <= s.range_px:
				adm += s.aura_dmg; afr += s.aura_fr
		# menzildeki hedefler (ilerleyene göre sıralı)
		var in_range: Array = []
		var rr = t.range_px * t.range_px
		var tair = Defs.TOWERS[t.tid].get("air", true)
		for e in enemies:
			if not e.alive: continue
			if e.flying and not tair: continue
			if e.pos.distance_squared_to(t.pos) <= rr:
				in_range.append(e)
		if in_range.is_empty():
			continue
		in_range.sort_custom(func(a, b): return a.dist > b.dist)
		t.cd = t.fire_rate / (1.0 + afr)
		t.idle = 0.0
		if t.ramp > 0.0:
			t.ramp_stacks = min(8.0, t.ramp_stacks + 1.0)
		var eff_dmg = t.damage * (1.0 + t.ramp * t.ramp_stacks) * (1.0 + adm)
		var n: int = min(t.multishot, in_range.size())
		for i in n:
			_fire_at(t, in_range[i], eff_dmg)
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
			e.alive = false; gold += e.gold
			_pop(e.pos + Vector2(0, -16), "+%d" % e.gold, Color("e8b64a"))
	enemies = enemies.filter(func(e): return e.alive)
	projs = projs.filter(func(p): return not p.dead)
	for pop in pops:
		pop.t -= dt; pop.pos.y -= 20.0 * dt
	pops = pops.filter(func(p): return p.t > 0.0)
	# kaybet / dalga tamam
	if life <= 0:
		life = 0; _lose(); return
	if spawned >= schedule.size() and enemies.is_empty():
		var b := Defs.wave_bonus(wave_index + 1)
		gold += b
		_pop(Vector2(360, 640), "Dalga temiz! +%d" % b, Color("e8b64a"))
		wave_index += 1
		if wave_index >= Defs.wave_count(): _win()
		else: phase = "ready"
		_refresh_hud()

func _fire_at(t: Tower, e: Enemy, dmg: float) -> void:
	var d: Dictionary = Defs.TOWERS[t.tid]
	var p := Proj.new()
	p.pos = t.pos; p.lpos = e.pos; p.target = e
	p.dmg = dmg; p.splash = t.splash; p.color = d["color"]
	p.kind = d["proj"]; p.slow = t.slow; p.slow_dur = t.slow_dur
	p.poison_dps = t.poison_dps; p.poison_dur = t.poison_dur; p.stun_dur = t.stun_dur
	p.air = Defs.TOWERS[t.tid].get("air", true)
	if t.tid == "deli":
		p.speed = 900.0
	elif t.splash > 0:
		p.speed = 420.0
	else:
		p.speed = 680.0 if t.tid == "sipahi" else 760.0
	projs.append(p)

func _apply_status(e: Enemy, p: Proj) -> void:
	if p.slow > 0.0:
		e.slow_t = max(e.slow_t, p.slow_dur)
		e.slow_factor = min(e.slow_factor if e.slow_t > 0.0 else 1.0, 1.0 - p.slow)
	if p.poison_dps > 0.0:
		e.poison_dps = max(e.poison_dps, p.poison_dps); e.poison_t = max(e.poison_t, p.poison_dur)
	if p.stun_dur > 0.0:
		e.stun_t = max(e.stun_t, p.stun_dur)

func _hurt(e: Enemy, dmg: float, ignore_armor: bool) -> void:
	var dd = dmg if ignore_armor else max(1.0, dmg - e.armor)
	e.hp -= dd; e.hit = 0.12; e.last_dmg_t = 0.0

func _impact(p: Proj) -> void:
	if p.splash > 0:
		for e in enemies:
			if not e.alive: continue
			if e.flying and not p.air: continue
			if e.pos.distance_to(p.pos) <= p.splash:
				_hurt(e, p.dmg, false); _apply_status(e, p)
		_ring(p.pos, p.splash, p.color)
	else:
		var e := p.target
		if e and e.alive:
			_hurt(e, p.dmg, false); _apply_status(e, p)

func _process(delta: float) -> void:
	if not paused and phase == "wave":
		for i in speed:
			if phase != "wave": break
			step(delta)
	for k in spell_cd:
		if float(spell_cd[k]) > 0.0:
			spell_cd[k] = max(0.0, float(spell_cd[k]) - delta)
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t <= 0.0: toast_lbl.visible = false
	_refresh_stats()
	queue_redraw()

# ------------------------------------------------- çizim
func _draw() -> void:
	for r in Defs.ROWS:
		for c in Defs.COLS:
			var on_path := path_keys.has(Vector2i(c, r))
			var col: Color
			if on_path: col = Color.BLACK
			else: col = mapdef["ground_b"] if (c + r) % 2 == 1 else mapdef["ground_a"]
			draw_rect(Rect2(c * TILE, r * TILE, TILE, TILE), col, true)
			if not on_path:
				draw_rect(Rect2(c * TILE, r * TILE, TILE, TILE), Color(0.91, 0.71, 0.29, 0.05), false, 1.0)
	_draw_decor()
	var pts := curve.get_baked_points()
	draw_polyline(pts, mapdef["road_edge"], TILE * 0.82, true)
	draw_polyline(pts, mapdef["road"], TILE * 0.62, true)
	_label(start_marker + Vector2(0, -TILE * 0.4), "⛬ BÜKREŞ", Color("c25b40"), 20)
	_label(end_marker + Vector2(0, TILE * 0.2), "⛬ İSTANBUL", Color("e8b64a"), 22)
	# destek aura halkaları
	for t in towers:
		if t.is_support:
			draw_arc(t.pos, t.range_px, 0, TAU, 40, Color(0.31, 0.64, 0.84, 0.18), 2.0)
	# yerleştirme hayaleti
	if sel_type != "" and hover_cell.x > -50:
		var c := hover_cell.x; var r := hover_cell.y
		var ok := _buildable(c, r)
		var d: Dictionary = Defs.TOWERS[sel_type]
		var ce := _cell_center(c, r)
		draw_circle(ce, float(d["range"]), Color(0.91, 0.71, 0.29, 0.08) if ok else Color(0.85, 0.27, 0.23, 0.12))
		draw_arc(ce, float(d["range"]), 0, TAU, 48, Color(0.91, 0.71, 0.29, 0.4) if ok else Color(0.85, 0.27, 0.23, 0.5), 1.5)
		_draw_tower_glyph(ce, sel_type, 1, 0.65)
	if sel_spell == "okyagmuru":
		var spr: Dictionary = SPELLS["okyagmuru"]
		draw_circle(mouse_pos, float(spr["radius"]), Color(0.91, 0.82, 0.54, 0.12))
		draw_arc(mouse_pos, float(spr["radius"]), 0, TAU, 40, Color(0.91, 0.82, 0.54, 0.5), 2.0)
	if sel_tower:
		draw_circle(sel_tower.pos, sel_tower.range_px, Color(0.91, 0.71, 0.29, 0.07))
		draw_arc(sel_tower.pos, sel_tower.range_px, 0, TAU, 48, Color(0.91, 0.71, 0.29, 0.45), 1.5)
	for t in towers:
		_draw_tower(t)
	for p in projs:
		_draw_proj(p)
	for e in enemies:
		_draw_enemy(e)
	for pop in pops:
		if pop.ring > 0:
			var a: float = clamp(pop.t / 0.28, 0.0, 1.0)
			draw_arc(pop.pos, pop.ring * (1.0 - pop.t / 0.28), 0, TAU, 32, Color(pop.color.r, pop.color.g, pop.color.b, a), 2.0)
		else:
			var a2: float = clamp(pop.t / 0.9, 0.0, 1.0)
			_label(pop.pos, pop.text, Color(pop.color.r, pop.color.g, pop.color.b, a2), 20)

func _draw_decor() -> void:
	var biome: String = mapdef.get("decor", "city")
	for r in Defs.ROWS:
		for c in Defs.COLS:
			if path_keys.has(Vector2i(c, r)): continue
			var h: int = abs((c * 73856093) ^ (r * 19349663) ^ decor_seed)
			if h % 4 != 0: continue
			var cx := c * TILE + TILE / 2.0 + float((h >> 3) % 22 - 11)
			var cy := r * TILE + TILE / 2.0 + float((h >> 7) % 22 - 11)
			var v := (h >> 4) % 3
			match biome:
				"forest": _decor_tree(Vector2(cx, cy), v)
				"swamp": _decor_reed(Vector2(cx, cy), v)
				"steppe": _decor_tuft(Vector2(cx, cy), v)
				_: _decor_stone(Vector2(cx, cy), v)

func _decor_tree(p: Vector2, v: int) -> void:
	var s := 10.0 + v * 3.0
	draw_line(p + Vector2(0, s * 0.5), p + Vector2(0, s * 1.1), Color(0.22, 0.15, 0.09, 0.55), 3.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.7, s * 0.5), p + Vector2(-s * 0.7, s * 0.5)]), Color(0.16, 0.3, 0.17, 0.6))

func _decor_reed(p: Vector2, v: int) -> void:
	for i in 3:
		var dx := (i - 1) * 4.0
		draw_line(p + Vector2(dx, 8), p + Vector2(dx - 2, -8 - v * 2), Color(0.33, 0.45, 0.3, 0.5), 2.0)

func _decor_tuft(p: Vector2, v: int) -> void:
	for i in 4:
		var a := -1.0 + i * 0.6
		draw_line(p, p + Vector2(a * 5, -7 - v), Color(0.42, 0.4, 0.24, 0.45), 1.5)

func _decor_stone(p: Vector2, v: int) -> void:
	draw_circle(p, 4.0 + v, Color(0.26, 0.22, 0.18, 0.5))

func _draw_tower(t: Tower) -> void:
	_draw_tower_glyph(t.pos, t.tid, t.level, 1.0)

func _draw_tower_glyph(pos: Vector2, tid: String, level: int, alpha: float) -> void:
	var d: Dictionary = Defs.TOWERS[tid]
	var col: Color = d["color"]
	var stone := Color(0.19, 0.15, 0.11, alpha)
	# yer gölgesi
	draw_circle(pos + Vector2(0, 20), 22, Color(0, 0, 0, 0.22 * alpha))
	# burç gövdesi (trapez)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-19, -16), pos + Vector2(19, -16),
		pos + Vector2(23, 22), pos + Vector2(-23, 22)]), stone)
	# mazgallar
	for i in 3:
		draw_rect(Rect2(pos.x - 18 + i * 14, pos.y - 24, 9, 9), stone, true)
	draw_line(pos + Vector2(-23, 22), pos + Vector2(23, 22), Color(0.1, 0.08, 0.05, alpha), 2.0)
	# amblem diski
	draw_circle(pos, 14, Color(col.r, col.g, col.b, alpha))
	draw_arc(pos, 14, 0, TAU, 20, Color(0, 0, 0, 0.3 * alpha), 2.0)
	_label(pos + Vector2(0, 1), d["glyph"], Color(0.09, 0.05, 0.03, alpha), 22, true)
	# bayrak
	draw_line(pos + Vector2(15, -24), pos + Vector2(15, -42), Color(0.3, 0.25, 0.18, alpha), 2.0)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(15, -42), pos + Vector2(31, -37), pos + Vector2(15, -32)]),
		Color(col.r, col.g, col.b, alpha))
	# seviye nişanları
	if level > 1:
		for i in (level - 1):
			draw_circle(pos + Vector2(-8 + i * 8, 15), 2.6, Color("e8b64a"))

func _draw_enemy(e: Enemy) -> void:
	draw_circle(e.pos + Vector2(0, e.r * 0.55), e.r * 0.95, Color(0, 0, 0, 0.2))
	if e.flying:
		draw_line(e.pos + Vector2(-e.r, -2), e.pos + Vector2(-e.r - 7, -8), Color(0.2, 0.15, 0.25, 0.8), 3.0)
		draw_line(e.pos + Vector2(e.r, -2), e.pos + Vector2(e.r + 7, -8), Color(0.2, 0.15, 0.25, 0.8), 3.0)
	if e.armor > 0.0:
		draw_arc(e.pos, e.r + 2, 0, TAU, 20, Color(0.74, 0.78, 0.84, 0.7), 2.0)
	if e.stun_t > 0.0:
		draw_arc(e.pos, e.r + 4, 0, TAU, 20, Color(0.95, 0.85, 0.3, 0.9), 2.5)
	elif e.slow_t > 0.0:
		draw_arc(e.pos, e.r + 4, 0, TAU, 24, Color(0.35, 0.7, 0.9, 0.8), 2.5)
	if e.poison_t > 0.0:
		draw_arc(e.pos, e.r + 7, 0, TAU, 20, Color(0.45, 0.85, 0.35, 0.7), 2.0)
	var body := Color.WHITE if e.hit > 0.0 else e.color
	draw_circle(e.pos, e.r, body)
	if e.hit <= 0.0:
		var dk := body.darkened(0.3)
		draw_circle(e.pos + Vector2(0, e.r * 0.3), e.r * 0.75, Color(dk.r, dk.g, dk.b, 0.45))
		draw_circle(e.pos + Vector2(-e.r * 0.3, -e.r * 0.3), e.r * 0.3, Color(1, 1, 1, 0.12))
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
		"whirl":
			draw_arc(p.pos, 8, 0, TAU, 12, p.color, 2.5)
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

# ------------------------------------------------- girdi
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var m := get_global_mouse_position()
		mouse_pos = m
		hover_cell = Vector2i(int(m.x / TILE), int(m.y / TILE))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if phase == "won" or phase == "lost": return
		var m := get_global_mouse_position()
		if sel_spell != "":
			_cast(sel_spell, m)
			return
		var c := int(m.x / TILE); var r := int(m.y / TILE)
		if c < 0 or c >= Defs.COLS or r < 0 or r >= Defs.ROWS: return
		var existing := _tower_at(c, r)
		if sel_type != "":
			if existing:
				sel_tower = existing; sel_type = ""
			elif _buildable(c, r):
				var d: Dictionary = Defs.TOWERS[sel_type]
				if gold >= int(d["cost"]):
					gold -= int(d["cost"]); towers.append(_make_tower(sel_type, c, r))
				else:
					_toast("Yeterli altın yok!")
		else:
			sel_tower = existing
		_refresh_hud()

# ------------------------------------------------- HUD
func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var top := _panel(Color(0.12, 0.06, 0.08, 0.92))
	top.anchor_right = 1.0; top.offset_bottom = 96
	hud.add_child(top)
	var th := HBoxContainer.new()
	th.set_anchors_preset(Control.PRESET_FULL_RECT)
	th.alignment = BoxContainer.ALIGNMENT_CENTER
	th.add_theme_constant_override("separation", 26)
	top.add_child(th)
	gold_lbl = _stat_label(th, "Altın", Color("e8b64a"))
	life_lbl = _stat_label(th, "Surlar", Color("c6362b"))
	wave_lbl = _stat_label(th, "Dalga", Color("f4e6cc"))

	var bottom := VBoxContainer.new()
	bottom.anchor_left = 0; bottom.anchor_right = 1; bottom.anchor_top = 1; bottom.anchor_bottom = 1
	bottom.offset_left = 8; bottom.offset_right = -8; bottom.offset_top = -322; bottom.offset_bottom = -10
	bottom.add_theme_constant_override("separation", 7)
	hud.add_child(bottom)

	# seçili kule paneli
	sel_box = VBoxContainer.new()
	sel_box.add_theme_constant_override("separation", 4)
	sel_box.visible = false
	bottom.add_child(sel_box)
	sel_lbl = Label.new()
	sel_lbl.add_theme_font_size_override("font_size", 17)
	sel_lbl.add_theme_color_override("font_color", Color("f4e6cc"))
	sel_box.add_child(sel_lbl)
	sel_desc = Label.new()
	sel_desc.add_theme_font_size_override("font_size", 14)
	sel_desc.add_theme_color_override("font_color", Color("c3a488"))
	sel_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sel_box.add_child(sel_desc)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 7)
	sel_box.add_child(brow)
	up1_btn = _mk_button("—", Color("d79b2b"), Color("1a0d08"))
	up1_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up1_btn.pressed.connect(func(): _on_up(0))
	brow.add_child(up1_btn)
	up2_btn = _mk_button("—", Color("46b3b0"), Color("08221f"))
	up2_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up2_btn.pressed.connect(func(): _on_up(1))
	brow.add_child(up2_btn)
	sell_btn = _mk_button("Sat", Color("4a4a54"), Color.WHITE)
	sell_btn.pressed.connect(_on_sell)
	brow.add_child(sell_btn)

	# büyü satırı
	var spells_row := HBoxContainer.new()
	spells_row.add_theme_constant_override("separation", 8)
	bottom.add_child(spells_row)
	for sid in ["okyagmuru", "don"]:
		var sp: Dictionary = SPELLS[sid]
		var sbtn := _mk_button("%s %s" % [sp["icon"], sp["name"]], Color("1b2b33"), Color("bfe6f0"))
		sbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sbtn.add_theme_font_size_override("font_size", 16)
		var sid_local = sid
		sbtn.pressed.connect(func(): _on_spell(sid_local))
		spells_row.add_child(sbtn)
		spell_btns[sid] = sbtn

	var ctrl := HBoxContainer.new()
	ctrl.add_theme_constant_override("separation", 8)
	bottom.add_child(ctrl)
	start_btn = _mk_button("Dalgayı Başlat", Color("c0362b"), Color.WHITE)
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.pressed.connect(_on_start)
	ctrl.add_child(start_btn)
	speed_btn = _mk_button("1×", Color("2a1620"), Color("f4e6cc"))
	speed_btn.custom_minimum_size = Vector2(68, 0)
	speed_btn.pressed.connect(_on_speed)
	ctrl.add_child(speed_btn)
	pause_btn = _mk_button("⏸", Color("2a1620"), Color("f4e6cc"))
	pause_btn.custom_minimum_size = Vector2(68, 0)
	pause_btn.pressed.connect(_on_pause)
	ctrl.add_child(pause_btn)

	var shop := HBoxContainer.new()
	shop.add_theme_constant_override("separation", 6)
	bottom.add_child(shop)
	for tid in Defs.SHOP_ORDER:
		if not GameData.unlocked.has(tid): continue
		var d: Dictionary = Defs.TOWERS[tid]
		var b := _mk_button("%s\n✦%d" % [d["name"], d["cost"]], Color("241320"), Color("f4e6cc"))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 58)
		b.add_theme_font_size_override("font_size", 15)
		var tid_local = tid
		b.pressed.connect(func(): _on_shop(tid_local))
		shop.add_child(b)
		shop_btns[tid] = b

	toast_lbl = Label.new()
	toast_lbl.anchor_left = 0.5; toast_lbl.anchor_right = 0.5; toast_lbl.offset_top = 108
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.add_theme_font_size_override("font_size", 20)
	toast_lbl.add_theme_color_override("font_color", Color("f4e6cc"))
	toast_lbl.visible = false
	hud.add_child(toast_lbl)

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
	var sb := StyleBoxFlat.new(); sb.bg_color = col
	p.add_theme_stylebox_override("panel", sb)
	return p

func _stat_label(parent: Node, key: String, col: Color) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	parent.add_child(box)
	var k := Label.new(); k.text = key
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.add_theme_font_size_override("font_size", 13)
	k.add_theme_color_override("font_color", Color("8a6c5c"))
	box.add_child(k)
	var v := Label.new(); v.text = "0"
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_theme_font_size_override("font_size", 30)
	v.add_theme_color_override("font_color", col)
	box.add_child(v)
	return v

func _mk_button(text: String, bg: Color, fg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = Vector2(0, 50)
	b.clip_text = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg; sb.set_corner_radius_all(11)
	sb.content_margin_left = 10; sb.content_margin_right = 10
	sb.content_margin_top = 6; sb.content_margin_bottom = 6
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate(); sh.bg_color = bg.lightened(0.12)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_stylebox_override("disabled", sb)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_disabled_color", Color(fg.r, fg.g, fg.b, 0.4))
	return b

func _toast(msg: String) -> void:
	toast_lbl.text = msg; toast_lbl.visible = true; toast_t = 1.4

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

func _on_up(slot: int) -> void:
	var t := sel_tower
	if not t or t.level >= 3: return
	var cost := _up_cost(t, slot)
	if gold < cost:
		_toast("Yeterli altın yok!"); return
	gold -= cost; t.invested += cost
	if t.level == 1:
		t.branch = _branch_keys(t.tid)[slot]
	t.level += 1
	_recalc(t)
	_refresh_hud()

func _on_sell() -> void:
	if not sel_tower: return
	gold += _sell_val(sel_tower)
	towers.erase(sel_tower)
	sel_tower = null
	_refresh_hud()

func _on_spell(id: String) -> void:
	if float(spell_cd[id]) > 0.0: return
	var sp: Dictionary = SPELLS[id]
	if sp["targeted"]:
		sel_spell = "" if sel_spell == id else id
		sel_type = ""; sel_tower = null
		_refresh_hud()
	else:
		_cast(id, Vector2.ZERO)

func _cast(id: String, pos: Vector2) -> void:
	var sp: Dictionary = SPELLS[id]
	spell_cd[id] = sp["cd"]
	if id == "okyagmuru":
		for e in enemies:
			if e.alive and e.pos.distance_to(pos) <= float(sp["radius"]):
				_hurt(e, float(sp["dmg"]), true)
		_ring(pos, float(sp["radius"]), Color("e8d08a"))
		_ring(pos, float(sp["radius"]) * 0.6, Color("e8d08a"))
	elif id == "don":
		for e in enemies:
			if e.alive: e.stun_t = max(e.stun_t, float(sp["freeze"]))
		_ring(Vector2(360, 760), 320, Color("7fd3ff"))
	sel_spell = ""
	_refresh_hud()

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
	for id in spell_btns:
		var b: Button = spell_btns[id]
		var cd := float(spell_cd[id])
		var sp: Dictionary = SPELLS[id]
		if cd > 0.0:
			b.text = "%s %ds" % [sp["icon"], int(ceil(cd))]; b.disabled = true
		else:
			b.text = "%s %s" % [sp["icon"], sp["name"]]; b.disabled = false
		var sb: StyleBoxFlat = b.get_theme_stylebox("normal")
		var bw := 2 if id == sel_spell else 0
		sb.border_width_left = bw; sb.border_width_right = bw
		sb.border_width_top = bw; sb.border_width_bottom = bw
		sb.border_color = Color("7fd3ff")

func _refresh_hud() -> void:
	_refresh_stats()
	for tid in shop_btns:
		var b: Button = shop_btns[tid]
		var selected = tid == sel_type
		var affordable = gold >= int(Defs.TOWERS[tid]["cost"])
		var sb: StyleBoxFlat = b.get_theme_stylebox("normal")
		var bw := 2 if selected else 0
		sb.border_width_left = bw; sb.border_width_right = bw
		sb.border_width_top = bw; sb.border_width_bottom = bw
		sb.border_color = Color("e8b64a")
		b.modulate = Color(1, 1, 1, 1) if affordable else Color(0.55, 0.55, 0.55, 1)
	if sel_tower:
		sel_box.visible = true
		var t := sel_tower
		var d: Dictionary = Defs.TOWERS[t.tid]
		if t.is_support:
			sel_lbl.text = "%s  Sv.%d  •  +%d%% hasar  •  +%d%% hız  •  Menzil %d" % [d["name"], t.level, int(t.aura_dmg * 100), int(t.aura_fr * 100), int(t.range_px)]
		else:
			sel_lbl.text = "%s  Sv.%d  •  Hasar %d  •  Menzil %d" % [d["name"], t.level, int(t.damage), int(t.range_px)]
		var bk := _branch_keys(t.tid)
		if t.level == 1:
			var b1: Dictionary = d["branches"][bk[0]]
			var b2: Dictionary = d["branches"][bk[1]]
			up1_btn.visible = true; up2_btn.visible = true
			up1_btn.text = "%s\n✦%d" % [b1["name"], int(b1["t1"]["cost"])]
			up2_btn.text = "%s\n✦%d" % [b2["name"], int(b2["t1"]["cost"])]
			up1_btn.disabled = gold < int(b1["t1"]["cost"])
			up2_btn.disabled = gold < int(b2["t1"]["cost"])
			sel_desc.text = "Dal seç →  %s: %s   |   %s: %s" % [b1["name"], b1["desc"], b2["name"], b2["desc"]]
		elif t.level == 2:
			var br: Dictionary = d["branches"][t.branch]
			up1_btn.visible = true; up2_btn.visible = false
			var c2 := int(br["t2"]["cost"])
			up1_btn.text = "%s II  ✦%d" % [br["name"], c2]
			up1_btn.disabled = gold < c2
			sel_desc.text = "%s — %s" % [br["name"], br["desc"]]
		else:
			up1_btn.visible = false; up2_btn.visible = false
			sel_desc.text = "Azami seviye — %s" % d["branches"][t.branch]["name"]
		sell_btn.text = "Sat ✦%d" % _sell_val(t)
	else:
		sel_box.visible = false

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
