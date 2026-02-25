## 阿瓦隆游戏核心管理器
class_name GameManager
extends Node

signal sig_phase_changed(new_phase: GameEnums.GamePhase)
signal sig_team_proposed(team: Array, leader_id: String)
signal sig_team_vote_received(player_id: String, vote: bool)
signal sig_task_vote_received(player_id: String, vote: bool)
signal sig_task_result_announced(result: GameEnums.TaskResult)
signal sig_game_result_announced(result: GameEnums.GameResult, winners: Array)
signal sig_player_info_updated(player: Player)
signal sig_assassin_needed(assassin_id: String)
signal sig_error_occurred(message: String)

## 游戏配置
var config: GameConfig = GameConfig.new()

## 玩家字典
var players: Dictionary = {}

## 当前阶段
var current_phase: GameEnums.GamePhase = GameEnums.GamePhase.WAITING

## 当前队长ID
var current_leader_id: String = ""

## 当前任务轮数 (0-4)
var current_task_round: int = 0

## 提议的任务团队
var proposed_team: Array = []

## 任务投票统计
var task_votes: Dictionary = {}

## 团队投票统计
var team_votes: Dictionary = {}

## 团队投票连续失败次数
var team_rejection_count: int = 0

## 任务成功次数
var success_count: int = 0

## 任务失败次数
var fail_count: int = 0

## 任务结果历史
var task_results: Array = []

## 游戏结果
var game_result: GameEnums.GameResult = GameEnums.GameResult.NONE

## 刺客ID（用于刺杀梅林）
var assassin_id: String = ""

## 梅林身份ID
var merlin_id: String = ""

## 是否为服务器模式
var is_server: bool = false

# 私有变量
var _task_configs: Array[GameConfig.TaskConfig] = []
var _player_order: Array = []  # 玩家顺序用于轮流当队长
var _vote_count: int = 0  # 当前投票计数


## 初始化游戏
func initialize(p_is_server: bool) -> void:
	is_server = p_is_server
	reset_game()

## 重置游戏
func reset_game() -> void:
	players.clear()
	current_phase = GameEnums.GamePhase.WAITING
	current_leader_id = ""
	current_task_round = 0
	proposed_team.clear()
	task_votes.clear()
	team_votes.clear()
	team_rejection_count = 0
	success_count = 0
	fail_count = 0
	task_results.clear()
	game_result = GameEnums.GameResult.NONE
	_task_configs.clear()
	_player_order.clear()
	_vote_count = 0

## 添加玩家
func add_player(player: Player) -> bool:
	if players.has(player.id):
		return false
	players[player.id] = player
	sig_player_info_updated.emit(player)
	return true

## 移除玩家
func remove_player(player_id: String) -> void:
	if players.has(player_id):
		players.erase(player_id)
		# 重新构建玩家顺序
		_update_player_order()

## 玩家准备
func set_player_ready(player_id: String, player_ready: bool) -> void:
	if players.has(player_id):
		players[player_id].is_ready = player_ready
		sig_player_info_updated.emit(players[player_id])

## 检查是否所有玩家都准备
func all_players_ready() -> bool:
	if players.is_empty():
		return false
	for player in players.values():
		if not player.is_ready:
			return false
	return true

## 开始游戏（服务端调用）
func start_game() -> bool:
	if not is_server:
		sig_error_occurred.emit("Only server can start the game")
		return false

	var player_count = players.size()
	if player_count < 5 or player_count > 10:
		sig_error_occurred.emit("Player count must be between 5-10")
		return false

	# 分配角色
	if not _assign_roles():
		return false

	# 获取任务配置
	_task_configs = GameConfig.get_task_configs(player_count)

	# 设置玩家顺序
	_update_player_order()

	# 设置第一轮队长
	current_leader_id = _player_order[0]

	# 进入角色分配阶段
	current_phase = GameEnums.GamePhase.ROLE_DISTRIBUTION
	sig_phase_changed.emit(current_phase)

	_on_game_start_delayed()
	return true


func _on_game_start_delayed() -> void:
	current_phase = GameEnums.GamePhase.TEAM_BUILDING
	sig_phase_changed.emit(current_phase)
	_propose_team()

## 分配角色
func _assign_roles() -> bool:
	var player_count = players.size()
	var role_config = GameConfig.get_role_config(player_count)

	var all_roles: Array = []
	all_roles.append_array(role_config["good"])
	all_roles.append_array(role_config["bad"])

	# 打乱角色
	all_roles.shuffle()

	var player_ids = players.keys()
	player_ids.shuffle()

	var i: int = 0
	for id in player_ids:
		if i >= all_roles.size():
			break
		var role = all_roles[i]
		players[id].role = role
		players[id].faction = GameEnums.Faction.RESISTANCE if role in [
			GameEnums.Role.MERLIN, GameEnums.Role.PERCIVAL, GameEnums.Role.RESISTANCE_MEMBER
		] else GameEnums.Faction.SPIES

		# 记录梅林ID
		if role == GameEnums.Role.MERLIN:
			merlin_id = id
		# 记录刺客ID
		if role == GameEnums.Role.MORGANA or role == GameEnums.Role.SPY:
			if assassin_id.is_empty():
				assassin_id = id

		i += 1

	return true

## 更新玩家顺序
func _update_player_order() -> void:
	_player_order.clear()
	for id in players.keys():
		_player_order.append(id)

## 提议组建团队
func _propose_team() -> void:
	var team_size = _task_configs[current_task_round].team_size
	proposed_team.clear()

	# 队长必须加入团队
	if players.has(current_leader_id):
		proposed_team.append(current_leader_id)

	# 随机选择其他成员
	var available_players = _player_order.duplicate()
	available_players.erase(current_leader_id)
	available_players.shuffle()

	var needed = team_size - 1
	for i in range(min(needed, available_players.size())):
		proposed_team.append(available_players[i])

	sig_team_proposed.emit(proposed_team, current_leader_id)

## 提出团队（手动指定）
func propose_team_by_leader(team: Array) -> bool:
	if current_phase != GameEnums.GamePhase.TEAM_BUILDING:
		return false
	if not team.has(current_leader_id):
		return false
	if team.size() != _task_configs[current_task_round].team_size:
		return false

	proposed_team = team
	sig_team_proposed.emit(proposed_team, current_leader_id)
	return true

## 玩家对团队投票
func vote_team(player_id: String, approve: bool) -> void:
	if current_phase != GameEnums.GamePhase.TEAM_VOTING:
		return
	if not players.has(player_id):
		return
	if not players[player_id].is_alive:
		return

	team_votes[player_id] = approve
	sig_team_vote_received.emit(player_id, approve)

	# 检查是否所有玩家都投票了
	if team_votes.size() == players.size():
		_calculate_team_vote_result()

## 计算团队投票结果
func _calculate_team_vote_result() -> void:
	var total_votes = team_votes.size()
	var approve_votes = 0
	for vote in team_votes.values():
		if vote:
			approve_votes += 1

	var result: GameEnums.VoteResult
	if approve_votes * 2 > total_votes:
		result = GameEnums.VoteResult.PASS
	else:
		result = GameEnums.VoteResult.REJECT

	if result == GameEnums.VoteResult.PASS:
		# 团队通过，进入任务投票阶段
		current_phase = GameEnums.GamePhase.TASK_VOTING
		task_votes.clear()
		sig_phase_changed.emit(current_phase)
	else:
		# 团队被拒绝
		team_rejection_count += 1
		if team_rejection_count >= 5:
			# 连续5次失败，间谍胜利
			_end_game(GameEnums.GameResult.SPIES_WIN)
		else:
			# 轮换队长
			_rotate_leader()
			current_phase = GameEnums.GamePhase.TEAM_BUILDING
			sig_phase_changed.emit(current_phase)
			_propose_team()

## 轮换队长
func _rotate_leader() -> void:
	var current_index = _player_order.find(current_leader_id)
	current_leader_id = _player_order[(current_index + 1) % _player_order.size()]

## 玩家对任务投票
func vote_task(player_id: String, approve: bool) -> void:
	if current_phase != GameEnums.GamePhase.TASK_VOTING:
		return
	if not proposed_team.has(player_id):
		return
	if not players.has(player_id):
		return
	if not players[player_id].is_alive:
		return

	task_votes[player_id] = approve
	sig_task_vote_received.emit(player_id, approve)

	# 检查是否所有团队成员都投票了
	if task_votes.size() == proposed_team.size():
		_calculate_task_result()

## 计算任务结果
func _calculate_task_result() -> void:
	var fail_votes = 0
	var total_votes = task_votes.size()
	var fail_threshold = _task_configs[current_task_round].fail_threshold

	for vote in task_votes.values():
		if not vote:
			fail_votes += 1

	var result: GameEnums.TaskResult
	if fail_votes >= fail_threshold:
		result = GameEnums.TaskResult.FAIL
	else:
		result = GameEnums.TaskResult.SUCCESS

	task_results.append(result)
	sig_task_result_announced.emit(result)

	# 更新任务计数
	if result == GameEnums.TaskResult.SUCCESS:
		success_count += 1
	else:
		fail_count += 1

	# 检查游戏结果
	if success_count >= 3:
		# 反抗军完成3个任务，进入刺杀梅林阶段
		current_phase = GameEnums.GamePhase.ASSASSINATION
		sig_phase_changed.emit(current_phase)
		sig_assassin_needed.emit(assassin_id)
	elif fail_count >= 3:
		# 间谍破坏3个任务，间谍胜利
		_end_game(GameEnums.GameResult.SPIES_WIN)
	else:
		# 进入下一轮
		_next_round()

## 进入下一轮
func _next_round() -> void:
	current_task_round += 1
	team_rejection_count = 0
	team_votes.clear()
	task_votes.clear()

	# 轮换队长
	_rotate_leader()

	current_phase = GameEnums.GamePhase.TEAM_BUILDING
	sig_phase_changed.emit(current_phase)
	_propose_team()

## 刺杀梅林
func assassinate_merlin(assassin_id: String, target_id: String) -> bool:
	if current_phase != GameEnums.GamePhase.ASSASSINATION:
		return false
	if assassin_id != self.assassin_id:
		return false
	if not players.has(target_id):
		return false

	# 检查是否刺杀到真正的梅林
	if target_id == merlin_id:
		# 刺杀成功，间谍胜利
		_end_game(GameEnums.GameResult.SPIES_WIN_BY_ASSASSINATION)
	else:
		# 刺杀失败，反抗军胜利
		_end_game(GameEnums.GameResult.RESISTANCE_WIN)
	return true

## 结束游戏
func _end_game(result: GameEnums.GameResult) -> void:
	game_result = result
	current_phase = GameEnums.GamePhase.GAME_OVER
	sig_phase_changed.emit(current_phase)

	var winners: Array = []
	match result:
		GameEnums.GameResult.RESISTANCE_WIN:
			for player in players.values():
				if player.faction == GameEnums.Faction.RESISTANCE:
					winners.append(player.id)
		GameEnums.GameResult.SPIES_WIN, GameEnums.GameResult.SPIES_WIN_BY_ASSASSINATION:
			for player in players.values():
				if player.faction == GameEnums.Faction.SPIES:
					winners.append(player.id)

	sig_game_result_announced.emit(result, winners)

## 获取玩家可见信息（用于客户端）
func get_player_view(player_id: String) -> Dictionary:
	if not players.has(player_id):
		return {}

	var player = players[player_id]
	var view: Dictionary = {
		"phase": current_phase,
		"player_id": player_id,
		"role": player.role,
		"faction": player.faction,
		"current_leader_id": current_leader_id,
		"task_round": current_task_round,
		"success_count": success_count,
		"fail_count": fail_count,
		"team_rejection_count": team_rejection_count,
		"proposed_team": proposed_team.duplicate(),
		"task_results": task_results.duplicate()
	}

	# 添加可见玩家信息
	var visible_players: Array = []
	for other_id in players.keys():
		var other = players[other_id]
		var info: Dictionary = {
			"id": other_id,
			"name": other.name,
			"is_alive": other.is_alive
		}
		if player.can_see_role(other):
			info["role"] = other.role
			info["faction"] = other.faction
		visible_players.append(info)
	view["players"] = visible_players

	return view

## 获取游戏状态（用于同步）
func get_game_state() -> Dictionary:
	return {
		"phase": current_phase,
		"current_leader_id": current_leader_id,
		"current_task_round": current_task_round,
		"proposed_team": proposed_team.duplicate(),
		"success_count": success_count,
		"fail_count": fail_count,
		"team_rejection_count": team_rejection_count,
		"task_results": task_results.duplicate()
	}

## 序列化游戏状态
func serialize() -> Dictionary:
	return {
		"config": {
			"player_count": players.size(),
			"task_configs": []
		},
		"players": players.keys().map(func(id): return players[id].to_dict()),
		"current_phase": current_phase,
		"current_leader_id": current_leader_id,
		"current_task_round": current_task_round,
		"proposed_team": proposed_team.duplicate(),
		"team_votes": team_votes.duplicate(),
		"task_votes": task_votes.duplicate(),
		"team_rejection_count": team_rejection_count,
		"success_count": success_count,
		"fail_count": fail_count,
		"task_results": task_results.duplicate(),
		"merlin_id": merlin_id,
		"assassin_id": assassin_id,
		"game_result": game_result
	}

## 反序列化游戏状态
func deserialize(data: Dictionary) -> void:
	reset_game()
	# 反序列化玩家
	for player_data in data.get("players", []):
		var player = Player.new()
		player.from_dict(player_data)
		players[player.id] = player

	current_phase = data.get("current_phase", GameEnums.GamePhase.WAITING)
	current_leader_id = data.get("current_leader_id", "")
	current_task_round = data.get("current_task_round", 0)
	team_rejection_count = data.get("team_rejection_count", 0)
	success_count = data.get("success_count", 0)
	fail_count = data.get("fail_count", 0)
	merlin_id = data.get("merlin_id", "")
	assassin_id = data.get("assassin_id", "")
	game_result = data.get("game_result", GameEnums.GameResult.NONE)

	# 数组需要单独处理
	if data.has("proposed_team"):
		proposed_team = Array(data["proposed_team"])
	if data.has("team_votes"):
		team_votes = data["team_votes"].duplicate(true)
	if data.has("task_votes"):
		task_votes = data["task_votes"].duplicate(true)
	if data.has("task_results"):
		task_results = Array(data["task_results"])

	_update_player_order()
