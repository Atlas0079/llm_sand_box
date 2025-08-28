# res://entities/components/ai_control_component.gd
extends Node
class_name LLMControlComponent

# --- 引用核心模块 (未来通过依赖注入或单例获取) ---
var perception_system: Node # 负责感知周围环境
var memory_system: Node     # 负责RAG和长期记忆
# var task_engine: Node       # 负责解释和执行动词  // 已弃用：直接使用 Autoload InteractionEngine

# --- 内部状态 ---
var is_deciding: bool = false # 防止在一次决策完成前重复触发
var last_decision_reason: String = ""

# --- Agent自身的引用 ---
var parent_entity: Entity
var agent_comp: AgentComponent
var creature_comp: CreatureComponent
var effect_comp: EffectComponent
var perception_comp: PerceptionComponent

# 新增的初始化方法，由 Entity.add_component 调用
func set_parent_entity(p_entity: Entity):
	self.parent_entity = p_entity
	# 在这里安全地获取其他组件的引用
	agent_comp = parent_entity.get_component("AgentComponent")
	creature_comp = parent_entity.get_component("CreatureComponent")
	effect_comp = parent_entity.get_component("EffectComponent")
	perception_comp = parent_entity.get_component("PerceptionComponent")

func _ready():
	# _ready 仍然可以用来做其他初始化，但获取引用的工作被移走了
	pass


# ==============================================================================
# 核心入口：被WorldManager调用
# ==============================================================================
func begin_decision_cycle(reason: String):
	if is_deciding:
		print(parent_entity.entity_name, " is already deciding. Ignoring new request.")
		return

	is_deciding = true
	last_decision_reason = reason
	print("--- ", parent_entity.entity_name, " begins decision cycle. Reason: ", reason, " ---")

	# 启动并等待整个决策管道完成
	await _run_strategic_phase()

# (继续在 AIControlComponent.gd 中)

# --- 决策管道 ---

# 阶段一：战略思考 (高级LLM)
func _run_strategic_phase():
	# 1. 收集高级上下文
	var context = _gather_strategic_context()
	
	# 2. 异步调用高级LLM
	var prompt_messages = _create_strategic_prompt(context)
	var llm_response_str = await LLMClient.request_blocking(prompt_messages, "gpt-4o-mini", 0.7) 

	if llm_response_str.begins_with("ERROR:"):
		printerr("High-Level LLM failed. Details: ", llm_response_str)
		_end_decision_cycle()
		return

	# 3. 使用新的健壮方法解析LLM返回的JSON
	var parse_result = _extract_json_from_string(llm_response_str)
	if parse_result == null:
		printerr("High-Level LLM returned invalid or non-extractable JSON. Response: ", llm_response_str)
		_end_decision_cycle()
		return
		
	var llm_decision = parse_result
	var thought = llm_decision.get("thought", "LLM did not provide a thought.")
	var high_level_goal = llm_decision.get("action", "")

	if high_level_goal.is_empty():
		print("High-Level LLM failed to provide a goal action.")
		_end_decision_cycle()
		return

	print("LLM Thought: '", thought, "'")
	print("Strategic Goal: '", high_level_goal, "'")
	
	# 4. 进入并等待下一阶段
	await _run_tactical_phase(high_level_goal)


# 阶段二：战术分解 (低级LLM)
func _run_tactical_phase(strategic_goal: String):
	# 1. 收集精确的战术上下文
	var context = _gather_tactical_context(strategic_goal)

	# 2. 异步调用低级LLM (LLMClient 现在是单例)
	var prompt_messages = _create_tactical_prompt(context)
	# 模型可以根据需求选择更小、更快的模型
	var action_sequence_json = await LLMClient.request_blocking(prompt_messages, "gpt-4o-mini", 0.5)

	if action_sequence_json.begins_with("ERROR:"):
		print("Low-Level LLM failed to generate action sequence. Details: ", action_sequence_json)
		_end_decision_cycle()
		return

	var parse_result = JSON.parse_string(action_sequence_json)
	if parse_result == null:
		print("Low-Level LLM returned invalid JSON. Response: ", action_sequence_json)
		_end_decision_cycle()
		return
		
	var action_sequence = parse_result

	if action_sequence.is_empty():
		print("Low-Level LLM failed to generate action sequence.")
		_end_decision_cycle()
		return

	print("Tactical Sequence: ", action_sequence)
	# 3. 进入并等待下一阶段
	await _run_execution_phase(action_sequence)


# 阶段三：执行
#现在已经没有TaskEngine了，这里我要记得改改
func _run_execution_phase(action_sequence: Array):
	# 遍历并执行Action序列（直接使用 Autoload 的 InteractionEngine）
	for action in action_sequence:
		var result = InteractionEngine.process_command(parent_entity, action)
		if result.get("status") == "failed":
			print("Action failed: ", action, " Reason: ", result.get("message"))
			break

	# 决策循环结束
	_end_decision_cycle()


# 阶段四：收尾
func _end_decision_cycle():
	print("--- ", parent_entity.entity_name, " ends decision cycle. ---")
	is_deciding = false

# --- 上下文与Prompt构建器 ---
func _gather_strategic_context() -> Dictionary:
	var context = {}
	
	# 1. 获取最基础的组件引用
	var world = get_tree().get_root().get_node("WorldManager")

	# 2. 从各个专家组件收集上下文，并合并

	#状态信息在生物组件那添加过了
	context.merge(agent_comp.get_identity_context(), true)
	context.merge(creature_comp.get_vitals_context(), true)
	context.merge(perception_comp.get_environment_context(), true)

	# 3. 添加决策周期特有的瞬时信息
	context["current_time_formatted"] = world.game_time.time_to_string()
	context["interrupt_reason"] = last_decision_reason

	return context


func _create_strategic_prompt(context: Dictionary) -> Array:
	var template_path = "res://Prompt/Character/highlevel.txt"
	var file = FileAccess.open(template_path, FileAccess.READ)
	if not file:
		printerr("Failed to load prompt template: ", template_path)
		return []
	
	var template_text = file.get_as_text()
	file.close()

	# 新逻辑：从上下文中提取出中断原因，作为 "user" prompt
	# 使用 Godot 4 的 get/erase 组合来替代旧的 pop()
	var user_prompt_content = context.get("interrupt_reason", "你正处于空闲状态，决定下一步要做什么")
	context.erase("interrupt_reason")

	# 替换所有占位符，剩下的内容将成为 "system" prompt
	for key in context.keys():
		template_text = template_text.replace("{" + key + "}", str(context[key]))

	# 构建最终的prompt
	return [
		# 大部分上下文现在是系统提示词，为AI设定场景和角色
		{"role": "system", "content": template_text},
		# 用户提示词现在只是触发决策的原因
		{"role": "user", "content": user_prompt_content}
	]

func _gather_tactical_context(strategic_goal: String) -> Dictionary:
	# 这是为低级LLM准备的“技术手册”
	var context = {}
	context["goal"] = strategic_goal
	
	# 1. 自身的可用动词
	# context["personal_verbs"] = _get_own_supported_verbs()

	# 2. 周围可交互的实体及其动词
	# context["interactable_entities"] = perception_system.get_tactical_details(parent_entity)
	
	return context

func _create_tactical_prompt(context: Dictionary) -> Array:
	var system_prompt = """
You are the tactical execution part of an AI. Your task is to break down a high-level goal into a sequence of concrete actions.
You must respond with a valid JSON array of action objects. Each object must have a "verb" and a "target_id".
Example: [{"verb": "MoveTo", "target_id": "well_01"}, {"verb": "Drink", "target_id": "self"}]

Available verbs and targets will be provided in the context. If you don't have enough information, you can respond with an empty array [].
"""
	var user_prompt = "My goal is: '" + context.get("goal", "") + "'.\n"
	user_prompt += "Here is the detailed tactical context:\n" + JSON.stringify(context, "  ")
	
	return [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_prompt}
	]

# --- 新增的辅助函数 ---

# 新增：健壮的JSON提取函数
func _extract_json_from_string(text: String) -> Variant:
	# 寻找第一个 '{' 和最后一个 '}'
	var first_brace = text.find("{")
	var last_brace = text.rfind("}")

	# 如果没有找到花括号，或者顺序不正确，则无法提取
	if first_brace == -1 or last_brace == -1 or last_brace < first_brace:
		return null

	# 提取可能的JSON子字符串
	var json_substring = text.substr(first_brace, last_brace - first_brace + 1)

	# 尝试解析提取出的子字符串
	var result = JSON.parse_string(json_substring)
	
	# 如果解析失败，返回null；成功则返回解析后的数据
	return result

func _get_resource_description(current: float, max_val: float, low_desc: String, mid_desc: String, high_desc: String) -> String:
	var percentage = current / max_val
	if percentage < 0.25:
		return low_desc
	elif percentage < 0.75:
		return mid_desc
	else:
		return high_desc