# res://Script/WorldManager.gd
# AutoLoad
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
    # _build_world() # 构建世界，并填充active_agents列表


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
        print("\n--- Tick ", game_time.total_ticks, " (", game_time.time_to_string(), ") ---")
    
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

func build_world():
    pass

# --- 公共API (Public API) ---



# --- 注册函数 (由WorldBuilder调用) ---

func register_entity(entity: Entity):
    if not active_entities.has(entity.entity_id):
        active_entities[entity.entity_id] = entity
        # 如果实体是Agent，也注册到 agets 列表
        if entity.has_component("AgentComponent"):
            active_agents[entity.entity_id] = entity
    else:
        printerr("WorldManager: Entity ID '", entity.entity_id, "' already exists.")

func register_location(location: Location):
    if not active_locations.has(location.location_id):
        active_locations[location.location_id] = location
        # 将地点节点加为子节点，以便 get_node 能找到
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

# --- 获取函数 ---

#！！！注意了！！！
# 根据ID获取其节点引用。任何对返回实体的“写入”或“修改”操作，
# 都必须通过 WorldExecutor 来完成

# 如果找到，返回 Entity 节点；否则返回 null。

func get_entity_by_id(entity_id: String) -> Entity:
    if active_entities.has(entity_id):
        return active_entities[entity_id]
    

    if active_agents.has(entity_id):
        return active_agents[entity_id]
        
    printerr("WorldManager: Entity with ID '", entity_id, "' not found.")
    return null

func get_task_by_id(task_id: String) -> Task:
    if active_tasks.has(task_id):
        return active_tasks[task_id]
    
    printerr("WorldManager: Task with ID '", task_id, "' not found.")
    return null

func get_location_by_id(location_id: String) -> Location:
    # 现在从字典中查找
    if active_locations.has(location_id):
        return active_locations[location_id]
        
    printerr("WorldManager: Location with ID '", location_id, "' not found.")
    return null

func get_path_by_id(path_id: String) -> Path:
    if active_paths.has(path_id):
        return active_paths[path_id]
    
    printerr("WorldManager: Path with ID '", path_id, "' not found.")
    return null