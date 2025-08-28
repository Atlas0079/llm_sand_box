# res://Script/LLMRelated/LLMClient.gd
# AutoLoad
extends Node

# --- 配置 ---
# 把你的URL和Token放在这里
# 在真实项目中，这些应该从配置文件或环境变量读取
const API_URL = "https://fastapi.aabao.top/v1/chat/completions"
const API_TOKEN = "sk-FSKFoh6aBuNw8XKJ8gyo1oQ2bCofdcXoFCQXCoQs43B2SpoQ"

# --- 内部状态 ---
var http_request: HTTPRequest

func _init():
    # 创建一个HTTPRequest节点来处理网络请求
    http_request = HTTPRequest.new()
    add_child(http_request) # 必须将它添加到场景树中才能工作

# ==============================================================================
func request_blocking(prompt_messages: Array, model_name: String, temperature: float = 0.7) -> String:
    """
    发送一个阻塞式的LLM请求，并返回文本结果。
    整个游戏会在此等待直到收到响应。
    """
    print("LLMClient: Sending request to model '", model_name, "'...")
    
    # 1. 准备请求头
    var headers = [
        "Content-Type: application/json",
        "Authorization: Bearer " + API_TOKEN
    ]


    # 2. 准备请求体 (Body)
    var body = {
        "model": model_name,
        "messages": prompt_messages, # 遵循OpenAI的messages格式
        "temperature": temperature,
        "stream": false # 我们需要完整的响应，而不是流式
    }
    
    # 将字典转换为JSON字符串
    var body_json_string = JSON.stringify(body)

    # 3. 发送请求
    # request()方法本身是异步的，但我们可以用await来等待它的完成信号
    var error = http_request.request(API_URL, headers, HTTPClient.METHOD_POST, body_json_string)
    
    if error != OK:
        printerr("LLMClient: An error occurred in the HTTP request.")
        return "ERROR: HTTP request failed."

    # 4. 阻塞并等待响应！
    # `request_completed`是HTTPRequest节点在请求完成时发出的信号
    # await会暂停此函数的执行，但因为我们在主线程调用，所以整个游戏都会冻结
    var result = await http_request.request_completed
    
    # 5. 解析结果
    var response_code = result[1]
    var response_headers = result[2]
    var response_body_raw = result[3]
    
    if response_code >= 400:
        printerr("LLMClient: API returned an error (", response_code, ").")
        printerr("Response body: ", response_body_raw.get_string_from_utf8())
        return "ERROR: API returned status " + str(response_code)

    # 将返回的原始二进制数据转换为JSON字典
    var response_json = JSON.parse_string(response_body_raw.get_string_from_utf8())
    
    if response_json == null:
        printerr("LLMClient: Failed to parse JSON response.")
        return "ERROR: JSON parsing failed."
        
    # 6. 提取并返回内容
    # 遵循OpenAI的格式，提取需要的内容
    if response_json.has("choices") and response_json.choices.size() > 0:
        var content = response_json.choices[0].message.content
        print("LLMClient: Received response.")
        return content
    else:
        printerr("LLMClient: Response format is invalid. 'choices' not found.")
        print("Full response: ", response_json)
        return "ERROR: Invalid response format."