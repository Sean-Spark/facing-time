# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Godot 4 game project** implementing "Avalon" (阿瓦隆) - a social deduction board game for 5-10 players. The project uses MVVM architecture with WebSocket networking.

## Commands

### Run the Godot project
```
godot --path ~/Projects/facing-time/GodotProject
```

### Run all unit tests
```
timeout 5 godot -s --path ~/Projects/facing-time/GodotProject ~/Projects/facing-time/GodotProject/addons/gut/gut_cmdln.gd  2>&1
```

### Run a specific test file
```
godot --path ~/Projects/facing-time/GodotProject -s res://tests/run_tests.gd
```

## Architecture

### MVVM Pattern
- **Models** (`game/models/`): `RoomData`, `PlayerData`, `SeatData` - extend `RefCounted`, contain pure data
- **ViewModels** (`game/viewmodels/`): `ViewModelBase`, `GameRoomViewModel` - extend `Node`, handle business logic and state
- **Views** (`game/ui/`): Scene files for UI presentation

### Network Layer
- WebSocket-based client-server architecture
- `WebSocketNetwork` manages both server and client modes
- `NetworkMessage` handles message serialization/deserialization

### Key Classes
- `GameRoomViewModel`: Main controller for game room logic (host/join, player seat selection, ready state)
- `RoomData`: Room state including seats and players
- `WebSocketNetwork`: Generic WebSocket manager in `game/network/`

### Testing
- Tests use custom framework (not GUT) located in `GodotProject/tests/`
- Test structure: `test_<module_name>.gd` files with `run_tests()` method
- Test categories: `models/`, `viewmodels/`, `e2e/`