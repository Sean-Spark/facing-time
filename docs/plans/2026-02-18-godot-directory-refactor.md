# 游戏目录结构重构计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 将 GodotProject/game 目录从 avalon 架构重构为 MVVM 架构

**Architecture:** 保留 Avalon.tscn 作为主入口，将 core、network、ui 从 avalon 子目录迁移到 game 根目录，删除无用目录

**Tech Stack:** Godot 4.x, GDScript

---

## Task 1: 迁移 core 目录

**Files:**
- Move: `GodotProject/game/avalon/core/game_manager.gd` → `GodotProject/game/core/game_manager.gd`
- Move: `GodotProject/game/avalon/core/game_config.gd` → `GodotProject/game/core/game_config.gd`
- Move: `GodotProject/game/avalon/core/game_enums.gd` → `GodotProject/game/core/game_enums.gd`
- Move: `GodotProject/game/avalon/core/player.gd` → `GodotProject/game/core/player.gd`
- Move: `GodotProject/game/avalon/core/room_manager.gd` → `GodotProject/game/core/room_manager.gd`

**Step 1: 创建 core 目录并移动文件**

```bash
mkdir -p GodotProject/game/core
mv GodotProject/game/avalon/core/*.gd GodotProject/game/core/
```

**Step 2: 更新 .tscn 文件中的引用路径**

修改所有引用 `res://game/avalon/core/` 的地方为 `res://game/core/`

**Step 3: 提交**

```bash
git add GodotProject/game/core/ GodotProject/game/avalon/core/
git commit -m "refactor: move core to game/core"
```

---

## Task 2: 迁移 server 目录

**Files:**
- Move: `GodotProject/game/avalon/server/wrap_rust_core_server.gd` → `GodotProject/game/server/wrap_rust_core_server.gd`

**Step 1: 创建 server 目录并移动文件**

```bash
mkdir -p GodotProject/game/server
mv GodotProject/game/avalon/server/*.gd GodotProject/game/server/
```

**Step 2: 提交**

```bash
git add GodotProject/game/server/ GodotProject/game/avalon/server/
git commit -m "refactor: move server to game/server"
```

---

## Task 3: 迁移 ui 目录

**Files:**
- Move: `GodotProject/game/avalon/ui/*.tscn` → `GodotProject/game/ui/`
- Move: `GodotProject/game/avalon/ui/*.gd` → `GodotProject/game/ui/`

**Step 1: 创建 ui 目录并移动文件**

```bash
mkdir -p GodotProject/game/ui
mv GodotProject/game/avalon/ui/*.tscn GodotProject/game/ui/
mv GodotProject/game/avalon/ui/*.gd GodotProject/game/ui/
```

**Step 2: 更新 .tscn 文件中的引用路径**

修改所有引用 `res://game/avalon/ui/` 的地方为 `res://game/ui/`

**Step 3: 提交**

```bash
git add GodotProject/game/ui/ GodotProject/game/avalon/ui/
git commit -m "refactor: move ui to game/ui"
```

---

## Task 4: 处理重复网络代码

**Files:**
- Delete: `GodotProject/game/avalon/network/` (使用 game/network/ 替代)
- Keep: `GodotProject/game/network/NetworkManager.gd`

**Step 1: 分析网络代码使用情况**

检查 avalon/network 中的代码是否被 UI 层直接调用，如果是，需要迁移或更新引用

**Step 2: 删除重复的网络代码**

```bash
rm -rf GodotProject/game/avalon/network/
```

**Step 3: 提交**

```bash
git rm -r GodotProject/game/avalon/network/
git commit -m "refactor: remove duplicate network code, use game/network/"
```

---

## Task 5: 删除无用目录和文件

**Files:**
- Delete: `GodotProject/game/avalon/` (整个目录)
- Delete: `GodotProject/game/avalon/`
- Delete: `GodotProject/game/阿瓦隆.md`
- Delete: `GodotProject/game/designe.md`

**Step 1: 删除空目录和无用文件**

```bash
rm -rf GodotProject/game/avalon/
rm GodotProject/game/阿瓦隆.md
rm GodotProject/game/designe.md
```

**Step 2: 提交**

```bash
git rm -r GodotProject/game/avalon/
git rm GodotProject/game/阿瓦隆.md GodotProject/game/designe.md
git commit -m "refactor: remove unused avalon directory and docs"
```

---

## Task 6: 验证项目完整性

**Files:**
- Test: Godot 项目编译检查

**Step 1: 运行 Godot 验证脚本**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path GodotProject --headless --script check_all_scripts.gd
```

**Step 2: 验证主场景可以加载**

确保 avalon.tscn (现在在 game/ui/) 可以正常加载

**Step 3: 提交**

```bash
git commit -m "fix: verify project integrity after refactor"
```

---

## 执行方式选择

**Plan complete and saved to `docs/plans/2026-02-18-godot-directory-refactor.md`. Two execution options:**

1. **Subagent-Driven (this session)** - 每个任务派遣子代理
2. **Parallel Session (separate)** - 新会话中执行

Which approach?
