# res://world/resources/game_time.gd
extends Resource
class_name GameTime

# --- 核心数据 (以最细粒度单位“刻”为基础) ---
var total_ticks: int = 0

# --- 定义常量，便于计算和理解 ---
const TICKS_PER_MINUTE = 1
const MINUTES_PER_HOUR = 60
const HOURS_PER_DAY = 24
const DAYS_PER_WEEK = 7
const WEEKS_PER_MONTH = 4 # 简化月份
const MONTHS_PER_YEAR = 12

const TICKS_PER_HOUR = TICKS_PER_MINUTE * MINUTES_PER_HOUR
const TICKS_PER_DAY = TICKS_PER_HOUR * HOURS_PER_DAY

# --- 公共API (只读属性，避免外部直接修改) ---
func get_year() -> int:
    return 1 + total_ticks / (TICKS_PER_DAY * DAYS_PER_WEEK * WEEKS_PER_MONTH * MONTHS_PER_YEAR)

func get_month() -> int:
    var ticks_in_year = total_ticks % (TICKS_PER_DAY * DAYS_PER_WEEK * WEEKS_PER_MONTH * MONTHS_PER_YEAR)
    return 1 + ticks_in_year / (TICKS_PER_DAY * DAYS_PER_WEEK * WEEKS_PER_MONTH)

func get_day_of_month() -> int:
    # ... 类似的计算 ...
    return 1 # (为简洁起见，省略具体实现)

func get_hour() -> int:
    var ticks_in_day = total_ticks % TICKS_PER_DAY
    return ticks_in_day / TICKS_PER_HOUR

func get_minute() -> int:
    var ticks_in_hour = (total_ticks % TICKS_PER_DAY) % TICKS_PER_HOUR
    return ticks_in_hour / TICKS_PER_MINUTE

# --- 时间推进方法 ---
func advance_ticks(ticks_to_add: int):
    var old_day = total_ticks / TICKS_PER_DAY
    total_ticks += ticks_to_add
    var new_day = total_ticks / TICKS_PER_DAY
    
    # 返回是否跨天了，这对于触发每日事件非常重要
    return new_day > old_day

func advance_minutes(minutes_to_add: int):
    return advance_ticks(minutes_to_add * TICKS_PER_MINUTE)

# --- 格式化输出，方便调试 ---
func time_to_string() -> String:
    return "Year %d, Month %d, Day %d, %02d:%02d" % [get_year(), get_month(), get_day_of_month(), get_hour(), get_minute()]