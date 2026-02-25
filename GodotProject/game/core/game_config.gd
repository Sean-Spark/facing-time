## 游戏配置
class_name GameConfig
extends RefCounted

## 默认配置
const DEFAULT_MIN_PLAYERS: int = 5
const DEFAULT_MAX_PLAYERS: int = 10
const DEFAULT_TEAM_SIZE: Array = [2, 3, 2, 3, 3]  # 5轮任务人数
const DEFAULT_FAIL_THRESHOLD: Array = [1, 1, 1, 2, 1]  # 失败票阈值

## 任务配置
class TaskConfig:
	var team_size: int
	var fail_threshold: int

	func _init(size: int, threshold: int):
		team_size = size
		fail_threshold = threshold

## 角色配置表
static func get_role_config(player_count: int) -> Dictionary:
	match player_count:
		5:
			return {
				"good": [GameEnums.Role.MERLIN, GameEnums.Role.PERCIVAL, GameEnums.Role.RESISTANCE_MEMBER],
				"bad": [GameEnums.Role.MORGANA, GameEnums.Role.MORDRED]
			}
		6:
			return {
				"good": [GameEnums.Role.MERLIN, GameEnums.Role.PERCIVAL, GameEnums.Role.RESISTANCE_MEMBER, GameEnums.Role.RESISTANCE_MEMBER],
				"bad": [GameEnums.Role.MORGANA, GameEnums.Role.MORDRED, GameEnums.Role.SPY]
			}
		7:
			return {
				"good": [GameEnums.Role.MERLIN, GameEnums.Role.PERCIVAL, GameEnums.Role.RESISTANCE_MEMBER, GameEnums.Role.RESISTANCE_MEMBER],
				"bad": [GameEnums.Role.MORGANA, GameEnums.Role.MORDRED, GameEnums.Role.SPY, GameEnums.Role.SPY]
			}
		8:
			return {
				"good": [GameEnums.Role.MERLIN, GameEnums.Role.PERCIVAL, GameEnums.Role.RESISTANCE_MEMBER, GameEnums.Role.RESISTANCE_MEMBER, GameEnums.Role.RESISTANCE_MEMBER],
				"bad": [GameEnums.Role.MORGANA, GameEnums.Role.MORDRED, GameEnums.Role.SPY, GameEnums.Role.SPY]
			}
		9:
			return {
				"good": [GameEnums.Role.MERLIN, GameEnums.Role.PERCIVAL, GameEnums.Role.RESISTANCE_MEMBER, GameEnums.Role.RESISTANCE_MEMBER, GameEnums.Role.RESISTANCE_MEMBER],
				"bad": [GameEnums.Role.MORGANA, GameEnums.Role.MORDRED, GameEnums.Role.SPY, GameEnums.Role.SPY, GameEnums.Role.SPY]
			}
		10:
			return {
				"good": [GameEnums.Role.MERLIN, GameEnums.Role.PERCIVAL, GameEnums.Role.RESISTANCE_MEMBER, GameEnums.Role.RESISTANCE_MEMBER, GameEnums.Role.RESISTANCE_MEMBER, GameEnums.Role.RESISTANCE_MEMBER],
				"bad": [GameEnums.Role.MORGANA, GameEnums.Role.MORDRED, GameEnums.Role.SPY, GameEnums.Role.SPY, GameEnums.Role.SPY]
			}
		_:
			# 默认5人配置
			return get_role_config(5)

## 获取每轮任务配置
static func get_task_configs(player_count: int) -> Array[TaskConfig]:
	var sizes: Array = [2, 3, 2, 3, 3]
	var thresholds: Array = [1, 1, 1, 2, 1]

	# 根据人数调整部分任务人数
	match player_count:
		6:
			sizes = [2, 3, 4, 3, 4]
		7:
			sizes = [2, 3, 3, 4, 4]
		8, 9, 10:
			sizes = [3, 4, 4, 5, 5]

	var configs: Array[TaskConfig] = []
	for i in range(5):
		configs.append(TaskConfig.new(sizes[i], thresholds[i]))
	return configs

## 获取好人/坏人数量
static func get_faction_counts(player_count: int) -> Dictionary:
	match player_count:
		5: return {"good": 3, "bad": 2}
		6: return {"good": 4, "bad": 3}
		7: return {"good": 4, "bad": 3}
		8: return {"good": 5, "bad": 3}
		9: return {"good": 6, "bad": 3}
		10: return {"good": 6, "bad": 4}
		_: return {"good": 3, "bad": 2}
