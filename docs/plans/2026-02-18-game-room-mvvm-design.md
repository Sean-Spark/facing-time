# 游戏房间系统 MVVM 重构实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将游戏房间系统重构为 MVVM 架构，分离 UI 逻辑与业务逻辑

**Architecture:** 采用集中式 ViewModel + 单例 NetworkManager 模式，Model 层定义数据结构，View 层负责渲染，ViewModel 层处理业务逻辑

**Tech Stack:** Godot 4.x, GDScript

---

## 准备工作

### Task 1: 创建项目目录结构

**Files:**
- Create: `GodotProject/game/models/`
- Create: `GodotProject/game/viewmodels/`
- Create: `GodotProject/game/network/`

**Step 1: 创建目录结构**

```bash
mkdir -p GodotProject/game/models GodotProject/game/viewmodels GodotProject/game/network
```

---

## Model 层实现

### Task 2: 实现 PlayerData 模型

**Files:**
- Create: `GodotProject/game/models/PlayerData.gd`

**Step 1: 创建 PlayerData.gd**

```gdscript
class_name PlayerData
extends RefCounted

var id: String = ""
var name: String = ""
var seat_index: int = -1
var is_ready: bool = false

func _init(p_id: String = "", p_name: String = "", p_seat: int = -1):
    id = p_id
    name = p_name
    seat_index = p_seat

func to_dict() -> Dictionary:
    return {
        "id": id,
        "name": name,
        "seat_index": seat_index,
        "is_ready": is_ready
    }

static func from_dict(data: Dictionary) -> PlayerData:
    return PlayerData.new(
        data.get("id", ""),
        data.get("name", ""),
        data.get("seat_index", -1)
    )
```

**Step 2: 提交**

```bash
git add GodotProject/game/models/PlayerData.gd
git commit -m "feat: add PlayerData model class"
```

---

### Task 3: 实现 SeatData 模型

**Files:**
- Create: `GodotProject/game/models/SeatData.gd`

**Step 1: 创建 SeatData.gd**

```gdscript
class_name SeatData
extends RefCounted

var index: int = 0
var player: PlayerData = null

func _init(seat_index: int = 0):
    index = seat_index

func is_empty() -> bool:
    return player == null

func assign_player(p: PlayerData) -> void:
    player = p
    player.seat_index = index

func clear_player() -> void:
    if player:
        player.seat_index = -1
        player = null
```

**Step 2: 提交**

```bash
git add GodotProject/game/models/SeatData.gd
git commit -m "feat: add SeatData model class"
```

---

### Task 4: 实现 RoomData 模型

**Files:**
- Create: `GodotProject/game/models/RoomData.gd`

**Step 1: 创建 RoomData.gd**

```gdscript
class_name RoomData
extends RefCounted

var room_id: String = ""
var player_count: int = 5
var seats: Array[SeatData] = []
var host_name: String = ""

func _init(count: int = 5):
    player_count = count
    for i in range(count):
        seats.append(SeatData.new(i))

func get_seat(index: int) -> SeatData:
    if index >= 0 and index < seats.size():
        return seats[index]
    return null

func find_empty_seat() -> SeatData:
    for seat in seats:
        if seat.is_empty():
            return seat
    return null

func get_all_players() -> Array[PlayerData]:
    var result: Array[PlayerData] = []
    for seat in seats:
        if not seat.is_empty():
            result.append(seat.player)
    return result

func is_all_ready() -> bool:
    for seat in seats:
        if not seat.is_empty() and not seat.player.is_ready:
            return false
    return get_all_players().size() > 0
```

**Step 2: 提交**

```bash
git add GodotProject/game/models/RoomData.gd
git commit -m "feat: add RoomData model class"
```

---

### Task 5: 实现 NetworkMessage 模型

**Files:**
- Create: `GodotProject/game/models/NetworkMessage.gd`

**Step 1: 创建 NetworkMessage.gd**

```gdscript
class_name NetworkMessage
extends RefCounted

enum Type {
    ROOM_STATE,
    PLAYER_JOIN,
    PLAYER_UPDATE,
    PLAYER_READY,
    GAME_START,
    PLAYER_LEAVE
}

var type: Type = Type.ROOM_STATE
var payload: Dictionary = {}
var timestamp: int = 0

func _init(msg_type: Type = Type.ROOM_STATE, data: Dictionary = {}):
    type = msg_type
    payload = data
    timestamp = Time.get_unix_time_from_system()

static func from_json(json_string: String) -> NetworkMessage:
    var json = JSON.new()
    var error = json.parse(json_string)
    if error != OK:
        return null
    var data = json.data
    var msg_type = Type.ROOM_STATE
    match data.get("type", ""):
        "room_state": msg_type = Type.ROOM_STATE
        "player_join": msg_type = Type.PLAYER_JOIN
        "player_update": msg_type = Type.PLAYER_UPDATE
        "player_ready": msg_type = Type.PLAYER_READY
        "game_start": msg_type = Type.GAME_START
        "player_leave": msg_type = Type.PLAYER_LEAVE
    return NetworkMessage.new(msg_type, data)

func to_json() -> String:
    var type_str = ""
    match type:
        Type.ROOM_STATE: type_str = "room_state"
        Type.PLAYER_JOIN: type_str = "player_join"
        Type.PLAYER_UPDATE: type_str = "player_update"
        Type.PLAYER_READY: type_str = "player_ready"
        Type.GAME_START: type_str = "game_start"
        Type.PLAYER_LEAVE: type_str = "player_leave"
    payload["type"] = type_str
    return JSON.stringify(payload)
```

**Step 2: 提交**

```bash
git add GodotProject/game/models/NetworkMessage.gd
git commit -m "feat: add NetworkMessage model class"
```

---

## Network 层实现

### Task 6: 实现 NetworkManager 单例

**Files:**
- Create: `GodotProject/game/network/NetworkManager.gd`

**Step 1: 创建 NetworkManager.gd**

```gdscript
extends Node

signal message_received(msg: NetworkMessage)
signal connection_state_changed(state: int)
signal error_occurred(message: String)

enum ConnectionState {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    ERROR
}

var state: ConnectionState = ConnectionState.DISCONNECTED
var is_host: bool = false
var _ws_peer: WebSocketPeer = null

func _ready():
    add_to_group("NetworkManager")

func start_host(port: int) -> bool:
    var server = WebSocketServer.new()
    server.bind_ip = "*"
    var err = server.listen(port)
    if err != OK:
        error_occurred.emit("Failed to start server on port " + str(port))
        return false

    _ws_peer = server
    is_host = true
    state = ConnectionState.CONNECTED
    connection_state_changed.emit(state)
    return true

func connect_to_host(url: String) -> bool:
    _ws_peer = WebSocketPeer.new()
    var err = _ws_peer.connect_to_url(url)
    if err != OK:
        error_occurred.emit("Failed to connect to " + url)
        state = ConnectionState.ERROR
        connection_state_changed.emit(state)
        return false

    state = ConnectionState.CONNECTING
    connection_state_changed.emit(state)
    return true

func send_message(msg: NetworkMessage) -> bool:
    if state != ConnectionState.CONNECTED:
        return false
    var json_str = msg.to_json()
    _ws_peer.send_text(json_str)
    return true

func _process(_delta):
    if _ws_peer:
        _ws_peer.poll()
        var state = _ws_peer.get_ready_state()
        if state == WebSocketPeer.STATE_OPEN:
            while _ws_peer.get_available_packet_count():
                var packet = _ws_peer.get_packet()
                var json_str = packet.get_string_from_utf8()
                var msg = NetworkMessage.from_json(json_str)
                if msg:
                    message_received.emit(msg)
        elif state == WebSocketPeer.STATE_CLOSED:
            self.state = ConnectionState.DISCONNECTED
            connection_state_changed.emit(self.state)

func disconnect():
    if _ws_peer:
        _ws_peer.close()
        _ws_peer = null
    state = ConnectionState.DISCONNECTED
    connection_state_changed.emit(state)
```

**Step 2: 提交**

```bash
git add GodotProject/game/network/NetworkManager.gd
git commit -m "feat: add NetworkManager singleton"
```

---

## ViewModel 层实现

### Task 7: 实现 ViewModelBase 基类

**Files:**
- Create: `GodotProject/game/viewmodels/ViewModelBase.gd`

**Step 1: 创建 ViewModelBase.gd**

```gdscript
class_name ViewModelBase
extends Node

signal property_changed(property_name: String, value: Variant)

func _notify_property_change(prop: String, value: Variant):
    property_changed.emit(prop, value)
```

**Step 2: 提交**

```bash
git add GodotProject/game/viewmodels/ViewModelBase.gd
git commit -m "feat: add ViewModelBase class"
```

---

### Task 8: 实现 GameRoomViewModel

**Files:**
- Create: `GodotProject/game/viewmodels/GameRoomViewModel.gd`

**Step 1: 创建 GameRoomViewModel.gd**

```gdscript
class_name GameRoomViewModel
extends ViewModelBase

signal connection_state_changed(state: int)
signal room_state_updated(room_data: RoomData)
signal player_joined(player: PlayerData)
signal player_left(seat_index: int)
signal player_ready_changed(seat_index: int, is_ready: bool)
signal game_start_triggered()
signal error_occurred(message: String)

enum ConnectionState {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    ERROR
}

var connection_state: int = ConnectionState.DISCONNECTED:
    set(v):
        connection_state = v
        connection_state_changed.emit(v)

var room_data: RoomData = null
var current_player: PlayerData = null
var validation_errors: Dictionary = {}

var _network: Node = null

func _ready():
    _network = get_tree().get_first_node_in_group("NetworkManager")
    if _network:
        _network.message_received.connect(_on_network_message)
        _network.connection_state_changed.connect(_on_connection_state_changed)
        _network.error_occurred.connect(_on_error)

func start_host(port: int, player_name: String, player_count: int) -> bool:
    if not _validate_host_init(port, player_name, player_count):
        return false

    if _network.start_host(port):
        room_data = RoomData.new(player_count)
        current_player = PlayerData.new(str(OS.get_unix_time()), player_name, 0)
        room_data.get_seat(0).assign_player(current_player)
        connection_state = ConnectionState.CONNECTED
        return true
    return false

func connect_to_host(url: String, player_name: String) -> bool:
    if player_name.is_empty():
        validation_errors["player_name"] = "Player name is required"
        return false

    if _network.connect_to_host(url):
        current_player = PlayerData.new(str(OS.get_unix_time()), player_name)
        connection_state = ConnectionState.CONNECTING
        return true
    return false

func select_seat(seat_index: int) -> bool:
    if not room_data or not current_player:
        return false

    var seat = room_data.get_seat(seat_index)
    if not seat or not seat.is_empty():
        return false

    # 清除当前位置
    if current_player.seat_index >= 0:
        var old_seat = room_data.get_seat(current_player.seat_index)
        if old_seat:
            old_seat.clear_player()

    seat.assign_player(current_player)

    # 发送网络消息
    var msg = NetworkMessage.new(NetworkMessage.Type.PLAYER_JOIN, {
        "seat_index": seat_index
    })
    _network.send_message(msg)

    room_state_updated.emit(room_data)
    return true

func toggle_ready() -> bool:
    if not current_player or current_player.seat_index < 0:
        return false

    current_player.is_ready = not current_player.is_ready

    var msg = NetworkMessage.new(NetworkMessage.Type.PLAYER_READY, {
        "seat_index": current_player.seat_index,
        "ready": current_player.is_ready
    })
    _network.send_message(msg)

    player_ready_changed.emit(current_player.seat_index, current_player.is_ready)

    # 检查是否全部准备
    if room_data.is_all_ready():
        var start_msg = NetworkMessage.new(NetworkMessage.Type.GAME_START, {})
        _network.send_message(start_msg)
        game_start_triggered.emit()

    return true

func leave_room():
    if _network:
        _network.disconnect()
    _reset_state()

func _validate_host_init(port: int, player_name: String, player_count: int) -> bool:
    validation_errors.clear()

    if port < 1 or port > 65535:
        validation_errors["port"] = "Port must be between 1 and 65535"
    if player_name.is_empty():
        validation_errors["player_name"] = "Player name is required"
    if player_count < 5 or player_count > 10:
        validation_errors["player_count"] = "Player count must be between 5 and 10"

    if not validation_errors.is_empty():
        var first_error = validation_errors.values()[0]
        error_occurred.emit(first_error)
        return false
    return true

func _on_network_message(msg: NetworkMessage):
    match msg.type:
        NetworkMessage.Type.ROOM_STATE:
            _handle_room_state(msg.payload)
        NetworkMessage.Type.PLAYER_JOIN:
            _handle_player_join(msg.payload)
        NetworkMessage.Type.PLAYER_UPDATE:
            _handle_player_update(msg.payload)
        NetworkMessage.Type.PLAYER_READY:
            _handle_player_ready(msg.payload)
        NetworkMessage.Type.GAME_START:
            game_start_triggered.emit()
        NetworkMessage.Type.PLAYER_LEAVE:
            _handle_player_leave(msg.payload)

func _handle_room_state(payload: Dictionary):
    if not room_data:
        room_data = RoomData.new(payload.get("player_count", 5))

    var players = payload.get("players", {})
    for seat_idx_str in players:
        var seat_idx = int(seat_idx_str)
        var player_name = players[seat_idx_str]
        var seat = room_data.get_seat(seat_idx)
        if seat and seat.is_empty():
            var player = PlayerData.new(str(seat_idx), player_name, seat_idx)
            seat.assign_player(player)

    room_state_updated.emit(room_data)

func _handle_player_join(payload: Dictionary):
    var seat_index = payload.get("seat_index", -1)
    var player_name = payload.get("player_name", "Unknown")
    var seat = room_data.get_seat(seat_index)
    if seat and seat.is_empty():
        var player = PlayerData.new(str(seat_index), player_name, seat_index)
        seat.assign_player(player)
        player_joined.emit(player)

func _handle_player_update(payload: Dictionary):
    var seat_index = payload.get("seat_index", -1)
    var player_name = payload.get("player_name", "Unknown")
    var seat = room_data.get_seat(seat_index)
    if seat and seat.is_empty():
        var player = PlayerData.new(str(seat_index), player_name, seat_index)
        seat.assign_player(player)
        player_joined.emit(player)

func _handle_player_ready(payload: Dictionary):
    var seat_index = payload.get("seat_index", -1)
    var is_ready = payload.get("ready", false)
    var seat = room_data.get_seat(seat_index)
    if seat and seat.player:
        seat.player.is_ready = is_ready
        player_ready_changed.emit(seat_index, is_ready)

func _handle_player_leave(payload: Dictionary):
    var seat_index = payload.get("seat_index", -1)
    var seat = room_data.get_seat(seat_index)
    if seat:
        seat.clear_player()
        player_left.emit(seat_index)

func _on_connection_state_changed(state: int):
    connection_state = state

func _on_error(message: String):
    error_occurred.emit(message)

func _reset_state():
    room_data = null
    current_player = null
    connection_state = ConnectionState.DISCONNECTED
```

**Step 2: 提交**

```bash
git add GodotProject/game/viewmodels/GameRoomViewModel.gd
git commit -m "feat: add GameRoomViewModel with business logic"
```

---

## 整合与测试

### Task 9: 创建测试场景验证 MVVM 架构

**Files:**
- Create: `GodotProject/game/test_mvvm.tscn`

**Step 1: 创建简单的测试场景**

```gdscript
extends Node

var viewmodel: GameRoomViewModel
var network: Node

func _ready():
    # 初始化网络管理器
    network = get_tree().get_first_node_in_group("NetworkManager")
    if not network:
        network = load("res://game/network/NetworkManager.gd").new()
        get_tree().root.add_child(network)

    # 初始化 ViewModel
    viewmodel = GameRoomViewModel.new()
    get_tree().root.add_child(viewmodel)

    # 测试: 创建房间
    var success = viewmodel.start_host(8765, "TestHost", 5)
    print("Host created: ", success)

    # 测试: 选择座位
    if success:
        success = viewmodel.select_seat(1)
        print("Seat selected: ", success)

    # 测试: 准备
    if success:
        success = viewmodel.toggle_ready()
        print("Ready toggled: ", success)

    # 测试: 离开
    viewmodel.leave_room()
    print("Left room")
```

**Step 2: 提交**

```bash
git add GodotProject/game/test_mvvm.tscn
git commit -f "feat: add MVVM test scene"
```

---

## 执行方式选择

**Plan complete and saved to `docs/plans/2026-02-18-game-room-mvvm-design.md`. Two execution options:**

1. **Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

2. **Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
