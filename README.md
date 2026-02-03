# FacingTime

基于局域网的Web服务器应用，支持 iOS 和 macOS 平台。

## 功能特性

- **Web服务器**: 在设备上启动HTTP服务器，支持静态文件服务和REST API
- **聊天室**: 通过浏览器访问 `/chat` 页面即可参与实时聊天
- **局域网发现**: 使用Bonjour自动发现附近的服务器
- **跨平台**: 原生支持 iOS 16+ 和 macOS 13+

## 架构设计

```
┌─────────────────────────────────────────────────────────────────┐
│                      FacingTime WebServer                        │
├─────────────────────────────────────────────────────────────────┤
│  SwiftUI Views (跨平台UI)                                       │
│  ├── ServerView       - 服务器状态和控制                         │
│  ├── DeviceDiscoveryView - 局域网服务器发现                       │
│  └── SettingsView     - 应用设置                                 │
├─────────────────────────────────────────────────────────────────┤
│  Swift Services (原生网络通讯)                                   │
│  └── NetworkService   - Network.framework + Bonjour              │
├─────────────────────────────────────────────────────────────────┤
│  Core (HTTP服务器核心)                                           │
│  ├── HttpServer       - HTTP协议处理                            │
│  ├── Router           - 请求路由                                 │
│  ├── ChatRoom         - 聊天消息管理                            │
│  └── Handlers         - 业务处理器                               │
└─────────────────────────────────────────────────────────────────┘
```

## API 端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/` | GET | 主页HTML |
| `/chat` | GET | 聊天室页面 |
| `/api/status` | GET | 服务器状态 |
| `/api/messages` | GET | 获取消息列表 |
| `/api/messages` | POST | 发送消息 |

## 快速开始

### 1. 安装依赖

```bash
# 安装 XcodeGen (如果未安装)
brew install xcodegen

# 生成项目
./setup.sh
```

### 2. 运行应用

macOS:
```bash
./debug_start.sh
```

iOS:
- 在Xcode中选择iOS Simulator或设备
- 按Cmd+R运行

### 3. 使用

1. 打开应用，点击"启动服务器"
2. 在浏览器中访问显示的地址
3. 访问 `/chat` 页面开始聊天

## 项目结构

```
facing-time/
├── Sources/
│   ├── App/              # 应用入口和状态管理
│   ├── Core/             # HTTP服务器核心 (Swift实现)
│   ├── Services/         # 网络服务层
│   └── Views/            # SwiftUI视图
├── Resources/            # 资源文件
├── RustCore/            # Rust核心模块 (未来扩展)
├── project.yml           # XcodeGen配置
└── setup.sh             # 项目初始化脚本
```

## 技术栈

- **UI**: SwiftUI
- **网络**: Network.framework, Bonjour (NSNetService)
- **HTTP服务器**: 原生Swift实现
- **目标平台**: iOS 16.0+, macOS 13.0+

## 扩展

### 迁移到Rust核心

项目已包含Rust核心模块 (`Sources/RustCore/`)，可用于替换Swift HTTP服务器：

```bash
# 编译Rust库
cd Sources/RustCore
./build.sh
```

### 添加新API端点

在 `Sources/Core/HttpServer.swift` 的 `Router` 中添加新路由：

```swift
private func setupRoutes() {
    routes["GET:/api/your-endpoint"] = { _ in
        self.handleYourEndpoint()
    }
}
```
