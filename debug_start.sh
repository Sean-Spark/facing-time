#!/bin/bash

# 调试启动脚本

echo "=== FacingTime 启动调试 ==="

# 构建项目
echo "1. 构建项目..."
xcodebuild -project FacingTime.xcodeproj \
    -scheme FacingTime_macOS \
    -sdk macosx \
    -configuration Debug \
    build

if [ $? -ne 0 ]; then
    echo "构建失败"
    exit 1
fi

echo ""
echo "2. 获取构建产物路径..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "FacingTime_macOS.app" -type d 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    APP_PATH=$(find . -name "*.app" -type d 2>/dev/null | head -1)
fi

echo "应用路径: $APP_PATH"

if [ -n "$APP_PATH" ]; then
    echo ""
    echo "3. 启动应用..."
    open "$APP_PATH"

    echo ""
    echo "4. 检查进程..."
    sleep 2
    ps aux | grep -i facingtime | grep -v grep

    echo ""
    echo "5. 检查崩溃日志..."
    log show --predicate 'eventMessage CONTAINS "FacingTime"' --last 1m 2>/dev/null | head -30
fi

echo ""
echo "=== 如果应用启动失败，请检查: ==="
echo "- 系统偏好设置 > 安全性与隐私 > 通用"
echo "- 是否有阻止应用运行的提示"
