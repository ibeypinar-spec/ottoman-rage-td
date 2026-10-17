extends Node
## Tüm oyun verisi tek yerde — kule/düşman/dalga/harita tanımları.
## Derinlik eklemek: buraya veri eklemek demek.

const COLS := 9
const ROWS := 16
const TILE := 80

# ------------------------------------------------------------------ KULELER
# Temel alanlar: cost, range, damage, fire_rate, splash, slow, slow_dur.
# support=true → saldırmaz, çevre kuleleri güçlendirir (aura_dmg / aura_fr).
# branches: iki dal. Her dalın t1 (seviye 2) ve t2 (seviye 3) tam-durum modifikatörleri.
#   Çarpan alanlar: damage, range, fire_rate, splash, aura_dmg_add, aura_fr_add
#   Mutlak alanlar: poison_dps, poison_dur, stun_dur, multishot, slow, slow_dur, ramp,
#                   splash_abs, aura_dmg, aura_fr
const TOWERS := {
	"sipahi": {
		"name":"Sipahi","cls":"Nişancı","cost":50,"glyph":"S","color":Color("63b85a"),
		"range":190,"damage":9,"fire_rate":0.38,"splash":0,"slow":0.0,"slow_dur":0.0,
		"proj":"arrow","desc":"Hızlı ok yağmuru, uzun menzil.",
		"branches":{
			"zehir":{"name":"Zehirli Ok","desc":"Oklar zehirler; saniyede hasar.",
				"t1":{"cost":60,"poison_dps":9,"poison_dur":3.0},
				"t2":{"cost":110,"damage":1.1,"poison_dps":22,"poison_dur":3.5,"slow":0.25,"slow_dur":1.0}},
			"coklu":{"name":"Çoklu Atış","desc":"Aynı anda birden çok hedefe ok.",
				"t1":{"cost":60,"range":1.15,"multishot":2},
				"t2":{"cost":120,"range":1.25,"damage":1.15,"multishot":3}},
		},
	},
	"yeniceri": {
		"name":"Yeniçeri","cls":"Savaşçı","cost":60,"glyph":"Y","color":Color("df5a4e"),
		"range":150,"damage":21,"fire_rate":0.85,"splash":0,"slow":0.0,"slow_dur":0.0,
		"proj":"musket","desc":"Tüfekle dengeli tek hedef hasarı.",
		"branches":{
			"pala":{"name":"Pala Ustası","desc":"Ağır tek hedef, yüksek hasar.",
				"t1":{"cost":65,"damage":1.6,"range":1.1},
				"t2":{"cost":130,"damage":2.4,"range":1.15}},
			"ocak":{"name":"Ocak Nizamı","desc":"Hızlı atış + hafif alan.",
				"t1":{"cost":65,"fire_rate":0.6,"damage":1.1},
				"t2":{"cost":130,"fire_rate":0.45,"damage":1.2,"splash_abs":44}},
		},
	},
	"deli": {
		"name":"Deli","cls":"Cengâver","cost":85,"glyph":"D","color":Color("e05a7a"),
		"range":100,"damage":15,"fire_rate":0.8,"splash":100,"slow":0.0,"slow_dur":0.0,
		"air":false,"proj":"whirl","desc":"Kısa menzil, çevredekilere döne döne vurur. Uçanları vuramaz.",
		"branches":{
			"ofke":{"name":"Kan Öfkesi","desc":"Vurdukça hasarı artar (öfke birikir).",
				"t1":{"cost":80,"damage":1.2,"ramp":0.08},
				"t2":{"cost":150,"damage":1.4,"ramp":0.14}},
			"kasirga":{"name":"Kasırga","desc":"Daha geniş dönme alanı.",
				"t1":{"cost":80,"range":1.25,"splash":1.25,"damage":1.1},
				"t2":{"cost":150,"range":1.5,"splash":1.5,"damage":1.25}},
		},
	},
	"abdal": {
		"name":"Abdal","cls":"Doğa","cost":70,"glyph":"A","color":Color("a877d6"),
		"range":150,"damage":5,"fire_rate":0.9,"splash":0,"slow":0.5,"slow_dur":1.6,
		"proj":"wisp","desc":"Beddua ile düşmanı %50 yavaşlatır.",
		"branches":{
			"beddua":{"name":"Beddua","desc":"Güçlü yavaşlatma + zehir.",
				"t1":{"cost":70,"slow":0.6,"slow_dur":2.0,"poison_dps":7,"poison_dur":2.5},
				"t2":{"cost":130,"slow":0.7,"slow_dur":2.4,"poison_dps":16,"poison_dur":3.0}},
			"ruzgar":{"name":"Rüzgâr Ruhu","desc":"Alan yavaşlatma (grup).",
				"t1":{"cost":70,"splash_abs":70,"slow":0.45,"slow_dur":1.6},
				"t2":{"cost":130,"splash_abs":95,"slow":0.55,"slow_dur":2.0,"damage":1.5}},
		},
	},
	"ozan": {
		"name":"Ozan","cls":"Aşık","cost":90,"glyph":"O","color":Color("4ea3d6"),
		"range":150,"damage":0,"fire_rate":1.0,"splash":0,"slow":0.0,"slow_dur":0.0,
		"proj":"none","support":true,"aura_dmg":0.15,"aura_fr":0.0,
		"desc":"Saldırmaz; menzildeki kuleleri güçlendirir.",
		"branches":{
			"yigitlik":{"name":"Yiğitlik Türküsü","desc":"Çevre kulelere +hasar.",
				"t1":{"cost":75,"aura_dmg":0.28,"range":1.1},
				"t2":{"cost":140,"aura_dmg":0.48,"range":1.2}},
			"savas":{"name":"Savaş Türküsü","desc":"Çevre kulelere +atış hızı.",
				"t1":{"cost":75,"aura_fr":0.28,"range":1.1},
				"t2":{"cost":140,"aura_fr":0.5,"aura_dmg":0.12,"range":1.2}},
		},
	},
	"imam": {
		"name":"İmam","cls":"Büyücü","cost":95,"glyph":"İ","color":Color("46b3b0"),
		"range":155,"damage":16,"fire_rate":1.25,"splash":70,"slow":0.0,"slow_dur":0.0,
		"proj":"magic","desc":"Kutsal büyü patlaması — grupları biçer.",
		"branches":{
			"nazar":{"name":"Nazar Oku","desc":"Tek hedefe ağır hasar + sersemletme.",
				"t1":{"cost":90,"damage":2.2,"splash":0.0,"stun_dur":0.6},
				"t2":{"cost":170,"damage":3.4,"splash":0.0,"stun_dur":1.1}},
			"gazap":{"name":"İlahi Gazap","desc":"Çok geniş alan hasarı.",
				"t1":{"cost":90,"splash":1.3,"damage":1.2},
				"t2":{"cost":170,"splash":1.7,"damage":1.5}},
		},
	},
}
const SHOP_ORDER := ["sipahi", "yeniceri", "deli", "abdal", "ozan", "imam"]

# ------------------------------------------------------------------ DÜŞMANLAR
const ENEMIES := {
	"eskiya":   {"name":"Eşkıya",         "hp": 42,   "speed": 70,  "gold": 6,   "leak": 1,  "r": 14, "color": Color("c25b40")},
	"asker":    {"name":"Asker",          "hp": 100,  "speed": 54,  "gold": 11,  "leak": 1,  "r": 15, "color": Color("9199a6")},
	"strigoi":  {"name":"Strigoi",        "hp": 74,   "speed": 100, "gold": 13,  "leak": 1,  "r": 14, "color": Color("caa6e2")},
	"zirhli":   {"name":"Zırhlı Muhafız", "hp": 230,  "speed": 40,  "gold": 22,  "leak": 2,  "r": 17, "color": Color("7d8694"), "armor": 12},
	"yarasa":   {"name":"Yarasa Sürüsü",  "hp": 30,   "speed": 122, "gold": 5,   "leak": 1,  "r": 10, "color": Color("6a4f80"), "flying": true},
	"hortlak":  {"name":"Hortlak",        "hp": 150,  "speed": 52,  "gold": 18,  "leak": 1,  "r": 15, "color": Color("8aa06a"), "regen": 20},
	"vukodlak": {"name":"Vukodlak",       "hp": 460,  "speed": 42,  "gold": 45,  "leak": 3,  "r": 21, "color": Color("6a5440"), "boss": true},
	"vlad":     {"name":"Vlad Dracul",    "hp": 3400, "speed": 36,  "gold": 260, "leak": 10, "r": 28, "color": Color("8a1522"), "boss": true, "regen": 22},
}

# ------------------------------------------------------------------ DALGALAR
const WAVES := [
	[{"t":"eskiya","n":6,"gap":0.9,"delay":0.5}],
	[{"t":"eskiya","n":12,"gap":0.6,"delay":0.3}],
	[{"t":"asker","n":6,"gap":1.0,"delay":0.3},{"t":"eskiya","n":8,"gap":0.5,"delay":1.0}],
	[{"t":"strigoi","n":8,"gap":0.55,"delay":0.3}],
	[{"t":"asker","n":8,"gap":0.6,"delay":0.3},{"t":"zirhli","n":3,"gap":1.6,"delay":1.5}],
	[{"t":"vukodlak","n":1,"gap":1,"delay":0.2},{"t":"eskiya","n":14,"gap":0.45,"delay":1.5}],
	[{"t":"strigoi","n":10,"gap":0.45,"delay":0.3},{"t":"yarasa","n":8,"gap":0.4,"delay":2.5}],
	[{"t":"asker","n":10,"gap":0.5,"delay":0.3},{"t":"hortlak","n":4,"gap":1.4,"delay":2}],
	[{"t":"zirhli","n":5,"gap":1.3,"delay":0.3},{"t":"vukodlak","n":2,"gap":4,"delay":1}],
	[{"t":"yarasa","n":16,"gap":0.3,"delay":0.3},{"t":"strigoi","n":10,"gap":0.4,"delay":2}],
	[{"t":"hortlak","n":6,"gap":1.1,"delay":0.3},{"t":"vukodlak","n":3,"gap":2.5,"delay":1}],
	[{"t":"zirhli","n":6,"gap":1.0,"delay":0.3},{"t":"yarasa","n":12,"gap":0.3,"delay":2},{"t":"vukodlak","n":3,"gap":2.5,"delay":3}],
	[{"t":"vlad","n":1,"gap":1,"delay":0.5},{"t":"vukodlak","n":3,"gap":4,"delay":2},{"t":"strigoi","n":12,"gap":0.5,"delay":3}],
]

# ------------------------------------------------------------------ HARİTALAR
const MAPS := {
	"istanbul": {
		"name": "İstanbul Yolu", "biome": "Şehir",
		"start_gold": 160, "start_life": 20,
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
