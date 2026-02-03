#!/bin/bash

set -e

echo "=== FacingTime 项目设置 ==="
echo ""

# 检查 XcodeGen 是否安装
if ! command -v xcodegen &> /dev/null; then
    echo "XcodeGen 未安装，正在通过 Homebrew 安装..."
    if ! command -v brew &> /dev/null; then
        echo "错误: Homebrew 未安装，请先安装 Homebrew"
        echo "安装 Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    brew install xcodegen
fi

echo "XcodeGen 版本: $(xcodegen --version)"
echo ""

# 生成 Xcode 项目
echo "正在生成 Xcode 项目..."
xcodegen generate

echo ""
echo "=== 项目设置完成 ==="
echo ""
echo "构建命令:"
echo ""
echo "iOS (模拟器):"
echo "  xcodebuild -project FacingTime.xcodeproj -scheme FacingTime_iOS -sdk iphonesimulator build"
echo ""
echo "macOS:"
echo "  xcodebuild -project FacingTime.xcodeproj -scheme FacingTime_macOS -sdk macosx build"
echo ""
echo "运行测试:"
echo "  ./run_tests.sh"
echo ""
echo "单独运行 iOS 测试:"
echo "  xcodebuild -project FacingTime.xcodeproj -scheme FacingTime_iOS -sdk iphonesimulator test"
echo ""
echo "单独运行 macOS 测试:"
echo "  xcodebuild -project FacingTime.xcodeproj -scheme FacingTime_macOS -sdk macosx test"
echo ""
echo "在 Xcode 中打开:"
echo "  open FacingTime.xcodeproj"
echo ""
echo "运行前请确保:"
echo "  1. 在 Xcode 中选择正确的签名团队"
echo "  2. iOS 目标需要选择开发设备"
