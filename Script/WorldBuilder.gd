# Script/WorldBuilder.gd
extends Node

# 构建世界的入口函数
func build_world_from_data():
    print("--- WorldBuilder: Starting to build world ---")
    
    # 1. 加载地点数据
    var location_data = _load_json("res://Data/Locations.json")
    if location_data.is_empty():
        printerr("WorldBuilder: Failed to load location data.")
        return
        
    # 2. 遍历并创建地点和路径
    for loc_id in location_data:
        var loc_template = location_data[loc_id]
        
        # a. 创建并初始化 Location 节点
        var new_location = Location.new()
        new_location.name = loc_id # 将节点名称设为ID，方便查找
        new_location.initialize_from_data(loc_id, loc_template)
        
        # b. 向 WorldManager 注册 Location 实例
        WorldManager.register_location(new_location)

        # c. 遍历、创建并注册 Path 资源
        if loc_template.has("connections"):
            for path_id in loc_template["connections"]:
                var path_template = loc_template["connections"][path_id]
                
                # 创建 Path 资源
                var new_path = Path.new(
                    path_template.get("name"),
                    path_template.get("target_location"),
                    path_template.get("travel_time", 10),
                    path_template.get("description", ""),
                    path_template.get("conditions", {})
                )
                
                # 向 WorldManager 注册 Path
                WorldManager.register_path(path_id, new_path)
                
                # 告诉 Location 它拥有这个连接
                new_location.add_connection(path_id, new_path.target_location_id)

    print("--- WorldBuilder: World build complete ---")

# 加载JSON文件的辅助函数
func _load_json(path: String) -> Dictionary:
    var file = FileAccess.open(path, FileAccess.READ)
    if not file: return {}
    var data = JSON.parse_string(file.get_as_text())
    return data if data else {} 