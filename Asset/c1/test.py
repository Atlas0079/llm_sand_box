import pygame
import os
import random # 新增导入

# --- 配置参数 ---
SCREEN_WIDTH = 800
SCREEN_HEIGHT = 600
FPS = 60

# 颜色
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)

# 立绘图片路径 (!!! 请务必修改为你自己的路径 !!!)
BASE_IMAGE_PATH = r"E:\output\like\原立绘-全身\1\c1" # 使用 r"..." 来处理Windows路径中的反斜杠
# IMAGE_FILES 字典将被移除，改为动态扫描
# IMAGE_FILES = {
# "default": os.path.join(BASE_IMAGE_PATH, "1-shy.png"),
# "angry": os.path.join(BASE_IMAGE_PATH, "1-normal.png")
# }

# 过渡动画参数
TRANSITION_OFFSET_Y = 15  # 向下/向上移动的像素距离 (基于缩放后图像的相对移动)
TRANSITION_SPEED = 2      # 每帧移动的像素

# --- 初始化 Pygame ---
pygame.init()
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("立绘表情切换演示 (已缩放)")
clock = pygame.time.Clock()

# --- 函数：按比例缩放图片以适应屏幕 ---
def scale_image_to_fit(image_surface, target_width, target_height):
    img_width, img_height = image_surface.get_size()
    
    # 计算宽高比
    img_aspect_ratio = img_width / img_height
    target_aspect_ratio = target_width / target_height

    # 以宽度为基准还是高度为基准进行缩放
    if img_aspect_ratio > target_aspect_ratio:
        # 图片比目标区域更宽，以目标宽度为基准
        new_width = target_width
        new_height = int(new_width / img_aspect_ratio)
    else:
        # 图片比目标区域更高（或宽高比相同），以目标高度为基准
        new_height = target_height
        new_width = int(new_height * img_aspect_ratio)
    
    # 如果图片本身就比目标小，我们也可以选择不放大，这里我们选择总是缩放到适应
    # 如果想避免放大已经很小的图片，可以加一个判断：
    # if new_width > img_width or new_height > img_height:
    #     return image_surface # 或者返回原始尺寸，如果不想放大

    return pygame.transform.smoothscale(image_surface, (new_width, new_height))

# --- 加载并缩放立绘 ---
expressions = {}
scaled_expressions = {} # 存储缩放后的图片

try:
    if not os.path.isdir(BASE_IMAGE_PATH):
        print(f"错误：基础图片路径 '{BASE_IMAGE_PATH}' 不是一个有效的目录。程序退出。")
        pygame.quit()
        exit()

    image_files_found = [f for f in os.listdir(BASE_IMAGE_PATH) if f.lower().endswith(('.png', '.jpg', '.jpeg'))]

    if not image_files_found:
        print(f"错误：在目录 '{BASE_IMAGE_PATH}' 中没有找到支持的图片文件（.png, .jpg, .jpeg）。程序退出。")
        pygame.quit()
        exit()

    for filename in image_files_found:
        path = os.path.join(BASE_IMAGE_PATH, filename)
        # 从文件名提取表情名，例如 "1-smile.png" -> "smile"
        name_part = os.path.splitext(filename)[0]
        expression_name = name_part
        # 尝试去除数字前缀，如 "1-", "01-", "char2-"
        parts = name_part.split('-', 1)
        if len(parts) > 1 and parts[0].isdigit():
            expression_name = parts[1]
        else:
            parts = name_part.split('_', 1)
            if len(parts) > 1 and parts[0].isdigit():
                expression_name = parts[1]
        
        if not expression_name: # 如果提取后名称为空
            print(f"警告：无法从文件名 '{filename}' 中提取有效的表情名称，跳过此文件。")
            continue

        original_image = pygame.image.load(path).convert_alpha()
        expressions[expression_name] = original_image # 保留原始图片（可选）
        # 将图片缩放到适应屏幕，但保留一些边距，比如90%的高度
        scaled_image = scale_image_to_fit(original_image, SCREEN_WIDTH, int(SCREEN_HEIGHT * 0.95))
        scaled_expressions[expression_name] = scaled_image
        print(f"Loaded and scaled '{expression_name}' from '{filename}': original {original_image.get_size()} -> scaled {scaled_image.get_size()}")

except pygame.error as e:
    print(f"错误：加载图片时发生错误！{e}")
    print(f"请检查 '{BASE_IMAGE_PATH}' 目录下的图片文件。")
    pygame.quit()
    exit()
# except Exception as e: # 捕获其他潜在错误，如路径问题
# print(f"发生未知错误: {e}")
# pygame.quit()
# exit()

if not scaled_expressions:
    print("错误：没有任何图片被成功加载和缩放。程序退出。")
    pygame.quit()
    exit()

# 当前显示的表情和位置
available_expression_names = list(scaled_expressions.keys())
current_expression_name = random.choice(available_expression_names) # 初始随机选择一个表情
# if current_expression_name not in scaled_expressions:
    # 如果默认表情加载失败，尝试使用第一个加载成功的表情
    # current_expression_name = next(iter(scaled_expressions)) # 旧逻辑

current_image = scaled_expressions[current_expression_name]
image_rect = current_image.get_rect()

# 将缩放后的立绘放在屏幕底部中央
image_rect.centerx = SCREEN_WIDTH // 2
image_rect.bottom = SCREEN_HEIGHT - 10 # 离底部10像素
original_y = image_rect.y # 这是缩放后图像的原始Y位置

# --- 动画状态变量 ---
transition_state = "NONE"
target_expression_name = None
temp_display_image = None

# --- 游戏主循环 ---
running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                if transition_state == "NONE":
                    available_expression_names = list(scaled_expressions.keys())
                    if len(available_expression_names) > 1:
                        # 从不是当前表情的其他表情中随机选择
                        possible_targets = [name for name in available_expression_names if name != current_expression_name]
                        if possible_targets: # 确保有其他表情可选
                            target_expression_name = random.choice(possible_targets)
                            transition_state = "GOING_DOWN"
                            temp_display_image = scaled_expressions[current_expression_name] # 开始下降时显示当前图像
                            print(f"开始随机切换: {current_expression_name} -> {target_expression_name}")
                        # else: # 如果 possible_targets 为空，说明虽然总表情数>1，但不知何故出错了（不太可能发生）
                            # print("无法选择新的不同表情。")
                    elif len(available_expression_names) == 1:
                        print("只有一个表情，无法切换。")
                    else: # len == 0，已被前面的检查覆盖
                        print("没有可切换的表情。")
                        
                    # 旧的固定切换逻辑
                    # if current_expression_name == "default":
                        # target_expression_name = "angry" if "angry" in scaled_expressions else current_expression_name
                    # else:
                        # target_expression_name = "default" if "default" in scaled_expressions else current_expression_name
                    
                    # if target_expression_name != current_expression_name:
                        # transition_state = "GOING_DOWN"
                        # temp_display_image = scaled_expressions[current_expression_name]
                        # print(f"开始切换到: {target_expression_name}")

            if event.key == pygame.K_ESCAPE:
                running = False

    # --- 更新动画状态 ---
    if transition_state == "GOING_DOWN":
        image_rect.y += TRANSITION_SPEED
        if image_rect.y >= original_y + TRANSITION_OFFSET_Y:
            image_rect.y = original_y + TRANSITION_OFFSET_Y
            # 在图像向下移动到底部后，才真正切换表情的 "逻辑名称"
            # temp_display_image 依然是旧表情，直到上升动画开始前切换
            # current_expression_name = target_expression_name # 移到下一个状态
            temp_display_image = scaled_expressions[target_expression_name] # 切换为目标图像，准备上升
            transition_state = "GOING_UP"
            print(f"图像已切换为: {target_expression_name}, 准备上升")

    elif transition_state == "GOING_UP":
        image_rect.y -= TRANSITION_SPEED
        if image_rect.y <= original_y:
            image_rect.y = original_y
            current_expression_name = target_expression_name # 在动画完全结束后，更新当前表情名称
            transition_state = "NONE"
            current_image = scaled_expressions[current_expression_name] # 更新主显示图像
            temp_display_image = None
            print(f"过渡完成，当前为: {current_expression_name}")
            
    # --- 绘制 ---
    screen.fill(WHITE)

    display_image_to_render = temp_display_image if temp_display_image else current_image
    
    if display_image_to_render:
        # 如果不同表情缩放后尺寸有细微差别，你可能需要更新rect的尺寸以匹配当前图像
        # 但为了简单的上下移动，我们通常用一个固定的rect来定位，只改变blit的surface
        # 如果要精确匹配，可以这样做：
        # current_rect_for_blit = display_image_to_render.get_rect()
        # current_rect_for_blit.centerx = image_rect.centerx # 保持中心X
        # current_rect_for_blit.y = image_rect.y # 使用动画控制的Y
        # screen.blit(display_image_to_render, current_rect_for_blit)
        # 为简化，我们直接用image_rect，假设缩放后的图片尺寸差异不大
        screen.blit(display_image_to_render, image_rect)

    else:
        pygame.draw.rect(screen, (200,0,0), (100,100,100,100))
        font = pygame.font.Font(None, 30)
        text_surf = font.render("Image load error", True, BLACK)
        screen.blit(text_surf, (10,10))

    pygame.display.flip()
    clock.tick(FPS)

# --- 退出 Pygame ---
pygame.quit()