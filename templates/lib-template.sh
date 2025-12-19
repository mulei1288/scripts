#!/usr/bin/env bash

# Copyright 2024 项目名称
#
# Licensed under the Apache License, Version 2.0

# 库文件说明：[在此描述库的功能]
#
# 此文件提供了一组可复用的工具函数，可以被其他脚本引用。
#
# 用法：
#   source "${PROJECT_ROOT}/lib/lib-template.sh"
#
# 提供的函数：
#   - example_function: 示例函数
#   - another_function: 另一个示例函数

# 防止重复加载
if [[ -n "${__LIB_TEMPLATE_LOADED:-}" ]]; then
    return 0
fi
readonly __LIB_TEMPLATE_LOADED=1

# 库常量定义
readonly LIB_VERSION="1.0.0"

# 示例函数：检查元素是否在数组中
#
# 参数：
#   $1 - 要搜索的元素
#   $2+ - 数组元素
#
# 返回值：
#   0 - 找到元素
#   1 - 未找到元素
#
# 示例：
#   items=("apple" "banana" "orange")
#   if array_contains "banana" "${items[@]}"; then
#       echo "找到了"
#   fi
function array_contains() {
    local search="$1"
    local element
    shift

    for element; do
        if [[ "${element}" == "${search}" ]]; then
            return 0
        fi
    done

    return 1
}

# 示例函数：检测主机操作系统
#
# 返回值：
#   输出操作系统名称（darwin, linux）
#
# 示例：
#   os=$(detect_os)
#   echo "当前操作系统: ${os}"
function detect_os() {
    local host_os
    case "$(uname -s)" in
        Darwin)
            host_os=darwin
            ;;
        Linux)
            host_os=linux
            ;;
        *)
            echo "错误：不支持的操作系统" >&2
            exit 1
            ;;
    esac
    echo "${host_os}"
}

# 示例函数：检测主机架构
#
# 返回值：
#   输出架构名称（amd64, arm64, arm）
#
# 示例：
#   arch=$(detect_arch)
#   echo "当前架构: ${arch}"
function detect_arch() {
    local host_arch
    case "$(uname -m)" in
        x86_64*|i?86_64*|amd64*)
            host_arch=amd64
            ;;
        aarch64*|arm64*)
            host_arch=arm64
            ;;
        arm*)
            host_arch=arm
            ;;
        *)
            echo "错误：不支持的架构" >&2
            exit 1
            ;;
    esac
    echo "${host_arch}"
}

# 示例函数：重试执行命令
#
# 参数：
#   $1 - 最大重试次数
#   $2+ - 要执行的命令
#
# 返回值：
#   0 - 命令执行成功
#   1 - 命令执行失败（已达最大重试次数）
#
# 示例：
#   retry 3 curl -f https://example.com/api
#   retry 5 docker pull myimage:latest
function retry() {
    local max_attempts="$1"
    shift
    local attempt=1

    while [[ ${attempt} -le ${max_attempts} ]]; do
        if "$@"; then
            return 0
        fi

        echo "尝试 ${attempt}/${max_attempts} 失败，重试..." >&2
        ((attempt++))
        sleep 2
    done

    echo "错误：命令执行失败，已重试 ${max_attempts} 次" >&2
    return 1
}

# 示例函数：确保目录存在
#
# 参数：
#   $1 - 目录路径
#
# 返回值：
#   0 - 目录存在或创建成功
#   1 - 创建失败
#
# 示例：
#   ensure_dir "/tmp/myapp"
function ensure_dir() {
    local dir="$1"

    if [[ ! -d "${dir}" ]]; then
        if ! mkdir -p "${dir}"; then
            echo "错误：无法创建目录: ${dir}" >&2
            return 1
        fi
    fi

    return 0
}

# 示例函数：检查命令是否存在
#
# 参数：
#   $1 - 命令名称
#
# 返回值：
#   0 - 命令存在
#   1 - 命令不存在
#
# 示例：
#   if command_exists docker; then
#       echo "Docker 已安装"
#   fi
function command_exists() {
    local cmd="$1"
    command -v "${cmd}" >/dev/null 2>&1
}

# 示例函数：获取文件的绝对路径
#
# 参数：
#   $1 - 文件路径
#
# 返回值：
#   输出文件的绝对路径
#
# 示例：
#   abs_path=$(get_abs_path "relative/path/file.txt")
function get_abs_path() {
    local path="$1"

    if [[ -d "${path}" ]]; then
        (cd "${path}" && pwd -P)
    elif [[ -f "${path}" ]]; then
        local dir
        local file
        dir=$(dirname "${path}")
        file=$(basename "${path}")
        (cd "${dir}" && echo "$(pwd -P)/${file}")
    else
        echo "错误：路径不存在: ${path}" >&2
        return 1
    fi
}

# 示例函数：添加多个 trap 处理器
#
# 参数：
#   $1 - trap 命令
#   $2+ - 信号名称
#
# 示例：
#   trap_add cleanup_function EXIT
#   trap_add error_handler ERR
function trap_add() {
    local trap_add_cmd="$1"
    shift

    for trap_add_name in "$@"; do
        local existing_cmd
        existing_cmd=$(trap -p "${trap_add_name}" | awk -F"'" '{print $2}')

        if [[ -z "${existing_cmd}" ]]; then
            # shellcheck disable=SC2064
            trap "${trap_add_cmd}" "${trap_add_name}"
        else
            # shellcheck disable=SC2064
            trap "${trap_add_cmd};${existing_cmd}" "${trap_add_name}"
        fi
    done
}

# 示例函数：等待 URL 响应
#
# 参数：
#   $1 - 要检查的 URL
#   $2 - 检查间隔秒数（默认: 1）
#   $3 - 最大检查次数（默认: 30）
#
# 返回值：
#   0 - URL 响应成功
#   1 - 超时
#
# 示例：
#   wait_for_url "http://localhost:8080" 2 60
function wait_for_url() {
    local url="$1"
    local interval="${2:-1}"
    local max_attempts="${3:-30}"
    local attempt=1

    echo "等待 ${url} 响应..." >&2

    while [[ ${attempt} -le ${max_attempts} ]]; do
        if curl -f -s -o /dev/null "${url}"; then
            echo "URL 响应成功" >&2
            return 0
        fi

        echo "尝试 ${attempt}/${max_attempts}..." >&2
        ((attempt++))
        sleep "${interval}"
    done

    echo "错误：等待 ${url} 超时" >&2
    return 1
}

# 在库加载时执行的初始化代码（如果需要）
function __lib_init() {
    # 初始化逻辑
    :
}

# 执行初始化
__lib_init
