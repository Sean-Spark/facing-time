# WebSocketNetwork 测试设计

**日期**: 2026-02-23
**主题**: 网络模块集成测试

## 概述

为 **WebSocketNetwork** 组件编写集成测试，验证服务器/客户端模式的完整通信流程。

## 需求澄清

- **测试范围**: WebSocketNetwork (高层网络管理器)
- **测试方式**: 集成测试 (本地实际连接)
- **TLS 配置**: 使用现有证书 (res://resources/tls/)

## 测试架构

```
TestWebSocketNetwork (GutTest)
├── 测试夹具 (setup/teardown)
│   ├── _server: WebSocketNetwork (服务器模式)
│   └── _client: WebSocketNetwork (客户端模式)
│
├── 服务器功能测试
│   ├── test_server_start_and_stop          # 服务器启动/停止
│   ├── test_server_listening_state        # 监听状态正确
│   ├── test_get_connected_peers_empty     # 初始无连接
│   ├── test_broadcast_without_clients      # 无客户端时广播
│   └── test_send_to_invalid_peer          # 发送给无效 peer
│
├── 客户端功能测试
│   ├── test_client_connect_and_disconnect # 客户端连接/断开
│   ├── test_client_connection_state       # 连接状态变化
│   └── test_send_without_connection       # 未连接时发送
│
├── 消息通信测试 (服务器-客户端)
│   ├── test_client_to_server_message      # 客户端 → 服务器
│   ├── test_server_to_client_message      # 服务器 → 客户端
│   ├── test_broadcast_to_all_clients      # 广播到所有客户端
│   └── test_multiple_clients_message      # 多客户端消息
│
└── 便捷方法测试
    ├── test_send_player_joined            # 发送玩家加入
    ├── test_send_player_left               # 发送玩家离开
    ├── test_send_player_ready              # 发送准备状态
    └── test_send_chat                      # 发送聊天消息
```

## 测试策略

1. **本地回环测试** - 服务器和客户端都在本地，使用 `ws://127.0.0.1:<port>`
2. **异步等待** - 使用信号和超时机制等待异步连接事件
3. **状态验证** - 每个操作后验证 `connection_state` 和信号发射
4. **清理保证** - 每个测试后确保正确断开连接

## 测试夹具

```gdscript
var _server_network: WebSocketNetwork
var _client_network: WebSocketNetwork
var _test_port: int = 9949
var _connection_timeout: float = 2.0

func before_each():
    _server_network = WebSocketNetwork.new()
    _client_network = WebSocketNetwork.new()
    add_child(_server_network)
    add_child(_client_network)

func after_each():
    _server_network.cleanup()
    _client_network.cleanup()
    _server_network.free()
    _client_network.free()
```

## 关键测试用例示例

```gdscript
func test_client_to_server_message():
    # 启动服务器
    var err = _server_network.start_server(_test_port)
    assert_eq(err, OK, "Server should start")

    # 等待服务器就绪
    await _wait_for_state(_server_network, WebSocketNetwork.ConnectionState.LISTENING)

    # 客户端连接
    err = _client_network.connect_to_server("wss://127.0.0.1:%d" % _test_port)
    assert_eq(err, OK, "Client should connect")

    # 等待连接建立
    await _wait_for_signal(_client_network.connected_to_server)

    # 发送消息并验证
    var received = _await_message(_server_network)
    assert_not_null(received, "Should receive message")
```

## 实现任务

1. 修改 `test_network.gd` 添加完整的集成测试
2. 实现测试夹具和辅助方法
3. 添加服务器功能测试用例
4. 添加客户端功能测试用例
5. 添加消息通信测试用例
6. 添加便捷方法测试用例
7. 运行测试验证
