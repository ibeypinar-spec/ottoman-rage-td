extends Node
## Basit sahne yöneticisi — ekranlar kodla kurulur, .tscn gerektirmez.

const MainMenuScript := preload("res://MainMenu.gd")
const MapSelectScript := preload("res://MapSelect.gd")
const GameScreenScript := preload("res://GameScreen.gd")

var current: Node = null

func _ready() -> void:
	goto_menu()

func _swap(node: Node) -> void:
	if current and is_instance_valid(current):
		current.queue_free()
	current = node
	node.set("main", self)
	add_child(node)

func goto_menu() -> void:
	_swap(MainMenuScript.new())

func goto_mapselect() -> void:
	_swap(MapSelectScript.new())

func goto_game(map_id: String) -> void:
	var g = GameScreenScript.new()
	g.map_id = map_id
	_swap(g)
