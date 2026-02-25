# 游戏房间交互场景设计

## 1. 界面层级结构

```
Avalon (主控制器)
├── SelectMode (模式选择界面)
│   ├── HostButton (创建游戏) - 仅非Web平台显示
│   ├── ClientButton (加入游戏)
│   └── BackButton (返回)
├── HostInit (主机初始化界面)
│   ├── PortInput (端口输入框)
│   ├── PlayerCountSelector (人数设置按钮)
│   ├── PlayerNameInput (玩家名输入框)
│   ├── StartButton (服务启动按钮)
│   ├── StatusLabel (服务状态显示)
│   └── BackButton (返回)
├── ClientInit (从机初始化界面)
│   ├── HostUrlInput (主机地址输入框)
│   ├── PlayerNameInput (玩家名输入框)
│   ├── ConnectButton (连接服务按钮)
│   ├── StatusLabel (服务连接状态显示)
│   └── BackButton (返回)
└── GameRoom (游戏房间界面)
	├── SeatsContainer (座位容器)
	│   └── Seat[i] (座位框) x N
	│       ├── SeatLabel (座位编号)
	│       ├── NameLabel (玩家名字)
	│       └── ReadyLabel (准备状态)
	├── ReadyButton (准备/取消准备按钮)
	├── LeaveButton (离开房间按钮)
	└── StatusLabel (状态提示)
```

## 2. 平台差异

| 平台 | HostButton可见 | 功能限制 |
|------|---------------|----------|
| Web | ❌ 隐藏 | 只能作为从机加入 |
| Desktop | ✅ 显示 | 可创建或加入游戏 |
| Mobile | ✅ 显示 | 可创建或加入游戏 |

---

## 3. UI交互流程

### 3.1 模式选择界面 (SelectMode)

**进入方式**: 实例化Avalon场景时自动进入

**交互元素**:
| 元素 | 类型 | 必填 | 行为 |
|------|------|------|------|
| HostButton | Button | 否 | 点击 → 跳转到主机初始化界面 |
| ClientButton | Button | 是 | 点击 → 跳转到从机初始化界面 |
| BackButton | Button | 否 | 点击 → 销毁Avalon场景 |

**离开条件**:
- 点击 HostButton → 进入 HostInit
- 点击 ClientButton → 进入 ClientInit
- 点击 BackButton → 退出整个游戏房间系统

---

### 3.2 主机初始化界面 (HostInit)

**进入方式**: 从 SelectMode 点击 HostButton

**交互元素**:
| 元素 | 类型 | 必填 | 验证规则 |
|------|------|------|----------|
| PortInput | LineEdit | 是 | 端口号 1-65535 |
| PlayerNameInput | LineEdit | 是 | 非空字符串 |
| PlayerCountSelector | OptionButton | 是 | 可选 5-10 人 |
| StartButton | Button | 是 | 所有必填项验证通过后可点击 |
| BackButton | Button | 否 | 返回模式选择界面 |

**状态流转**:
```
PortInput输入 + PlayerName输入 + 人数选择
		   ↓
	  StartButton变为可点击
		   ↓
	  点击StartButton
		   ↓
	启动WebSocket服务器
		   ↓
	成功 → 进入GameRoom
	失败 → 显示错误状态
```

**离开条件**:
- StartButton 点击且服务器启动成功 → 进入 GameRoom
- BackButton 点击 → 返回 SelectMode

---

### 3.3 从机初始化界面 (ClientInit)

**进入方式**: 从 SelectMode 点击 ClientButton

**交互元素**:
| 元素 | 类型 | 必填 | 验证规则 |
|------|------|------|----------|
| HostUrlInput | LineEdit | 是 | WebSocket URL格式 |
| PlayerNameInput | LineEdit | 是 | 非空字符串 |
| ConnectButton | Button | 是 | 所有必填项验证通过后可点击 |
| StatusLabel | Label | 否 | 显示连接状态 |
| BackButton | Button | 否 | 返回模式选择界面 |

**状态流转**:
```
HostUrl输入 + PlayerName输入
		   ↓
	  ConnectButton变为可点击
		   ↓
	  点击ConnectButton
		   ↓
	尝试连接WebSocket服务器
		   ↓
	成功 → 等待服务器分配座位 → 进入GameRoom
	失败 → 显示错误状态
```

**连接状态显示**:
- "正在连接..." - 初始连接中
- "连接成功！" - 连接建立成功
- "连接失败：无法连接到服务器" - 连接失败
- "连接已关闭" - 连接意外断开

**离开条件**:
- 连接成功且收到座位分配 → 进入 GameRoom
- BackButton 点击 → 返回 SelectMode

---

### 3.4 游戏房间界面 (GameRoom)

**进入方式**:
- 主机: HostInit 点击 StartButton 成功
- 从机: ClientInit 连接成功并收到座位分配

**交互元素**:
| 元素 | 类型 | 交互规则 |
|------|------|----------|
| Seat[i] | Panel | 点击空座位 → 占据座位；点击已选座位 → 取消选择 |
| ReadyButton | Button | 选择座位后显示；点击 → 切换准备状态 |
| LeaveButton | Button | 点击 → 离开房间，返回选择界面 |

**座位选择流程**:
```
进入房间（未选座位）
		   ↓
	显示 N 个空座位
		   ↓
	点击某个座位 Seat[i]
		   ↓
	座位高亮显示，占据该座位
		   ↓
	显示ReadyButton
		   ↓
	点击ReadyButton
		   ↓
	ReadyButton变为"取消准备"
	座位显示 ✓ 标记
		   ↓
	所有玩家准备 → 游戏开始
```

**座位状态机**:
| 状态 | 视觉效果 | 允许操作 |
|------|----------|----------|
| 空座位 | 灰色背景，无名字 | 点击占据 |
| 已占未准备 | 绿色背景，显示名字 | 点击取消/点击准备 |
| 已占已准备 | 绿色背景，名字+✓ | 点击取消准备 |

**离开房间**:
- 点击 LeaveButton → 断开连接 → 返回 SelectMode

---

## 4. 网络同步场景

### 4.1 消息类型定义

#### 4.1.1 房间状态同步 (room_state)

**发送方**: 主机（服务器）

**触发时机**: 新客户端连接成功时

**消息格式示例**:
```json
{
  "type": "room_state",
  "player_count": 5,
  "players": {
	"0": "主机名",
	"1": "玩家1名",
	"2": "玩家2名"
  }
}
```

**接收方**: 新连接的从机

**同步内容**:
- 房间总人数
- 所有已占座位的玩家名字

---

#### 4.1.2 玩家请求座位 (player_join)

**发送方**: 客户端

**触发时机**: 玩家请求座位

**消息格式示例**:
```json
{
  "type": "player_join",
  "seat_index": 2
}
```

**接收方**: 主机（服务器）

**同步内容**:
- 该玩家请求的座位编号

---

#### 4.1.3 玩家座位更新 (player_update)

**发送方**: 主机（服务器）

**触发时机**: 有玩家成功占据/离开座位时

**消息格式示例**:
```json
{
  "type": "player_update",
  "player_name": "新玩家名",
  "seat_index": 3
}
```

**接收方**: 所有客户端（包括发送方）

**同步内容**:
- 新玩家名字
- 新玩家座位编号

---

#### 4.1.4 准备状态 (player_ready)

**发送方**: 任意玩家客户端

**触发时机**: 玩家点击准备/取消准备按钮

**消息格式示例**:
```json
{
  "type": "player_ready",
  "seat_index": 2,
  "ready": true
}
```

**接收方**: 所有客户端

**同步内容**:
- 准备状态的座位编号
- 是否已准备

---

#### 4.1.5 游戏开始 (game_start)

**发送方**: 主机（服务器）

**触发时机**: 所有玩家都已准备

**消息格式示例**:
```json
{
  "type": "game_start"
}
```

**接收方**: 所有客户端

**同步内容**:
- 游戏正式开始信号

---

#### 4.1.6 玩家离开 (player_leave)

**发送方**: 主机（服务器）

**触发时机**: 有玩家主动离开或断开连接

**消息格式示例**:
```json
{
  "type": "player_leave",
  "seat_index": 2
}
```

**接收方**: 所有客户端

**同步内容**:
- 离开玩家的座位编号

---

### 4.2 同步场景详细流程

#### 场景1: 主机创建房间

```
1. 主机用户设置端口、人数、名字
2. 点击StartButton
3. 服务器启动成功
4. 主机自动占据座位0
5. 广播 player_join 给所有客户端
6. 进入游戏房间界面
```

#### 场景2: 从机加入房间

```
1. 从机用户输入主机URL和名字
2. 点击ConnectButton
3. 建立WebSocket连接
4. 服务器收到连接，分配可用座位
5. 服务器发送 room_state 给从机
6. 服务器发送 player_assigned 给从机
7. 服务器广播 player_join 给所有客户端
8. 从机进入游戏房间界面
```

#### 场景3: 玩家准备

```
1. 玩家点击座位占据
2. 点击ReadyButton
3. 本地更新准备状态
4. 发送 player_ready 消息
5. 服务器广播 player_ready 给所有客户端
6. 所有客户端更新该玩家准备状态
```

#### 场景4: 全部准备，游戏开始

```
1. 玩家A准备
2. 玩家B准备
...
N. 最后一个玩家准备
服务器检测到所有玩家已准备
		   ↓
	发送 game_start 给所有客户端
		   ↓
	所有客户端显示"游戏开始"
```

#### 场景5: 玩家离开

```
1. 玩家点击LeaveButton
2. 本地处理离开逻辑
3. 服务器检测到断开连接
4. 服务器广播 player_leave 给所有客户端
5. 所有客户端清空该座位
6. 如果主机离开，服务器关闭
```

---

### 4.3 异常处理场景

| 异常情况 | 处理方式 |
|----------|----------|
| 客户端连接超时 | 显示"连接失败"，返回ClientInit |
| 连接意外断开 | 显示"连接已关闭"，返回选择界面 |
| 主机离开房间 | 服务器关闭，所有客户端返回选择界面 |
| 网络延迟导致状态不一致 | 使用最新消息覆盖旧状态 |
| 重复连接同一用户 | 拒绝或踢出旧连接 |

---

## 5. 关键交互约束

1. **座位唯一性**: 一个座位只能被一个玩家占据
2. **准备依赖**: 必须先选择座位才能准备
3. **游戏开始条件**: 所有已占座位的玩家都必须准备
4. **主机特权**: 只有主机可以分配座位和广播游戏开始
5. **Web限制**: Web平台不能作为主机
6. **状态持久化**: 离开房间后清除所有本地状态

## 6. 使用MVVM的方式组织代码

### 6.1 整体架构

```
┌─────────────────────────────────────────────────────────┐
│                        View 层                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │SelectMode│ │ HostInit │ │ClientInit│ │GameRoom  │  │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘  │
└───────┼────────────┼────────────┼────────────┼────────┘
        │            │            │            │
        ▼            ▼            ▼            ▼
┌─────────────────────────────────────────────────────────┐
│                    ViewModel 层                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │              GameRoomViewModel                  │    │
│  │  - connection_state    - room_data              │    │
│  │  - players             - current_seat          │    │
│  │  - ready_state         - validation_state      │    │
│  └────────────────────────┬────────────────────────┘    │
│                          │                               │
│  ┌───────────────────────┴────────────────────────┐     │
│  │              NetworkManager (单例)             │     │
│  │  - 连接管理  - 消息收发  - 状态同步            │     │
│  └───────────────────────┬────────────────────────┘     │
└─────────────────────────┼───────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                      Model 层                           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│  │PlayerData│ │RoomData  │ │SeatData  │ │NetMsg    │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘   │
└─────────────────────────────────────────────────────────┘
```

### 6.2 Model 层定义

| 类名 | 职责 | 核心属性 |
|------|------|----------|
| `PlayerData` | 玩家数据 | id, name, seat_index, is_ready |
| `SeatData` | 座位数据 | index, player (nullable), is_empty |
| `RoomData` | 房间数据 | room_id, player_count, seats[], host_name |
| `NetworkMessage` | 网络消息 | type, payload, timestamp |

### 6.3 ViewModel 层设计

#### GameRoomViewModel（集中式）

```
属性:
  - connection_state: Enum (DISCONNECTED, CONNECTING, CONNECTED, ERROR)
  - room_data: RoomData
  - current_player: PlayerData
  - validation_errors: Dictionary

信号:
  - connection_state_changed(state)
  - room_state_updated(room_data)
  - player_joined(player)
  - player_left(seat_index)
  - player_ready_changed(seat_index, is_ready)
  - game_start_triggered()
  - error_occurred(message)

方法:
  - connect_to_host(url, player_name) → void
  - start_host(port, player_name, player_count) → void
  - select_seat(seat_index) → void
  - toggle_ready() → void
  - leave_room() → void
  - _on_network_message(msg) → void  // 内部处理
```

### 6.4 View 层映射

| View | 绑定 ViewModel | 展示数据 |
|------|----------------|----------|
| SelectMode | 无（仅导航） | - |
| HostInit | GameRoomViewModel | port, player_count, player_name, status |
| ClientInit | GameRoomViewModel | host_url, player_name, connection_state |
| GameRoom | GameRoomViewModel | seats, players, ready_state, status |

### 6.5 数据流

```
用户操作 (点击按钮)
       │
       ▼
View 发送信号/调用方法
       │
       ▼
ViewModel 处理业务逻辑
       │
       ├──► NetworkManager 发送网络消息
       │
       ▼
ViewModel 更新内部状态 + 发出信号
       │
       ▼
View 响应信号，更新界面
```

### 6.6 消息处理映射

| 原设计消息 | 新设计处理流程 |
|------------|----------------|
| `room_state` | NetworkManager 接收 → GameRoomViewModel 更新 room_data → 发出 `room_state_updated` 信号 |
| `player_join` | ViewModel 发起 → NetworkManager 发送 |
| `player_update` | 同 room_state 处理流程 |
| `player_ready` | ViewModel 发起 → NetworkManager 发送 → 所有 ViewModel 更新 |
| `game_start` | NetworkManager 接收 → 发出 `game_start_triggered` 信号 |
| `player_leave` | NetworkManager 接收 → 发出 `player_left` 信号 |

### 6.7 文件组织结构

```
res://
├── models/
│   ├── PlayerData.gd
│   ├── SeatData.gd
│   ├── RoomData.gd
│   └── NetworkMessage.gd
├── viewmodels/
│   ├── GameRoomViewModel.gd
│   └── ViewModelBase.gd
├── views/
│   ├── SelectMode.tscn
│   ├── HostInit.tscn
│   ├── ClientInit.tscn
│   └── GameRoom.tscn
├── network/
│   ├── NetworkManager.gd (单例)
│   ├── WebSocketClient.gd
│   └── WebSocketServer.gd
└── main/
    └── Avalon.tscn (入口)
```
