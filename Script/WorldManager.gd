# res://Script/WorldManager.gd
# AutoLoad
#
# --- 核心职责 (Core Responsibilities) ---
# 1. 状态容器 (State Container):
#    - 持有游戏中所有激活的实体(Entities)、特工(Agents)、任务(Tasks)、地点(Locations)的引用。
#    - 提供通过ID快速查找这些游戏对象的公共API (e.g., get_entity_by_id)。
#    - 是游戏世界当前状态的唯一真实来源 (Single Source of Truth)。
#
# 2. 主循环驱动者 (Main Loop Driver):
#    - 负责驱动游戏世界的模拟，以tick为单位推进时间。
#    - 在每个tick中，按顺序触发agent的决策检查 (_simulation_loop)。
#    - 管理模拟的开始、暂停和停止。
#
# --- 设计原则 ---
# - "读"操作的中心: 其他系统通过WorldManager来查询和了解世界状态。
# - "写"操作的发起者: 它不直接修改世界状态的细节，而是通过调用其他系统
#   (如LLMControlComponent, WorldExecutor)来发起状态变更。

extends Node
# --- 核心数据 ---
var game_time: GameTime

var active_entities: Dictionary = {}
# key: entity_id, value: entity_node
# 存储所有需要更新的实体，除了agent，那些拥有task的实体也在这里

var active_agents: Dictionary = {}
# key: agent_id, value: agent_node
# 存储所有需要决策的agent，实际上agent也是一个实体。

var active_tasks: Dictionary = {}
# key: task_id, value: task_node
# 存储所有需要执行的任务

var active_paths: Dictionary = {}
# key: path_id, value: Path Resource
# 存储所有路径

var active_locations: Dictionary = {}
# key: location_id, value: location_node
# 存储所有需要更新的地点

# --- 模拟控制 ---
@export var ticks_per_second: int = 1 # 每秒模拟多少个游戏tick(分钟)
# var tick_timer: Timer # 我们不再需要Timer了

# 新增一个变量来控制主循环的运行
var is_simulation_running: bool = false

func _ready():
	#TODO：从存档中加载游戏时间
	game_time = GameTime.new()
	if typeof(WorldBuilder) != TYPE_NIL:
		WorldBuilder.build_world_from_save_data()
	else:
		print("WorldManager: WorldBuilder singleton not available or running in editor.")


func start_simulation():
	if is_simulation_running:
		return # 防止重复启动
	
	is_simulation_running = true
	print("--- Simulation Started (Turn-Based) ---")
	
	# 启动手动控制的主循环
	_simulation_loop()

func pause_simulation():
	is_simulation_running = false
	print("--- Simulation Paused ---")

# --- 主循环 (手动控制) ---
func _simulation_loop():
	# 只要模拟在运行，就一直循环
	while is_simulation_running:
		
		# --- 1. 推进时间 ---
		game_time.advance_ticks(game_time.TICKS_PER_MINUTE)
		print("--- Tick ", game_time.total_ticks, " (", game_time.time_to_string(), ") ---")
	
		# --- 2. 更新所有实体状态 ---
		for entity_id in active_entities:
			var entity = active_entities[entity_id]
			if is_instance_valid(entity):
				entity.update_per_tick(game_time.TICKS_PER_MINUTE)
		
		# --- 3. 依次检查并执行Agent决策 (核心串行逻辑) ---
		for agent_id in active_agents:
			var agent = active_agents[agent_id]
			if not is_instance_valid(agent): continue
			
			# a. 检查是否需要中断
			var interrupt_result = agent.get_component("DecisionArbiterComponent").check_if_interrupt_is_needed(agent)
			
			# b. 如果需要，则等待其决策完成
			if interrupt_result.interrupt:
				if agent.has_component("LLMControlComponent"):
					# 使用 await！主循环会在这里暂停，直到这个agent的整个决策流程走完
					await agent.get_component("LLMControlComponent").begin_decision_cycle(interrupt_result.reason)
				# (可以为PlayerControlComponent添加类似逻辑)
		
		# --- 4. 模拟tick之间的延迟 (可选) ---
		# 如果你希望在两个tick之间有一个短暂的现实世界延迟，可以取消下面的注释
		# await get_tree().create_timer(1.0 / ticks_per_second).timeout
		
		# 允许Godot处理一帧的渲染和输入，防止无限循环导致游戏卡死
		await get_tree().process_frame


# --- 注册/注销 函数 ---
func register_entity(entity: Entity):
	if not active_entities.has(entity.entity_id):
		active_entities[entity.entity_id] = entity
		if entity.has_component("AgentComponent"):
			active_agents[entity.entity_id] = entity
		# 在纯ID模式下，实体成为WorldManager的子节点
		add_child(entity)
	else:
		printerr("WorldManager: Entity ID '", entity.entity_id, "' already exists.")

func unregister_entity(entity_id: String):
	if active_entities.has(entity_id):
		if active_agents.has(entity_id):
			active_agents.erase(entity_id)
		active_entities.erase(entity_id)

func register_location(location: Location):
	if not active_locations.has(location.location_id):
		active_locations[location.location_id] = location
		add_child(location)
	else:
		printerr("WorldManager: Location ID '", location.location_id, "' already exists.")

func register_task(task: Task):
	if not active_tasks.has(task.task_id):
		active_tasks[task.task_id] = task
	else:
		printerr("WorldManager: Task ID '", task.task_id, "' already exists.")

func unregister_task(task_id: String):
	if active_tasks.has(task_id):
		active_tasks.erase(task_id)

func register_path(path_id: String, path_resource: Path):
	if not active_paths.has(path_id):
		active_paths[path_id] = path_resource
	else:
		printerr("WorldManager: Path ID '", path_id, "' already exists.")

# --- 获取函数 (Getters) ---

#！！！注意了！！！
# 根据ID获取其节点引用。任何对返回实体的“写入”或“修改”操作，
# 都必须通过 WorldExecutor 来完成

# 如果找到，返回 Entity 节点；否则返回 null。

func get_entity_by_id(entity_id: String) -> Entity:
	return active_entities.get(entity_id, null)

func get_task_by_id(task_id: String) -> Task:
	if active_tasks.has(task_id):
		return active_tasks[task_id]
	
	printerr("WorldManager: Task with ID '", task_id, "' not found.")
	return null

func get_location_by_id(location_id: String) -> Location:
	return active_locations.get(location_id, null)
	
func get_path_by_id(path_id: String) -> Path:
	if active_paths.has(path_id):
		return active_paths[path_id]
	
	printerr("WorldManager: Path with ID '", path_id, "' not found.")
	return null

func get_container_node_by_id(id: String):
	"""
	智能查找函数，返回一个可以作为容器的节点 (实体或地点)。
	"""
	var entity = get_entity_by_id(id)
	if is_instance_valid(entity) and entity.has_component("ContainerComponent"):
		return entity # 它是一个容器实体
	
	var location = get_location_by_id(id)
	if is_instance_valid(location):
		return location # 它是一个地点

	printerr("WorldManager: Could not find a valid container node with ID '", id, "'.")
	return null