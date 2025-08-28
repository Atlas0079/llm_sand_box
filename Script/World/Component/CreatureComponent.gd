# res://entities/components/creature_component.gd
extends Node
class_name CreatureComponent

# --- 1. 基础资源 (Primary Attributes) ---
@export var max_hp: float = 100.0
var current_hp: float

@export var max_nutrition: float = 100.0
var current_nutrition: float

@export var max_energy: float = 100.0
var current_energy: float

var stress: float = 0.0

# --- 3. 核心能力值 (Capacities) - 动态计算！---
#
var capacities: Dictionary = {
    "Manipulation": 1.0, # 1.0 = 100%
    "Moving": 1.0,
    "Consciousness": 1.0
}

# 弃用，疼痛现在被表示为状态
#var pain_level: float = 0.0 # 0.0 to 1.0

# --- 4. 技能 (Skills) ---
var skills: Dictionary = {
    "Crafting": 1,
    "Medicine": 1,
    "Farming": 1,
    "Mining": 1,
    "Woodworking": 1,
    "Cooking": 1,
    "Fishing": 1,
    "Shooting": 1,
    "Trading": 1,
}

# --- 初始化 ---
func _ready():
    current_hp = max_hp
    current_nutrition = max_nutrition
    current_energy = max_energy
    
    # 我们需要一个方法来定期更新状态
    recalculate_all_capacities()

# --- 核心逻辑：动态计算 ---
func recalculate_all_capacities():
    # 这是一个简化的例子，展示了计算流程
    var base_manipulation = 1.0
    var base_moving = 1.0
    var base_consciousness = 1.0
    
    #TODO：这里我需要向该生物的Condition组件获取对应的倍率，最后计算出该生物的实际能力值

    # 根据基础资源调整
    if current_energy < 30:
        base_consciousness -= 0.3
    
    # 最终赋值，操作能力和移动能力不能超过意识
    capacities["Consciousness"] = clampf(base_consciousness, 0.0, 2.0)
    capacities["Moving"] = clampf(base_moving, 0.0, capacities["Consciousness"])
    capacities["Manipulation"] = clampf(base_manipulation, 0.0, capacities["Consciousness"])

    print("Capacities recalculated: ", capacities)

#通过EffectExecutor更新
func update_per_tick(ticks_per_minute: int):
    pass

# --- 新增：上下文提供函数 ---
func get_vitals_context() -> Dictionary:
    """
    收集所有与此生物内在状态相关的上下文（生理+状态效果）。
    """
    var context = {}
    
    # 1. 添加生理状态描述
    context["health_description"] = _get_resource_description(self.current_hp, self.max_hp, "濒临死亡", "受伤", "健康")
    context["nutrition_description"] = _get_resource_description(self.current_nutrition, self.max_nutrition, "极度饥饿", "有点饿", "饱食")
    context["energy_description"] = _get_resource_description(self.current_energy, self.max_energy, "筋疲力尽", "有些疲惫", "精力充沛")
    
    # 2. 从EffectComponent合并状态和特质信息
    var effect_comp = get_parent().get_component("EffectComponent")
    if effect_comp:
        context.merge(effect_comp.get_conditions_context(), true)
    else:
        context["trait_list"] = "无"
        context["status_list"] = "无"
        
    return context

# --- 私有辅助函数 ---
func _get_resource_description(current: float, max_val: float, low_desc: String, mid_desc: String, high_desc: String) -> String:
    var percentage = current / max_val
    if percentage < 0.25:
        return low_desc
    elif percentage < 0.75:
        return mid_desc
    else:
        return high_desc

# --- 5. 提供的“工具”/“动作” (Public API) ---
# 这部分是给控制组件调用的“接口”

func consume(item_entity: Entity):
    pass
