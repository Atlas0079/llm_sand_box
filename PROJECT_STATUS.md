### 项目现状总览

- **总体结论**：当前为“框架已搭、流程骨架清晰，但不可运行的原型（MVP-未贯通）”。核心系统（世界模型、组件体系、决策管线、交互/任务、时间系统）基本到位，但数据层与若干接口未落地，导致无法形成可见行为。

## 已完成（可复用的骨架）

- **AutoLoad 单例**：`project.godot` 已挂载 `DataManager`、`WorldManager`、`LLMClient`、`DatabaseClient`、`WorldExecutor`、`InteractionEngine`。
- **世界模型基础**：`Entity.gd`、`Task.gd`（Resource）、`Location.gd`（Node2D）、`Path.gd`（Resource）、`GameTime.gd`（Resource）。
- **组件体系雏形**：`AgentComponent`、`CreatureComponent`、`PerceptionComponent`、`EffectComponent`、`TaskComponent`、`WorkerComponent`、`DecisionArbiterComponent` 等。
- **AI 决策管线（LLM）**：`LLMControlComponent.gd` 已实现“战略→战术→执行”三段式，并通过 `InteractionEngine` 下发动作。
- **交互与任务链路（雏形）**：`InteractionEngine.gd` 具备“匹配配方→消耗输入→瞬时或持续任务”的流程；`WorkerComponent.gd` 会在 tick 中推进任务进度并触发收尾效果。
- **世界构建（地点/路径）**：`WorldBuilder.gd` 可从 `Data/Locations.json` 构建 `Location` 与 `Path` 并注册到 `WorldManager`。
- **向量数据库服务（原型）**：`Script/LLMRelated/vector_database_server/` 提供 FastAPI 程序与 Chroma 后端实现文件。
- **LLM 测试**：`Scene/llmtest.tscn` + `Script/Test/TestLLM.gd` 可演示一次补全调用（依赖外部 API）。

## 明显问题（会导致运行失败或逻辑不通）

- **DataManager API 严重缺失/路径错误**
	- `InteractionEngine._ready()` 需要 `DataManager.get_all_recipes()`，未实现。
	- `EffectComponent.add_condition()` 需要 `DataManager.get_condition_template(id)`，未实现。

- **世界未被真正构建**
	- `WorldManager.build_world()` 为空；未创建/注册任何实体，`active_agents` 为空，主循环即便启动也不会有决策发生。
	- `WorldBuilder` 仅构建地点/路径，未构建实体与组件（缺少“从数据定义实体+挂载组件”的流程）。
- **组件访问方式不一致（潜在崩溃点）**
	- 代码混用 `get_component("XxxComponent")` 与 `find_child("XxxComponent")`。当前 `Entity.gd` 仅维护 `components` 字典，且没有统一的“挂载组件→注册字典”的实现，导致：
		- `WorldExecutor._execute_create_entity()` 访问 `InventoryComponent`，但项目未提供该组件脚本。
		- `InteractionEngine` 的背包接口（`count_item`/`remove_item`）并不存在。
- **API/数据结构不匹配**
	- `PerceptionComponent._format_connections()` 调用 `location.get_all_paths()`，而 `Location.gd` 仅有 `get_all_path_ids()`；且 `connections` 存的是 `path_id -> target_location_id`，感知逻辑期望 `Path` 对象数据（含 `path_name`、`travel_time`）。
	- `PerceptionComponent._get_entity_status_summary()` 访问 `task_comp.assigned_task_ids`，`TaskComponent.gd` 无此字段。
	- `InteractionEngine._handle_duration_interaction()` 向 `Task` 赋 `on_completion_effects`，`Task.gd` 未定义该属性（完成效果已由 `WorldExecutor._execute_finish_task()` 从 `recipe.completion_effects` 读取）。
	- `WorldExecutor._execute_create_entity()` 调用 `WorldManager.create_entity()` 与 `agent.get_location()`，均未实现。
- **LLM 提示词与实现不一致**
	- `Prompt/Character/lowlevel.txt` 约定输出为包含 `thought` 与 `actions` 的 JSON 对象；`LLMControlComponent._run_tactical_phase()` 则期望直接得到“动作数组”。二者需要统一。
	- `highlevel.txt` 中 `{available_verbs_description}` 未由上下文提供。
- **LLM 客户端与安全性**
	- `LLMClient.gd` 硬编码了 API URL 与 TOKEN（应改为配置/环境变量）。注释中“阻塞会冻结游戏”的说法与 Godot `await` 行为不一致。
	- `TestLLM.gd` 手动 `new()` 并 `add_child(LLMClient)`，但 `LLMClient` 已作为 AutoLoad，存在重复实例化反模式。
- **向量数据库服务端/客户端不匹配（不可用）**
	- 服务器 `main.py` 引用 `FaissBackend`，仓库未提供 `faiss_backend.py`（仅有 `chroma_backend.py`）。
	- Pydantic 模型字段缺失：
		- `AddRequest` 未定义 `agent_id`，但服务实现需要写入到 `metadata["agent_id"]`。
		- `SearchRequest` 未包含 `agent_id` 与 `current_game_time`，而 `DatabaseClient.gd` 会发送它们且后端应按 `agent_id` 过滤更新。
	- `requirements.txt` 缺少 `chromadb` 依赖。
- **UI 与游戏循环未打通**
	- `Scene/root.tscn` 为静态 UI，未在入口脚本中触发 `WorldBuilder.build_world_from_data()`、`WorldManager.start_simulation()`。

## 待实现与优先级建议

- **P0（打通最小可运行链路）**
	- 实现 `DataManager` 最小接口：
		- 修正数据路径为 `res://Data/...`。
		- 补 `get_all_recipes()`（交互配方）、`get_condition_template(id)`（状态/特质模板）。
		- 临时提供最小配方与条件 JSON，先让 `InteractionEngine` 与 `EffectComponent` 可用。
	- `WorldBuilder` 增加“从数据创建实体并挂载组件”的流程：
		- 统一“组件作为子节点 + 在 `Entity` 内注册到 `components` 字典”的规范；后续统一使用 `get_component("XxxComponent")`，移除 `find_child` 依赖。
	- 在 `WorldManager.build_world()` 调用 `WorldBuilder.build_world_from_data()` 并注册至少一个带 `AgentComponent` + `LLMControlComponent` 的实体，确保 `active_agents` 非空。
	- 修复 `PerceptionComponent`：
		- 新增 `Location.get_all_paths()` 或在感知中用 `get_all_path_ids()` + `WorldManager.get_path_by_id()` 组装所需结构。
		- 用 `TaskComponent.get_all_tasks()` 或 `WorkerComponent.has_task()` 判断是否“正在执行任务”，避免引用不存在字段。
	- 修复 `InteractionEngine/_Task`：
		- 移除对 `new_task.on_completion_effects` 的赋值（完成效果已经在 `WorldExecutor._execute_finish_task()` 中处理）。
	- 暂缓“物品消耗/背包”：
		- 将 `_check_and_consume_inputs()` 改为“只检查、不消耗”，或补 `InventoryComponent` 最小占位（仅 `count_item`/`remove_item`）。
	- 统一 LLM 低层输出与解析：
		- 二选一：调整低层提示词输出为“动作数组”，或修改解析以兼容 `{"thought":..., "actions":[...]}`。
	- `LLMClient` 配置化：
		- 移除硬编码 Token，改为 `ProjectSettings` 或环境变量；测试脚本改用 AutoLoad 实例。

- **P1（RAG/记忆服务可用）**
	- 修复 Python 服务：
		- 采用 `ChromaBackend`（开发友好），并在 `main.py` 中实例化它。
		- Pydantic 模型补全字段：`AddRequest` 加 `agent_id`，`SearchRequest` 加 `agent_id` 与可选 `current_game_time`。
		- `requirements.txt` 增加 `chromadb`。
	- 对齐 `DatabaseClient.gd` 与后端字段名与返回结构（`/search` 返回 `{results:[...]}` 已与客户端包装兼容）。

- **P2（玩法与稳定性）**
	- `WorldExecutor`：
		- 去掉对未实现接口（`WorldManager.create_entity()`、`agent.get_location()`）的依赖，或补齐实现。建议运行时仅修改状态/归属，实体在构建期创建。
	- `CreatureComponent.recalculate_all_capacities()` 对接 `EffectComponent.get_capacity_modifiers()`，让状态真正影响能力值。
	- `highlevel.txt` 的 `{available_verbs_description}` 由 `LLMControlComponent` 汇总提供（来自 `PerceptionComponent` 或数据定义）。
	- 为 `Scene/root.tscn` 绑定入口脚本：构建世界、启动模拟、显示基本日志。

## 专业术语与规范建议

- **组件访问统一**：固定使用 `get_component("XxxComponent")`，避免 `find_child()`。
- **数据驱动与 Schema**：将实体、组件与配方的 JSON Schema 固化在 `Data/Schemas/`，由 `DataManager` 统一解析。
- **配置与安全**：密钥走环境变量或 `ProjectSettings`，不要硬编码在脚本中。

## 你现在做到哪里了

- **架构层面**：核心系统骨架齐全，连线思路清晰（`WorldManager` 串行仲裁 → `LLMControlComponent` 两段式推理 → `InteractionEngine` 执行）。
- **运行层面**：因数据层 API、世界构建、组件访问统一、服务端字段对齐未完成，暂未形成“可见行为”。

## 建议的下一步

- 先完成 P0 清单：`DataManager` 最小实现 → 统一组件访问 → 修复感知/交互不匹配 → `WorldManager.build_world()` 落地一个最小 Agent → 跑通一次完整决策循环。 