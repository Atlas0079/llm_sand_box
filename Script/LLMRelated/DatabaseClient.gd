# res://Script/LLMRelated/DatabaseClient.gd
# AutoLoad
extends Node

# 该脚本提供了一个客户端，用于和 Python 向量数据库服务器进行交互。
# 它可以处理添加新的文本记忆以及搜索相关的记忆。
#
# 如何使用:
# 1. 将此脚本添加为您场景中的一个节点（例如，一个自动加载的单例）。
# 2. 在检查器中，设置 "Server Base Url"、"Embedding Api Url" 和 "Embedding Api Token"。
#    - Server Base Url: 您的 Python 服务器地址 (例如: "http://127.0.0.1:18191")。
#    - Embedding Api Url: 用于将文本转换为向量的第三方服务的 URL。
#    - Embedding Api Token: 该服务的身份验证令牌。
# 3. 从任何其他脚本中，获取对该节点的引用并调用其公共函数。
#
# 示例:
#
# var db_client = get_node("/root/DatabaseClient")
# var agent_id = "npc_bob"
# var game_time_str = "0001-01-01 12:30:00"
#
# # 添加记忆的示例
# var add_result = await db_client.add_memory("密钥藏在老橡树下。", agent_id, game_time_str, 0.9)
# if add_result.has("error"):
#     print("添加记忆失败: ", add_result.get("details"))
# else:
#     print("记忆添加成功！")
#
# # 搜索记忆的示例
# var search_result = await db_client.search_memory("钥匙在哪？", agent_id, game_time_str, 5)
# if search_result.has("error"):
#     print("搜索失败: ", search_result.get("details"))
# else:
#     print("搜索结果: ", search_result.get("data"))
#


## Python 向量数据库服务器的基础 URL。
@export var server_base_url: String = "http://127.0.0.1:18191"

## 用于生成嵌入向量的第三方 API 的 URL。
@export var embedding_api_url: String = "https://fastapi.aabao.top/v1/embeddings"

## 第三方嵌入 API 的 Bearer Token。
@export var embedding_api_token: String = "sk-FSKFoh6aBuNw8XKJ8gyo1oQ2bCofdcXoFCQXCoQs43B2SpoQ"


# --- 公共函数 ---

## 发送文本到服务器，将其转换为向量并为指定的 agent 存储。
## 可以选择性地提供一个0.0到1.0之间的重要性分数。
## 需要提供一个字符串格式的游戏内创建时间。
## 还可以指定记忆类型，如 "normal" 或 "reflection"。
func add_memory(text: String, agent_id: String, created_time: String, importance: float = 0.5, memory_type: String = "normal") -> Dictionary:
	var endpoint = "/add"
	var body = {
		"text": text,
		"agent_id": agent_id,
		"created_time": created_time,
		"importance": importance,
		"memory_type": memory_type,
		"api_token": embedding_api_token
	}
	return await _make_request(endpoint, body)


## 在指定 agent 的记忆中搜索与给定文本相关的条目。
## 需要提供当前的字符串格式的游戏内时间，用于更新被调用记忆的访问时间。
func search_memory(text: String, agent_id: String, current_game_time: String, k: int = 5) -> Dictionary:
	var endpoint = "/search"
	var body = {
		"text": text,
		"agent_id": agent_id,
		"current_game_time": current_game_time,
		"k": k,
		"api_token": embedding_api_token
	}
	var result = await _make_request(endpoint, body)
	
	if "data" in result:
		return { "data": result.data.get("results", []) }
	else:
		return result


# --- 私有辅助函数 ---

# 用于处理 HTTP POST 请求的内部函数。
func _make_request(endpoint: String, body: Dictionary) -> Dictionary:
	var http_request = HTTPRequest.new()
	add_child(http_request) # 该节点必须在场景树中才能发出请求。

	var url = "%s%s" % [server_base_url, endpoint]
	var headers = ["Content-Type: application/json"]
	var request_body_json = JSON.stringify(body)

	# 启动请求。
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, request_body_json)
	if error != OK:
		http_request.queue_free()
		return { "error": "HTTPRequest 创建失败。", "details": "Godot 错误码: %d" % error }

	# 等待请求完成。
	var result: Array = await http_request.request_completed
	
	# 从结果数组中提取数据。
	var response_code = result[1]
	var response_body_raw = result[3]
	var response_body_str = response_body_raw.get_string_from_utf8()
	
	# 不再需要请求节点了。
	http_request.queue_free()
	
	# 解析来自服务器的 JSON 响应。
	var json = JSON.parse_string(response_body_str)

	# 检查 HTTP 错误或无效的 JSON。
	if response_code >= 400 or json == null:
		var error_message = "请求失败。"
		if json != null and json.has("detail"):
			error_message = json.detail
		return { "error": error_message, "details": { "status_code": response_code, "body": response_body_str } }

	# 如果代码执行到这里，说明请求是成功的。
	return { "data": json }
