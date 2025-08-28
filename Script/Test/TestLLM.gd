# res://Script/Test/TestLLM.gd
extends Node

# 这个函数会在节点第一次进入场景树时被调用。
func _ready():
	# 由于我们使用了 'await'，_ready 函数会自动变成异步的。
	print("--- 开始 LLMClient 测试 ---")

	# 1. 创建 LLMClient 的实例
	var llm_client = LLMClient.new()
	# 重要：必须将客户端添加到场景树中，它内部的 HTTPRequest 才能工作。
	add_child(llm_client)

	# 2. 准备一个简单的测试 Prompt
	var prompt_messages = [
		{"role": "system", "content": "你是一个乐于助人的助手。"},
		{"role": "user", "content": "你好！请给我讲一个关于机器人发现音乐的简短故事。"}
	]
	# 请确保这个模型名称是你的API端点所支持的
	var model_name = "gemini-2.5-flash" 

	# 3. 调用请求函数并等待结果
	# 'await' 关键字会暂停此函数的执行，直到LLM响应，但不会冻结整个游戏。
	print("正在发送请求，请稍候...")
	var response = await llm_client.request_blocking(prompt_messages, model_name)

	# 4. 将结果打印到Godot的输出控制台
	print("--- LLM 响应 ---")
	if response.begins_with("ERROR:"):
		printerr(response)
	else:
		print(response)
	print("--- 测试结束 ---")

	# 5. 测试完成后，清理客户端节点
	llm_client.queue_free() 