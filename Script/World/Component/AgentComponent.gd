class_name AgentComponent
extends Node


# ==============================================================================
# 对应 Prompt/Character/highlevel.txt 中的占位符
# 这个组件用于存储Agent的核心身份、性格和长期记忆等相对静态的数据。
# ==============================================================================


# --- [身份与性格] ---
# 这些是角色的基础信息，通常在创建后不会改变。

# 对应 {agent_name}
var agent_name: String = "默认名字"
# 对应 {agent_gender}
var agent_gender: String = "未指定" # e.g., "男", "女", "无性"
# 对应 {agent_race}
var agent_race: String = "人类"
# 对应 {agent_age}
var agent_age: int = 25
var agent_backstory: String = "一段关于角色过去的背景故事。"
# 对应 {personality_summary}
var personality_summary: String = "一个对世界充满好奇心的探险家。"
# 对应 {trait_list}
#var trait_list: Array[String] = ["勇敢", "善良", "有点冒失"]
var agent_preferences: String = "喜欢在晴朗的日子里探索，不喜欢阴暗的洞穴。"


# --- [常识] ---
# 角色通过学习和经历获得的通用知识。

# 对应 {common_knowledge_summary}
var common_knowledge_summary: String = "知道基础的生存技能，了解王国的基本历史。"


# --- [记忆与规划] ---
# 这些是角色的动机和行动指南，会随着游戏进程缓慢更新。
# (这部分是动态的，不会在这里初始化)

# --- 新增：上下文提供函数 ---
func get_identity_context() -> Dictionary:
    """
    收集所有与此Agent身份、性格和记忆相关的上下文，并返回一个字典。
    """
    var context = {}
    
    # [身份与性格] & [常识]
    context["agent_name"] = self.agent_name
    context["agent_gender"] = self.agent_gender
    context["agent_race"] = self.agent_race
    context["agent_age"] = self.agent_age
    context["personality_summary"] = self.personality_summary
    context["common_knowledge_summary"] = self.common_knowledge_summary
    
    # [记忆与规划] (目前为占位符)
    context["long_term_goals"] = "TODO: Implement long term goals from memory."
    context["daily_plan"] = "TODO: Implement daily plan from memory."
    context["reflection_summary"] = "TODO: Implement reflection summary from memory."
    context["recent_events_log"] = "TODO: Implement recent events log from memory."
    
    return context