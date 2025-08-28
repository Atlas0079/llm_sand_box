# res://entities/entity.gd
extends Node
class_name Entity

# --- 核心属性 ---
var entity_id: String
var entity_name: String = "Unnamed Entity"

var volume: float = 1.0   # 物体的"大小"，用于容器计算
var weight: float = 1.0   # 物体的"重量"，用于角色负重计算

# --- 组件管理系统 ---
# 使用字典存储组件引用，key是组件类型名，value是组件实例
#
#这个组件是实体（Entity）的内部组成部分。
#现在增删组件是由builder（初始化时）和WorldExecutor（运行时）完成
var components: Dictionary = {}

# _ready() 函数在节点及其子节点都进入场景树时被调用
func _ready():
	pass

# --- 组件管理方法 ---

func add_component(component_instance: Node, component_name: String):
	"""
	统一的组件添加方法。
	将组件加为子节点，并注册到字典中。
	"""
	if not component_instance is Node:
		printerr("Component '", component_name, "' is not a Node and cannot be added as a child.")
		return

	if components.has(component_name):
		printerr("Component '", component_name, "' already exists on entity '", self.entity_name, "'.")
		return

	# 关键步骤 1: 注册到字典
	components[component_name] = component_instance
	# 关键步骤 2: 加为子节点
	add_child(component_instance)
	
	# (可选但推荐) 步骤 3: 明确告知组件它的父实体是谁
	if component_instance.has_method("set_parent_entity"):
		component_instance.set_parent_entity(self)

func get_component(component_type: String):
	"""获取指定类型的组件"""
	return components.get(component_type, null)

func has_component(component_type: String) -> bool:
	"""检查是否拥有指定类型的组件"""
	return components.has(component_type)



# --- 便捷的组件访问方法 ---
# 这些方法提供了类型安全的组件访问，避免了直接操作components字典

func get_tag_component() -> TagComponent:
	"""获取TagComponent，如果不存在返回null"""
	return get_component("TagComponent") as TagComponent

func get_container_component() -> ContainerComponent:
	"""获取ContainerComponent，如果不存在返回null"""
	return get_component("ContainerComponent") as ContainerComponent

func get_creature_component() -> CreatureComponent:
	"""获取CreatureComponent，如果不存在返回null"""
	return get_component("CreatureComponent") as CreatureComponent

func get_effects_component():
	"""获取EffectsComponent，如果不存在返回null"""
	return get_component("EffectsComponent")

# --- 标签系统的便捷方法 ---
# 这些方法封装了对TagComponent的访问，保持了向后兼容性
func has_tag(tag_name: String) -> bool:
	var tag_component = get_tag_component()
	if not is_instance_valid(tag_component): return false
	return tag_component.has_tag(tag_name)

func add_tag(tag_name: String):
	var tag_component = get_tag_component()
	if is_instance_valid(tag_component):
		tag_component.add_tag(tag_name)

func remove_tag(tag_name: String):
	var tag_component = get_tag_component()
	if is_instance_valid(tag_component):
		tag_component.remove_tag(tag_name)

func get_all_tags() -> PackedStringArray:
	var tag_component = get_tag_component()
	if not is_instance_valid(tag_component): return []
	return tag_component.get_tags()

# --- 核心更新逻辑 ---
func update_per_tick(ticks_per_minute: int):
	"""
	这个函数由WorldManager在每个模拟tick调用。
	它会遍历所有组件，并调用它们的update_per_tick方法（如果存在）。
	"""
	for component in components.values():
		if component.has_method("update_per_tick"):
			component.update_per_tick(ticks_per_minute)

# --- 调试和开发工具 ---
func print_components():
	"""打印所有已注册的组件（用于调试）"""
	print("Entity '", entity_name, "' components:")
	for component_type in components.keys():
		print("  - ", component_type)