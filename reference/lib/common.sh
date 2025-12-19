#!/usr/bin/env bash

# Copyright 2024 Scripts Project
#
# Licensed under the Apache License, Version 2.0

# 通用工具库
#
# 此库提供了一组常用的工具函数，可以被项目中的其他脚本引用。
#
# 用法：
#   source "${PROJECT_ROOT}/lib/common.sh"
#
# 提供的功能：
#   - 日志函数（log_info, log_error, log_warn, log_debug）
#   - 平台检测（detect_os, detect_arch）
#   - 数组操作（array_contains）
#   - 重试机制（retry）
#   - 工具检查（command_exists, check_prerequisites）
#   - 临时目录管理（ensure_temp_dir, cleanup_temp_dir）

# 防止重复加载
if [[ -n "${__COMMON_LIB_LOADED:-}" ]]; then
    return 0
fi
readonly __COMMON_LIB_LOADED=1

# ============================================================================
# 日志函数
# ============================================================================

# 全局日志级别控制
VERBOSE="${VERBOSE:-0}"
DEBUG="${DEBUG:-0}"

# 信息日志
function log_info() {
    echo "[INFO] $*"
}

# 错误日志（输出到 stderr）
function log_error() {
    echo "[ERROR] $*" >&2
}

# 警告日志（输出到 stderr）
function log_warn() {
    echo "[WARN] $*" >&2
}

# 调试日志（仅在 DEBUG=1 时输出）
function log_debug() {
    if [[ "${DEBUG}" == "1" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# 详细日志（仅在 VERBOSE=1 时输出）
function log_verbose() {
    if [[ "${VERBOSE}" == "1" ]]; then
        echo "[VERBOSE] $*"
    fi
}

# 带时间戳的状态日志
function log_status() {
    local timestamp
    timestamp=$(date +"[%m%d %H:%M:%S]")
    echo "+++ ${timestamp} $*"
}

# ============================================================================
# 平台检测
# ============================================================================

# 检测主机操作系统
#
# 返回值：
#   输出操作系统名称（darwin, linux）
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
            log_error "不支持的操作系统: $(uname -s)"
            exit 1
            ;;
    esac
    echo "${host_os}"
}

# 检测主机架构
#
# 返回值：
#   输出架构名称（amd64, arm64, arm）
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
        s390x*)
            host_arch=s390x
            ;;
        ppc64le*)
            host_arch=ppc64le
            ;;
        *)
            log_error "不支持的架构: $(uname -m)"
            exit 1
            ;;
    esac
    echo "${host_arch}"
}

# 获取平台标识（OS/ARCH）
#
# 返回值：
#   输出平台标识，如 "linux/amd64"
function detect_platform() {
    local os arch
    os=$(detect_os)
    arch=$(detect_arch)
    echo "${os}/${arch}"
}

# ============================================================================
# 数组操作
# ============================================================================

# 检查元素是否在数组中
#
# 参数：
#   $1 - 要搜索的元素
#   $2+ - 数组元素
#
# 返回值：
#   0 - 找到元素
#   1 - 未找到元素
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

# ============================================================================
# 重试机制
# ============================================================================

# 重试执行命令
#
# 参数：
#   $1 - 最大重试次数
#   $2+ - 要执行的命令
#
# 返回值：
#   0 - 命令执行成功
#   1 - 命令执行失败（已达最大重试次数）
function retry() {
    local max_attempts="$1"
    shift
    local attempt=1
    local delay=2

    while [[ ${attempt} -le ${max_attempts} ]]; do
        if "$@"; then
            return 0
        fi

        log_warn "尝试 ${attempt}/${max_attempts} 失败，${delay} 秒后重试..."
        ((attempt++))
        sleep "${delay}"
    done

    log_error "命令执行失败，已重试 ${max_attempts} 次"
    return 1
}

# ============================================================================
# 工具检查
# ============================================================================

# 检查命令是否存在
#
# 参数：
#   $1 - 命令名称
#
# 返回值：
#   0 - 命令存在
#   1 - 命令不存在
function command_exists() {
    local cmd="$1"
    command -v "${cmd}" >/dev/null 2>&1
}

# 检查必需的工具
#
# 参数：
#   $@ - 工具名称列表
#
# 返回值：
#   0 - 所有工具都存在
#   1 - 有工具缺失
function check_prerequisites() {
    local missing_tools=()

    for tool in "$@"; do
        if ! command_exists "${tool}"; then
            missing_tools+=("${tool}")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "缺少必需的工具: ${missing_tools[*]}"
        return 1
    fi

    return 0
}

# ============================================================================
# 文件和目录操作
# ============================================================================

# 确保目录存在
#
# 参数：
#   $1 - 目录路径
#
# 返回值：
#   0 - 目录存在或创建成功
#   1 - 创建失败
function ensure_dir() {
    local dir="$1"

    if [[ ! -d "${dir}" ]]; then
        log_debug "创建目录: ${dir}"
        if ! mkdir -p "${dir}"; then
            log_error "无法创建目录: ${dir}"
            return 1
        fi
    fi

    return 0
}

# 获取文件的绝对路径
#
# 参数：
#   $1 - 文件路径
#
# 返回值：
#   输出文件的绝对路径
function get_abs_path() {
    local path="$1"

    if [[ -d "${path}" ]]; then
        (cd "${path}" && pwd -P)
    elif [[ -f "${path}" ]]; then
        local dir file
        dir=$(dirname "${path}")
        file=$(basename "${path}")
        (cd "${dir}" && echo "$(pwd -P)/${file}")
    else
        log_error "路径不存在: ${path}"
        return 1
    fi
}

# ============================================================================
# 临时目录管理
# ============================================================================

# 临时目录变量
TEMP_DIR=""

# 创建临时目录
#
# 返回值：
#   设置全局变量 TEMP_DIR
function ensure_temp_dir() {
    if [[ -z "${TEMP_DIR}" ]]; then
        TEMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t scripts.XXXXXX)
        log_debug "创建临时目录: ${TEMP_DIR}"
        trap cleanup_temp_dir EXIT
    fi
}

# 清理临时目录
function cleanup_temp_dir() {
    if [[ -n "${TEMP_DIR}" && -d "${TEMP_DIR}" ]]; then
        log_debug "清理临时目录: ${TEMP_DIR}"
        rm -rf "${TEMP_DIR}"
    fi
}

# ============================================================================
# Trap 管理
# ============================================================================

# 添加多个 trap 处理器
#
# 参数：
#   $1 - trap 命令
#   $2+ - 信号名称
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

# ============================================================================
# 网络工具
# ============================================================================

# 等待 URL 响应
#
# 参数：
#   $1 - 要检查的 URL
#   $2 - 检查间隔秒数（默认: 1）
#   $3 - 最大检查次数（默认: 30）
#
# 返回值：
#   0 - URL 响应成功
#   1 - 超时
function wait_for_url() {
    local url="$1"
    local interval="${2:-1}"
    local max_attempts="${3:-30}"
    local attempt=1

    log_info "等待 ${url} 响应..."

    while [[ ${attempt} -le ${max_attempts} ]]; do
        if curl -f -s -o /dev/null "${url}" 2>/dev/null; then
            log_info "URL 响应成功"
            return 0
        fi

        log_debug "尝试 ${attempt}/${max_attempts}..."
        ((attempt++))
        sleep "${interval}"
    done

    log_error "等待 ${url} 超时"
    return 1
}

# ============================================================================
# 版本比较
# ============================================================================

# 比较版本号
#
# 参数：
#   $1 - 版本号 1
#   $2 - 版本号 2
#
# 返回值：
#   0 - 版本号相等
#   1 - 版本号 1 > 版本号 2
#   2 - 版本号 1 < 版本号 2
function version_compare() {
    local ver1="$1"
    local ver2="$2"

    if [[ "${ver1}" == "${ver2}" ]]; then
        return 0
    fi

    local IFS=.
    local i ver1_arr ver2_arr
    read -ra ver1_arr <<< "${ver1}"
    read -ra ver2_arr <<< "${ver2}"

    # 补齐长度
    for ((i=${#ver1_arr[@]}; i<${#ver2_arr[@]}; i++)); do
        ver1_arr[i]=0
    done

    for ((i=0; i<${#ver1_arr[@]}; i++)); do
        if [[ -z ${ver2_arr[i]:-} ]]; then
            ver2_arr[i]=0
        fi

        if ((10#${ver1_arr[i]} > 10#${ver2_arr[i]})); then
            return 1
        fi

        if ((10#${ver1_arr[i]} < 10#${ver2_arr[i]})); then
            return 2
        fi
    done

    return 0
}

# ============================================================================
# 初始化
# ============================================================================

# 库初始化函数
function __common_lib_init() {
    # 检测并导出平台信息
    if [[ -z "${HOST_OS:-}" ]]; then
        HOST_OS=$(detect_os)
        export HOST_OS
    fi

    if [[ -z "${HOST_ARCH:-}" ]]; then
        HOST_ARCH=$(detect_arch)
        export HOST_ARCH
    fi

    if [[ -z "${HOST_PLATFORM:-}" ]]; then
        HOST_PLATFORM="${HOST_OS}/${HOST_ARCH}"
        export HOST_PLATFORM
    fi

    log_debug "通用库已加载 (平台: ${HOST_PLATFORM})"
}

# 执行初始化
__common_lib_init
