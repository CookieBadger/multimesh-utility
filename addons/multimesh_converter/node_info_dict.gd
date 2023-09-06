extends Object

var dict := Dictionary()
var NodeInfo = preload("res://addons/multimesh_converter/node_info.gd")

# Called when the node enters the scene tree for the first time.
func add_node(scene_file_path: String, node: Node):
	if !dict.has(scene_file_path):
		dict[scene_file_path] = Array()
	dict[scene_file_path].push_back(node)

