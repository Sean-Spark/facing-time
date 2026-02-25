# RustCore - 高性能跨平台 Web 服务器库

使用 Rust + Axum 实现的高效并发 Web 服务器，通过 FFI 接口暴露给 Swift/iOS 调用。

## 特性

- **高效并发**: 基于 tokio 异步运行时，支持高并发连接
- **静态文件服务**: 使用 tower-http 提供高效的静态文件服务
- **FFI 接口**: 完整的 C 兼容接口，供 Swift Godot 调用
- **优雅关闭**: 支持优雅关闭机制

## FFI 接口

| 函数 | 描述 |
|------|------|
| `ft_http_server_create()` | 创建服务器实例，返回句柄 |
| `ft_http_server_start(server, address, static_dir)` | 启动服务器 |
| `ft_http_server_stop(server)` | 停止服务器 |
| `ft_http_server_is_running(server)` | 检查服务器运行状态 |
| `ft_http_server_free(server)` | 释放服务器资源 |
| `ft_log_init(callback)` | 初始化日志回调 |
| `ft_log_is_initialized()` | 检查日志是否已初始化 |

## 构建

```bash
# Debug 构建
cargo build

# Release 构建
cargo build --release

# 运行测试
cargo test --test lib_test

# 运行独立示例服务器
cargo run --example simple_server
```

## 运行示例服务器

```bash
cargo run --example simple_server
```

输出：
```
Starting RustCore server at http://0.0.0.0:8080
WebSocket endpoint: ws://0.0.0.0:8080/ws
Press Ctrl+C to stop
```

访问 http://localhost:8080 查看页面，连接 ws://localhost:8080/ws 测试 WebSocket。

## 输出产物

- `target/release/libfacingtime_core.dylib` (macOS)
- `target/release/libfacingtime_core.so` (Linux)
- `target/release/libfacingtime_core.a` (静态库)

## 路由

- `/` - 主页
- `/health` - 健康检查端点
- `/*` - 静态文件服务

## Swift 集成

详见 `Sources/RustCoreIntegration/RustCoreWrapper.swift`

## 依赖

- tokio 1.x
- axum 0.8.x
- tower-http 0.6.x
- hyper 1.x
- parking_lot 0.12
