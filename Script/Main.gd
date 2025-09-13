extends Node

func _ready():
	# 仅在运行时启动，避免编辑器下误触主循环
	if Engine.is_editor_hint():
		print("Main: Running in editor, simulation not started.")
		return
	
	# 延迟到下一帧启动，确保 WorldBuilder 已完成构建（避免竞态）
	print("Main: Deferring simulation start to next frame...")
	call_deferred("_start_simulation_safely")

func _start_simulation_safely():
	# 再次确认单例存在
	if typeof(WorldManager) == TYPE_NIL:
		printerr("Main: WorldManager singleton not available.")
		return
	
	WorldManager.start_simulation()
	print("Main: Simulation started.")
