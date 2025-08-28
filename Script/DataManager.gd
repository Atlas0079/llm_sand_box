# res://Script/DataManager.gd
# AutoLoad

#等着重写吧！全部重写！嘻嘻！

extends Node

# 用于存储所有加载的实体模板数据
var entity_templates: Dictionary = {}

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
    print("DataManager: Loading all entity templates...")
    var item_data = _load_file("res://Data/items.json")
    # 将加载的数据合并到主字典中
    entity_templates.merge(item_data, true) 
    
    # 你可以在这里继续加载其他文件，比如creatures.json
    # var creature_data = _load_file("res://data/creatures.json")
    # entity_templates.merge(creature_data, true)

    print("DataManager: ", entity_templates.size(), " entity templates loaded.")

# 提供一个公共接口来获取模板数据
func get_entity_template(template_id: String) -> Dictionary:
    if entity_templates.has(template_id):
        return entity_templates[template_id]
    
    printerr("DataManager: Template not found for ID: ", template_id)
    return {}