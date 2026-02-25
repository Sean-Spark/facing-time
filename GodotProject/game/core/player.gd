## 玩家数据类
class_name Player
extends RefCounted

## 玩家ID
var id: String

## 玩家名称
var name: String

## 所属阵营
var faction: GameEnums.Faction

## 角色
var role: GameEnums.Role

## 是否已准备
var is_ready: bool = false

## 是否存活
var is_alive: bool = true

## 任务投票（用于显示结果）
var task_vote: bool = false

## 构造函数
func _init(p_id: String = "", p_name: String = ""):
	id = p_id
	name = p_name

## 获取玩家信息字典
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"faction": faction,
		"role": role,
		"is_ready": is_ready,
		"is_alive": is_alive
	}

## 从字典加载
func from_dict(data: Dictionary) -> void:
	id = data.get("id", "")
	name = data.get("name", "")
	faction = data.get("faction", GameEnums.Faction.RESISTANCE)
	role = data.get("role", GameEnums.Role.RESISTANCE_MEMBER)
	is_ready = data.get("is_ready", false)
	is_alive = data.get("is_alive", true)

## 是否能看到另一玩家的角色
func can_see_role(other: Player) -> bool:
	match role:
		GameEnums.Role.MERLIN:
			# 梅林能看到所有间谍（除莫德雷德）
			if other.faction == GameEnums.Faction.SPIES:
				if other.role == GameEnums.Role.MORDRED:
					return false
				return true
		GameEnums.Role.PERCIVAL:
			# 派西维尔能看到梅林和莫甘娜
			if other.role == GameEnums.Role.MERLIN or other.role == GameEnums.Role.MORGANA:
				return true
		GameEnums.Role.MORDRED:
			# 莫德雷德能看到其他间谍
			if other.faction == GameEnums.Faction.SPIES:
				if other.role != GameEnums.Role.MORDRED:
					return true
		GameEnums.Role.MORGANA:
			# 莫甘娜能看到其他间谍（除奥伯伦）
			if other.faction == GameEnums.Faction.SPIES:
				if other.role != GameEnums.Role.OBERON:
					return true
		GameEnums.Role.SPY:
			# 普通间谍能看到其他间谍（除奥伯伦）
			if other.faction == GameEnums.Faction.SPIES:
				if other.role != GameEnums.Role.OBERON:
					return true
		GameEnums.Role.OBERON:
			# 奥伯伦看不到任何人
			pass
	return false
