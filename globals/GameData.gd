extends Node
## Meta ilerleme + kayıt. Seferler arası kalıcı durum burada tutulur.

const SAVE_PATH := "user://save.json"

var meta_gold: int = 0                      # seferler arası biriken hazine
var unlocked: Array = ["sipahi", "yeniceri", "deli", "abdal", "ozan", "imam"]  # açık kuleler
var best_stars: Dictionary = {}             # map_id -> 0..3 yıldız
var perks: Dictionary = {                   # kalıcı yükseltmeler (meta ağaç) — ileride büyüyecek
	"start_gold_bonus": 0,                  # her sefere ek başlangıç altını
	"tower_damage": 0,                      # % kule hasar bonusu (her seviye +%5)
	"start_life_bonus": 0,                  # ek başlangıç surları
}
var settings: Dictionary = {"speed": 1}

func _ready() -> void:
	load_game()

func damage_mult() -> float:
	return 1.0 + 0.05 * int(perks.get("tower_damage", 0))

func map_stars(map_id: String) -> int:
	return int(best_stars.get(map_id, 0))

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
