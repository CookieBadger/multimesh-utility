extends Object

var name: String
var meshNode: Node
var colliderNode: Node

func _init(name: String, meshNode: Node, colliderNode: Node):
	self.name = name
	self.meshNode = meshNode
	self.colliderNode = colliderNode
