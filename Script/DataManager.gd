# res://Script/DataManager.gd
# AutoLoad

#等着重写吧！全部重写！嘻嘻！

extends Node

# 用于存储所有加载的实体模板数据
var entity_templates: Dictionary = {}
var recipe_db: Dictionary = {}

func _ready():
    # 游戏一启动就加载数据
    _load_all_data()

func _load_file(path: String) -> Dictionary:
    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        printerr("Failed to open data file: ", path)
        return {}
    
    var content = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var error = json.parse(content)
    if error != OK:
        printerr("JSON Parse Error in '", path, "': ", json.get_error_message(), " at line ", json.get_error_line())
        return {}
    
    return json.get_data()

func _load_all_data():
    print("DataManager: Loading all data...")
    # --- 加载实体模板 ---
    var item_data = _load_file("res://Data/Entities/items.json") # 注意路径修正
    entity_templates.merge(item_data, true) 

    var character_data = _load_file("res://Data/Entities/characters.json")
    entity_templates.merge(character_data, true)
    
    print("DataManager: ", entity_templates.size(), " entity templates loaded.")

    # --- 加载交互配方 ---
    recipe_db = _load_file("res://Data/Recipes.json")
    print("DataManager: ", recipe_db.size(), " recipes loaded.")

# 提供一个公共接口来获取模板数据
func get_entity_template(template_id: String) -> Dictionary:
    if entity_templates.has(template_id):
        return entity_templates[template_id]
    
    printerr("DataManager: Template not found for ID: ", template_id)
    return {}

# 新增：提供获取所有配方的接口
func get_all_recipes() -> Dictionary:
    return recipe_db