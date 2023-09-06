@tool
extends EditorPlugin

var plugin_container : Control
var convert_to_multimesh_button : Button
var convert_to_instances_button : Button
var combine_to_single_mesh_button : Button
var convert_instanced_scenes_to_multimeshes_button : Button

const NodeInfo = preload("res://addons/multimesh_converter/node_info.gd")
const NodeInfoDict = preload("res://addons/multimesh_converter/node_info_dict.gd")

func _enter_tree():
	plugin_container = VBoxContainer.new()
	add_control_to_bottom_panel(plugin_container, "MultiMesh Utility")
	
	convert_to_multimesh_button = Button.new()
	convert_to_multimesh_button.text = "Convert Selected To MultiMeshInstance3D"
	convert_to_multimesh_button.pressed.connect(on_convert_to_multimesh)
	plugin_container.add_child(convert_to_multimesh_button)
	
	convert_to_instances_button = Button.new()
	convert_to_instances_button.text = "Convert Selected To MeshInstances"
	convert_to_instances_button.pressed.connect(on_convert_to_instances)
	plugin_container.add_child(convert_to_instances_button)
	
	combine_to_single_mesh_button = Button.new()
	combine_to_single_mesh_button.text = "Combine Selected To Single MeshInstance3D"
	combine_to_single_mesh_button.pressed.connect(on_combine_to_single_mesh)
	plugin_container.add_child(combine_to_single_mesh_button)
	
	convert_instanced_scenes_to_multimeshes_button = Button.new()
	convert_instanced_scenes_to_multimeshes_button.text = "Combine Selected MultiMeshInstances"
	convert_instanced_scenes_to_multimeshes_button.pressed.connect(on_convert_instanced_scenes_to_multimeshes)
	plugin_container.add_child(convert_instanced_scenes_to_multimeshes_button)
	
	get_editor_interface().get_selection().selection_changed.connect(on_selection_changed)
	on_selection_changed()

func _exit_tree():
	if plugin_container != null:
		remove_control_from_bottom_panel(plugin_container)
		plugin_container.queue_free()

func on_selection_changed():
	var to_instances = false
	var to_multimesh = false
	
	## check convert to multimesh possible
	var selectedNodes : Array[Node] = get_editor_interface().get_selection().get_selected_nodes()
	var mesh
	if selectedNodes.size() != 0:
		for node in selectedNodes:
			if !(node is MeshInstance3D) || (mesh != null && mesh != node.mesh):
				to_multimesh = false
			else:
				mesh = node.mesh
				to_multimesh = true
	
	## check convert to mesh instances possible
	if selectedNodes.size() == 1 && selectedNodes[0] is MultiMeshInstance3D:
		to_instances = true
	
	convert_to_multimesh_button.disabled = !to_multimesh
	convert_to_instances_button.disabled = !to_instances

func on_convert_to_multimesh():
	var selectedNodes : Array[Node] = get_editor_interface().get_selection().get_selected_nodes()
	
	if selectedNodes.size() == 0:
		print("Select MeshInstance3D nodes first")
		return
	
	var mesh
	for node in selectedNodes:
		if !(node is MeshInstance3D):
			print("Select MeshInstance3D instances only")
			return
		var mesh_instance = node as MeshInstance3D
		if mesh != null && mesh != mesh_instance.mesh:
			print("Select MeshInstance3D instances of the same mesh only")
			return
			
		mesh = mesh_instance.mesh
		
	var mmi = instances_to_multimesh(selectedNodes)
	
	get_editor_interface().get_selection().add_node(mmi)

func instances_to_multimesh(instances : Array) -> MultiMeshInstance3D:
	var root = get_editor_interface().get_edited_scene_root()
	var mmi = MultiMeshInstance3D.new()
	root.add_child(mmi)
	mmi.owner = root
	mmi.name = "MultiMesh" + instances[0].name
	
	mmi.multimesh = MultiMesh.new()
	mmi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	mmi.multimesh.mesh = (instances[0] as MeshInstance3D).mesh
	mmi.multimesh.instance_count = instances.size()
	var i : int = 0
	
	for node in instances:
		mmi.multimesh.set_instance_transform(i, (node as Node3D).transform)
		i+=1
	
	for node in instances:
		node.queue_free()
	
	return mmi

func on_convert_to_instances():
	var selectedNodes : Array[Node] = get_editor_interface().get_selection().get_selected_nodes()
	
	if selectedNodes.size() != 1 || !(selectedNodes[0] is MultiMeshInstance3D):
		print("Select exactly 1 MultiMeshInstance3D node")
		return
	
	var mesh
	var mmi : MultiMeshInstance3D = selectedNodes[0] as MultiMeshInstance3D
	var root = get_editor_interface().get_edited_scene_root()
	for i in range(mmi.multimesh.instance_count):
		var mesh_instance = MeshInstance3D.new()
		root.add_child(mesh_instance)
		mesh_instance.owner = root
		mesh_instance.mesh = mmi.multimesh.mesh
		mesh_instance.transform = mmi.multimesh.get_instance_transform(i)
		mesh_instance.name = mmi.name.substr(9) if mmi.name.to_lower().begins_with("multimesh") else mmi.name
		get_editor_interface().get_selection().add_node(mesh_instance)
	
	mmi.queue_free()

var meshes = Dictionary()
var save_file_path : String
	
func on_combine_to_single_mesh():
	var selectedNodes : Array[Node] = get_editor_interface().get_selection().get_selected_nodes()
	
	if selectedNodes.size() == 0:
		print("Select some intanced nodes first")
		return
	
	for node in selectedNodes:
		if !(node is Node3D):
			print("Select Node3D instances only")
			return

	for node in selectedNodes:
		if !node.scene_file_path.is_empty():
			if meshes.has(node.scene_file_path):
				mesh_instance_from_mesh_path(node)
			else:
				mesh_instance_new_mesh(node)

func mesh_instance_new_mesh(node: Node3D) -> NodeInfo:
	var mesh = ArrayMesh.new()
	combine_mesh_recursive(node, node, mesh)
	if mesh.get_surface_count() != 0:
		var saveDialog = FileDialog.new()
		saveDialog.title = "Save mesh of " + node.name;
		saveDialog.size = Vector2i(600, 400)
		var base = get_editor_interface().get_base_control()
		saveDialog.position = base.get_viewport().get_window().position + (base.get_viewport_rect().get_center() as Vector2i) - saveDialog.size/2
		saveDialog.position = saveDialog.position.clamp(Vector2i.ZERO + Vector2i.DOWN*30, DisplayServer.screen_get_size(base.get_window().current_screen) - saveDialog.size - Vector2i.DOWN*30)
		saveDialog.popup_exclusive(get_editor_interface().get_base_control())
		saveDialog.file_selected.connect(file_selected)
		await saveDialog.file_selected
		ResourceSaver.save(mesh, save_file_path)
		meshes[node.scene_file_path] = save_file_path
		var meshInst = create_new_mesh_instance(node, ResourceLoader.load(save_file_path))
		var collision_parent = create_new_node_instance(node.get_parent(), node.transform, node.name+"Collider")
		var hasCol = transfer_colliders(node, collision_parent)
		if !hasCol:
			collision_parent.queue_free()
		node.queue_free()
		saveDialog.queue_free()
		return NodeInfo.new(node.name, meshInst, collision_parent if hasCol else null)
	return null
	
func mesh_instance_from_mesh_path(node: Node3D) -> NodeInfo:
	var meshInst = create_new_mesh_instance(node, ResourceLoader.load(meshes[node.scene_file_path]))
	var collision_parent = create_new_node_instance(node.get_parent(), node.transform, node.name+"Collider")
	var hasCol = transfer_colliders(node, collision_parent)
	if !hasCol: 
		collision_parent.queue_free()
	node.queue_free()
	return NodeInfo.new(node.name, meshInst, collision_parent if hasCol else null)
	
func on_convert_instanced_scenes_to_multimeshes():
	var selectedNodes : Array[Node] = get_editor_interface().get_selection().get_selected_nodes()
	
	if selectedNodes.size() == 0:
		print("Select some intanced nodes first")
		return
	
	var colliderDict := NodeInfoDict.new()
	var meshDict := NodeInfoDict.new() 
	
	for node in selectedNodes:
		prints("processing node", node.name)
		if !node.scene_file_path.is_empty():
			if meshes.has(node.scene_file_path):
				var newNode = mesh_instance_from_mesh_path(node)
				meshDict.add_node(node.scene_file_path, newNode.meshNode)
				if newNode.colliderNode != null:
					colliderDict.add_node(node.scene_file_path, newNode.colliderNode)
			else:
				prints("awaiting...")
				var newNode = await mesh_instance_new_mesh(node)
				prints("awaitin finished, new node: ", newNode)
				if newNode != null:
					meshDict.add_node(node.scene_file_path, newNode.meshNode)
					if newNode.colliderNode != null:
						colliderDict.add_node(node.scene_file_path, newNode.colliderNode)
	
	print("all nodes processed")
	var mmiDict = Dictionary()
	
	for key in meshDict.dict.keys():
		var meshInstances = meshDict.dict[key]
		mmiDict[key] = instances_to_multimesh(meshInstances)
		
	for key in colliderDict.dict.keys():
		var cols : Array = colliderDict.dict[key]
		prints("collider nodes:", cols.size())
		if cols.is_empty(): break;
		#var node = create_new_node_instance(cols[0].get_parent(), Transform3D.IDENTITY, "MulitmeshCollider")
		for col in cols:
			col.reparent(mmiDict[key])
			set_owners(col, get_editor_interface().get_edited_scene_root())
	

func file_selected(path: String):
	save_file_path = path

func combine_mesh(root: Node3D, node: Node3D, resultMesh: Mesh):
	var mesh_instance = node as MeshInstance3D
	var mesh = mesh_instance.mesh
	var surfaceNr = resultMesh.get_surface_count()
	if mesh is ArrayMesh:
		var arrayMesh = mesh as ArrayMesh
		for i in range(arrayMesh.get_surface_count()):
			
			var arrays = arrayMesh.surface_get_arrays(i)
			
			var rootGlobalScale = Vector3(root.global_transform.basis.x.length_squared(),root.global_transform.basis.y.length_squared(),root.global_transform.basis.z.length_squared())
			var rootGlobalScaleInv = Vector3.ONE / rootGlobalScale
			var reverseRootTransform = Transform3D(root.global_transform.basis.scaled(rootGlobalScaleInv), root.global_position)
		
			for j in range(arrays[0].size()):
				arrays[0][j] = mesh_instance.global_transform * arrays[0][j] * reverseRootTransform
			
			resultMesh.add_surface_from_arrays(
				arrayMesh.surface_get_primitive_type(i), 
				arrays,
				arrayMesh.surface_get_blend_shape_arrays(i))
			resultMesh.surface_set_material(surfaceNr, arrayMesh.surface_get_material(i))
			resultMesh.surface_set_name(surfaceNr, arrayMesh.surface_get_name(i))
			surfaceNr += 1

func transfer_colliders(current: Node, target: Node) -> bool:
	# todo: reposition necessary?
	var hasCollider = false
	for c in current.get_children():
		if c is StaticBody3D:
			var gxform = c.global_transform
			current.remove_child(c)
			var transformer = Node3D.new()
			target.add_child(transformer)
			var root = get_editor_interface().get_edited_scene_root()
			transformer.owner = root
			transformer.name = "CollisionTransform"
			transformer.global_transform = gxform
			transformer.add_child(c)
			c.transform = Transform3D.IDENTITY
			set_owners(c, root)
			hasCollider = true
		else:
			hasCollider = transfer_colliders(c, target)
	return hasCollider

func set_owners(current: Node, root: Node):
	current.owner = root;
	for c in current.get_children():
		set_owners(c, root)
	
func combine_mesh_recursive(root: Node3D, current: Node3D, resultMesh: Mesh):
	if current is MeshInstance3D:
		combine_mesh(root, current, resultMesh)
	for c in current.get_children():
		combine_mesh_recursive(root, c, resultMesh)

func combine_children_to_mesh(parent: Node3D) -> Mesh:
	for node in parent.get_children():
		if !(node is MeshInstance3D):
			print("children of selected nodes must be of type MeshInstance3D only")
			return null
	
	var root = get_editor_interface().get_edited_scene_root()
	var resultMesh = ArrayMesh.new()
	
	var surfaceNr = 0;
	for node in parent.get_children():
		var mesh_instance = node as MeshInstance3D
		var mesh = mesh_instance.mesh
		if mesh is ArrayMesh:
			var arrayMesh = mesh as ArrayMesh
			for i in range(arrayMesh.get_surface_count()):
				
				var arrays = arrayMesh.surface_get_arrays(i)
				
				var parentGlobalScale = Vector3(parent.global_transform.basis.x.length_squared(),parent.global_transform.basis.y.length_squared(),parent.global_transform.basis.z.length_squared())
				var parentGlobalScaleInv = Vector3.ONE / parentGlobalScale
				var reverseParentTransform = Transform3D(parent.global_transform.basis.scaled(parentGlobalScaleInv), parent.global_position)
			
				for j in range(arrays[0].size()):
					arrays[0][j] = mesh_instance.global_transform * arrays[0][j] * reverseParentTransform
				
				resultMesh.add_surface_from_arrays(
					arrayMesh.surface_get_primitive_type(i), 
					arrays,
					arrayMesh.surface_get_blend_shape_arrays(i))
				resultMesh.surface_set_material(surfaceNr, arrayMesh.surface_get_material(i))
				resultMesh.surface_set_name(surfaceNr, arrayMesh.surface_get_name(i))
				surfaceNr += 1
	return resultMesh

func create_new_mesh_instance(baseNode: Node3D, mesh: Mesh) -> MeshInstance3D:
	var meshInst = MeshInstance3D.new()
	baseNode.get_parent().add_child(meshInst)
	var root = get_editor_interface().get_edited_scene_root()
	meshInst.owner = root
	meshInst.name = baseNode.name
	meshInst.mesh = mesh
	meshInst.transform = baseNode.transform
	return meshInst
	

func create_new_node_instance(parent: Node3D, transform: Transform3D, name: String):
	var node = Node3D.new()
	parent.add_child(node)
	var root = get_editor_interface().get_edited_scene_root()
	node.owner = root
	node.name = name
	node.transform = transform
	return node
