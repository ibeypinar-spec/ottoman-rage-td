extends Node
## Meta ilerleme + kayıt. Seferler arası kalıcı durum burada tutulur.

const SAVE_PATH := "user://save.json"

var meta_gold: int = 0                      # seferler arası biriken hazine
var unlocked: Array = ["sipahi", "yeniceri", "deli", "abdal", "ozan", "imam"]  # açık kuleler
var best_stars: Dictionary = {}             # map_id -> 0..3 yıldız
var perks: Dictionary = {                   # kalıcı yükseltmeler (Ocak meta ağacı)
	"tower_damage": 0,                      # +%5 kule hasarı / seviye
	"start_gold_bonus": 0,                  # +20 başlangıç altını / seviye
	"start_life_bonus": 0,                  # +2 başlangıç suru / seviye
	"spell_cd": 0,                          # -%10 büyü bekleme / seviye
	"wave_income": 0,                       # +6 altın/dalga / seviye
}
var settings: Dictionary = {"speed": 1}

func _ready() -> void:
	load_game()

func damage_mult() -> float:
	return 1.0 + 0.05 * int(perks.get("tower_damage", 0))

func spell_cd_mult() -> float:
	return 1.0 - 0.10 * int(perks.get("spell_cd", 0))

func wave_income_bonus() -> int:
	return 6 * int(perks.get("wave_income", 0))

func perk_level(key: String) -> int:
	return int(perks.get(key, 0))

func perk_cost(key: String) -> int:
	var cat: Dictionary = Defs.PERKS[key]
	var lvl := perk_level(key)
	if lvl >= int(cat["max"]):
		return -1
	return int(cat["cost"]) + int(cat["step"]) * lvl

func buy_perk(key: String) -> bool:
	var cost := perk_cost(key)
	if cost < 0 or meta_gold < cost:
		return false
	meta_gold -= cost
	perks[key] = perk_level(key) + 1
	save_game()
	return true

func map_stars(map_id: String) -> int:
	return int(best_stars.get(map_id, 0))

func is_map_unlocked(map_id: String) -> bool:
	var idx: int = Defs.CAMPAIGN.find(map_id)
	if idx <= 0:
		return true
	return map_stars(Defs.CAMPAIGN[idx - 1]) >= 1

func record_result(map_id: String, stars: int, earned_gold: int) -> void:
	if stars > map_stars(map_id):
		best_stars[map_id] = stars
	meta_gold += earned_gold
	save_game()

func save_game() -> void:
	var data := {
		"meta_gold": meta_gold,
		"unlocked": unlocked,
		"best_stars": best_stars,
		"perks": perks,
		"settings": settings,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	meta_gold = int(parsed.get("meta_gold", meta_gold))
	if parsed.has("unlocked"): unlocked = parsed["unlocked"]
	if parsed.has("best_stars"): best_stars = parsed["best_stars"]
	if parsed.has("perks"):
		for k in parsed["perks"]:
			perks[k] = parsed["perks"][k]
	if parsed.has("settings"):
		for k in parsed["settings"]:
			settings[k] = parsed["settings"][k]
