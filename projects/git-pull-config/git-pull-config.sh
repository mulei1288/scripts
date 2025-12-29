#!/bin/bash

# 基于配置文件的拉取脚本
# 用法：./git_pull_config.sh [配置文件]

CONFIG_FILE="${1:-projects.config}"

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo "配置文件 $CONFIG_FILE 不存在"
    exit 1
fi

# 检查yq是否安装（用于解析YAML）
if ! command -v yq &> /dev/null; then
    echo "请先安装 yq: brew install yq 或 sudo apt-get install yq"
    exit 1
fi

# 获取项目数量
project_count=$(yq e '.projects | length' "$CONFIG_FILE")

echo "开始处理 $project_count 个项目..."

# 遍历所有项目
for ((i=0; i<project_count; i++)); do
    name=$(yq e ".projects[$i].name" "$CONFIG_FILE")
    repo=$(yq e ".projects[$i].repo" "$CONFIG_FILE")
    branch=$(yq e ".projects[$i].branch" "$CONFIG_FILE")
    path=$(yq e ".projects[$i].path" "$CONFIG_FILE")

    echo ""
    echo "========================================"
    echo "项目: $name"
    echo "路径: $path"
    echo "分支: $branch"
    echo "========================================"

    # 如果指定了path，就使用path，否则使用name
    target_dir="${path:-$name}"

    # 处理项目
    if [ -d "$target_dir" ]; then
        echo "进入目录: $target_dir"
        cd "$target_dir" || continue

        echo "拉取最新代码..."
        git fetch --all

        echo "切换到分支: $branch"
        # 尝试切换到分支，如果不存在则创建
        git checkout "$branch" 2>/dev/null || git checkout -b "$branch" "origin/$branch"

        echo "更新代码..."
        git pull origin "$branch"

        cd - > /dev/null
    else
        echo "目录不存在，开始克隆..."
        git clone "$repo" "$target_dir"

        cd "$target_dir" || continue

        echo "切换到分支: $branch"
        git checkout "$branch" 2>/dev/null || echo "分支 $branch 不存在，使用默认分支"

        cd - > /dev/null
    fi

    echo "完成!"
done

echo ""
echo "所有项目处理完成!"