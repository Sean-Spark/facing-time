## 游戏状态枚举
class_name GameEnums

## 游戏阶段
enum GamePhase {
	WAITING,         # 等待玩家
	ROLE_DISTRIBUTION, # 角色分配
	TEAM_BUILDING,    # 组队阶段
	TEAM_VOTING,     # 团队投票
	TASK_VOTING,     # 任务投票
	TASK_RESULT,      # 任务结果
	ASSASSINATION,   # 刺杀梅林
	GAME_OVER        # 游戏结束
}

## 阵营
enum Faction {
	RESISTANCE,      # 反抗军（好人）
	SPIES            # 间谍（坏人）
}

## 角色
enum Role {
	# 好人阵营
	MERLIN,          # 梅林 - 看到所有间谍（除莫德雷德）
	PERCIVAL,        # 派西维尔 - 看到梅林和莫甘娜
	RESISTANCE_MEMBER, # 普通反抗军

	# 坏人阵营
	MORDRED,         # 莫德雷德 - 隐藏的间谍，梅林看不到
	MORGANA,         # 莫甘娜 - 伪装成梅林
	SPY,             # 普通间谍
	OBERON           # 奥伯伦 - 孤立的间谍
}

## 投票结果
enum VoteResult {
	PASS,            # 通过
	REJECT           # 拒绝
}

## 任务结果
enum TaskResult {
	SUCCESS,         # 成功
	FAIL,            # 失败（1张失败票即可）
	FAIL_2           # 失败（需2张失败票，仅4人局第4任务）
}

## 游戏结果
enum GameResult {
	RESISTANCE_WIN,   # 反抗军胜利
	SPIES_WIN,        # 间谍阵营胜利
	SPIES_WIN_BY_ASSASSINATION, # 刺杀梅林胜利
	NONE              # 未结束
}

## 消息类型
enum MessageType {
	# 房间相关（客户端<->服务端）
	ROOM_STATE,        # 房间状态
	PLAYER_ASSIGNED,  # 座位分配
	PLAYER_JOINED,    # 玩家加入
	PLAYER_LEFT,      # 玩家离开
	PLAYER_READY,     # 玩家准备

	# 游戏相关（客户端->服务端）
	JOIN_GAME,
	READY,
	VOTE_TEAM,
	VOTE_TASK,
	ASSASSINATE,

	# 游戏相关（服务端->客户端）
	GAME_START,
	ROLE_ASSIGNED,
	TEAM_PROPOSED,
	TEAM_VOTE_RESULT,
	TASK_VOTE,
	TASK_RESULT,
	PLAYER_INFO,
	GAME_OVER,
	ERROR,

	# 通用
	PING,
	PONG
}
