# res://Script/World/Component/ContainerComponent.gd
extends Node
class_name ContainerComponent

# --- 核心属性 ---
@export var capacity_volume: float = 10.0 # 容器能容纳的总“体积”
@export var is_transparent: bool = false # 容器内的物品是否对外界可见
@export var access_rule: Dictionary = {"open": true, "requires_key": "000000", "locked": false} # 访问规则: "open", "requires_key", "locked"
@export var accepted_tags: PackedStringArray = [] # 只接受带有特定标签的物品 (空数组=接受所有)

# --- 内部状态 ---
var contained_entities: Dictionary = {} # key: entity_id, value: Entity node

# ↓ 这个应该是实时计算的，弃用
# var current_contained_volume: float = 0.0

# 容器名称和描述
var container_name: String = ""
var container_description: String = ""

