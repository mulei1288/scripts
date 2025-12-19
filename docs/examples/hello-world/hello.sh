#!/usr/bin/env bash

# Copyright 2024 Scripts Project
#
# Licensed under the Apache License, Version 2.0

# 脚本说明：Hello World 示例脚本
#
# 用法：
#   hello.sh [选项] [名称]
#
# 选项：
#   -v, --verbose        启用详细输出
#   -h, --help           显示帮助信息
#
# 示例：
#   hello.sh
#   hello.sh Alice
#   hello.sh -v Bob

# 错误处理设置
set -o errexit
set -o nounset
set -o pipefail

# 环境初始化
unset CDPATH
umask 0022

# 定位脚本根目录
SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

# 常量定义
readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="1.0.0"

# 全局变量（带默认值）
VERBOSE="${VERBOSE:-0}"
DEBUG="${DEBUG:-0}"

# 日志函数（从 reference/lib/common.sh 复制）
function log_info() {
    echo "[INFO] $*"
}

function log_error() {
    echo "[ERROR] $*" >&2
}

function log_debug() {
    if [[ "${DEBUG}" == "1" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# 显示帮助信息
function show_help() {
    cat <<EOF
用法: ${SCRIPT_NAME} [选项] [名称]

说明：
  一个简单的 Hello World 脚本，用于向用户打招呼。

选项：
  -v, --verbose        启用详细输出
  -h, --help           显示帮助信息

参数：
  [名称]               要打招呼的名称（默认：World）

示例：
  ${SCRIPT_NAME}                    # 输出: Hello, World!
  ${SCRIPT_NAME} Alice              # 输出: Hello, Alice!
  ${SCRIPT_NAME} -v Bob             # 详细模式

环境变量：
  DEBUG=1              启用调试日志
  VERBOSE=1            启用详细输出

版本: ${VERSION}
EOF
}

# 解析命令行参数
function parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                # 位置参数
                POSITIONAL_ARGS+=("$1")
                shift
                ;;
        esac
    done
}

# 主函数
function main() {
    local -a POSITIONAL_ARGS=()
    
    # 解析参数
    parse_args "$@"
    
    # 获取名称（默认为 World）
    local name="${POSITIONAL_ARGS[0]:-World}"
    
    log_debug "脚本根目录: ${SCRIPT_ROOT}"
    log_debug "名称: ${name}"
    
    # 详细模式
    if [[ "${VERBOSE}" == "1" ]]; then
        local timestamp
        timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        log_info "当前时间: ${timestamp}"
        log_info "脚本版本: ${VERSION}"
    fi
    
    # 输出问候语
    echo "Hello, ${name}!"
    
    # 详细模式下输出额外信息
    if [[ "${VERBOSE}" == "1" ]]; then
        log_info "问候完成"
    fi
}

# 执行主函数
main "$@"
