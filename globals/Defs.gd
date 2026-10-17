extends Node
## Tüm oyun verisi tek yerde — kule/düşman/dalga/harita tanımları.
## Derinlik eklemek: buraya veri eklemek demek.

const COLS := 9
const ROWS := 16
const TILE := 80

# ------------------------------------------------------------------ KULELER
# damage: vuruş hasarı | range: piksel | fire_rate: saniye/atış
# splash: alan yarıçapı (0=tekil) | slow: 0..1 yavaşlatma oranı | slow_dur: sn
const TOWERS := {
	"sipahi": {
		"name": "Sipahi", "cls": "Nişancı", "cost": 50, "glyph": "S",
		"color": Color("63b85a"), "range": 190, "damage": 9, "fire_rate": 0.38,
		"splash": 0, "slow": 0.0, "slow_dur": 0.0, "proj": "arrow",
		"desc": "Hızlı ok yağmuru, uzun menzil.",
	},
	"yeniceri": {
		"name": "Yeniçeri", "cls": "Savaşçı", "cost": 60, "glyph": "Y",
		"color": Color("df5a4e"), "range": 150, "damage": 21, "fire_rate": 0.85,
		"splash": 0, "slow": 0.0, "slow_dur": 0.0, "proj": "musket",
		"desc": "Tüfekle dengeli tek hedef hasarı.",
	},
	"abdal": {
		"name": "Abdal", "cls": "Doğa", "cost": 70, "glyph": "A",
		"color": Color("a877d6"), "range": 150, "damage": 5, "fire_rate": 0.9,
		"splash": 0, "slow": 0.5, "slow_dur": 1.6, "proj": "wisp",
		"desc": "Beddua ile düşmanı %50 yavaşlatır.",
	},
	"imam": {
		"name": "İmam", "cls": "Büyücü", "cost": 95, "glyph": "İ",
		"color": Color("46b3b0"), "range": 155, "damage": 16, "fire_rate": 1.25,
		"splash": 70, "slow": 0.0, "slow_dur": 0.0, "proj": "magic",
		"desc": "Kutsal büyü patlaması — grupları biçer.",
	},
	"topcu": {
		"name": "Topçu", "cls": "Kuşatma", "cost": 120, "glyph": "T",
		"color": Color("e8903c"), "range": 170, "damage": 48, "fire_rate": 2.0,
		"splash": 58, "slow": 0.0, "slow_dur": 0.0, "proj": "cannon",
		"desc": "Ağır gülle, yıkıcı alan hasarı.",
	},
}
const SHOP_ORDER := ["sipahi", "yeniceri", "abdal", "imam", "topcu"]

# ------------------------------------------------------------------ DÜŞMANLAR
const ENEMIES := {
	"eskiya":   {"name": "Eşkıya",      "hp": 42,   "speed": 70,  "gold": 6,   "leak": 1,  "r": 14, "color": Color("c25b40")},
	"asker":    {"name": "Asker",       "hp": 100,  "speed": 54,  "gold": 11,  "leak": 1,  "r": 15, "color": Color("9199a6")},
	"strigoi":  {"name": "Strigoi",     "hp": 74,   "speed": 100, "gold": 13,  "leak": 1,  "r": 14, "color": Color("caa6e2")},
	"vukodlak": {"name": "Vukodlak",    "hp": 460,  "speed": 42,  "gold": 45,  "leak": 3,  "r": 21, "color": Color("6a5440"), "boss": true},
	"vlad":     {"name": "Vlad Dracul", "hp": 3400, "speed": 38,  "gold": 260, "leak": 10, "r": 28, "color": Color("8a1522"), "boss": true},
}

# ------------------------------------------------------------------ DALGALAR
# her grup: {t=tür, n=adet, gap=aralık sn, delay=başlangıç gecikmesi sn}
const WAVES := [
	[{"t":"eskiya","n":6,"gap":0.9,"delay":0.5}],
	[{"t":"eskiya","n":12,"gap":0.6,"delay":0.3}],
	[{"t":"asker","n":6,"gap":1.0,"delay":0.3},{"t":"eskiya","n":8,"gap":0.5,"delay":1.0}],
	[{"t":"strigoi","n":8,"gap":0.55,"delay":0.3}],
	[{"t":"asker","n":12,"gap":0.6,"delay":0.3}],
	[{"t":"vukodlak","n":1,"gap":1,"delay":0.2},{"t":"eskiya","n":14,"gap":0.45,"delay":1.5}],
	[{"t":"strigoi","n":14,"gap":0.42,"delay":0.3}],
	[{"t":"asker","n":12,"gap":0.5,"delay":0.3},{"t":"strigoi","n":8,"gap":0.5,"delay":3}],
	[{"t":"vukodlak","n":2,"gap":3,"delay":0.2},{"t":"asker","n":12,"gap":0.5,"delay":1}],
	[{"t":"strigoi","n":20,"gap":0.33,"delay":0.3}],
	[{"t":"vukodlak","n":3,"gap":2.5,"delay":0.2},{"t":"eskiya","n":18,"gap":0.4,"delay":1}],
	[{"t":"vukodlak","n":4,"gap":2,"delay":0.2},{"t":"strigoi","n":14,"gap":0.4,"delay":1}],
	[{"t":"vlad","n":1,"gap":1,"delay":0.5},{"t":"vukodlak","n":3,"gap":4,"delay":2},{"t":"strigoi","n":14,"gap":0.5,"delay":3}],
]

# ------------------------------------------------------------------ HARİTALAR
# path: grid hücreleri (Vector2i) halinde dönemeçli yol. İlk nokta ekran dışı giriş,
# son nokta ekran dışı çıkış (İstanbul). ground/road: biyom renkleri.
const MAPS := {
	"istanbul": {
		"name": "İstanbul Yolu",
		"biome": "Şehir",
		"start_gold": 160,
		"start_life": 20,
		"ground_a": Color("201814"), "ground_b": Color("241b17"),
		"road_edge": Color("4a3524"), "road": Color("6b4e34"),
		"path": [
			Vector2i(4,-1), Vector2i(4,2), Vector2i(1,2), Vector2i(1,5),
			Vector2i(7,5), Vector2i(7,8), Vector2i(2,8), Vector2i(2,11),
			Vector2i(6,11), Vector2i(6,14), Vector2i(6,16),
		],
	},
}

func wave_count() -> int:
	return WAVES.size()

func build_schedule(wave_index: int) -> Array:
	var s: Array = []
	for g in WAVES[wave_index]:
		for i in g["n"]:
			s.append({"t": float(g["delay"]) + i * float(g["gap"]), "type": g["t"]})
	s.sort_custom(func(a, b): return a["t"] < b["t"])
	return s

func wave_preview(wave_index: int) -> String:
	if wave_index < 0 or wave_index >= WAVES.size():
		return "—"
	var m: Dictionary = {}
	for g in WAVES[wave_index]:
		m[g["t"]] = int(m.get(g["t"], 0)) + int(g["n"])
	var parts: Array = []
	for k in m:
		parts.append("%s ×%d" % [ENEMIES[k]["name"], m[k]])
	return " · ".join(parts)

func wave_bonus(wave_number: int) -> int:
	return 25 + 6 * wave_number
