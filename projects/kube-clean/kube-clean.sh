#!/usr/bin/env bash

# Copyright 2025 kube-clean
#
# Licensed under the Apache License, Version 2.0

# 脚本说明：集群清理脚本，用于清理 Kubernetes 集群的无用数据
#
# 用法：
#   clean.sh [选项]
#
# 选项：
#   -d, --debug          启用调试模式
#   -h, --help           显示帮助信息
#
# 示例：
#   ./clean.sh
#   ./clean.sh --debug

# 错误处理设置
set -o errexit   # 命令失败时立即退出
set -o nounset   # 使用未定义变量时报错
set -o pipefail  # 管道中任何命令失败都返回失败状态

# 环境初始化
unset CDPATH
umask 0022

# 定位脚本根目录
SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

# 常量定义
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly VERSION="1.0.0"
readonly HOSTS_FILE="/etc/hosts"
readonly KUBEPILOT_ROOT="/var/lib/kubepilot/data/kube-cluster/rootfs"

# 全局变量
DEBUG="${DEBUG:-0}"

# 日志函数
function log_info() {
    echo "[INFO] $*"
}

function log_error() {
    echo "[ERROR] $*" >&2
}

function log_warn() {
    echo "[WARN] $*" >&2
}

function log_debug() {
    if [[ "${DEBUG}" == "1" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# 显示帮助信息
function show_help() {
    cat <<EOF
用法: ${SCRIPT_NAME} [选项]

说明：
  集群清理脚本，用于清理 Kubernetes 集群的无用数据

选项：
  -d, --debug          启用调试模式
  -h, --help           显示帮助信息

示例：
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --debug

版本: ${VERSION}
EOF
}

# 解析命令行参数
function parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--debug)
                DEBUG=1
                set -x
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
                log_error "不支持位置参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 获取 VIP 地址
function get_vip() {
    if [[ ! -f "${HOSTS_FILE}" ]]; then
        log_error "文件不存在: ${HOSTS_FILE}"
        return 1
    fi

    local vip
    vip=$(grep "apiserver.cluster.local" "${HOSTS_FILE}" | awk '{print $1}')

    if [[ -z "${vip}" ]]; then
        return 0
    fi

    # 只输出 VIP 地址，不输出日志（日志会污染返回值）
    echo "${vip}"
}

# 执行 kubepilot 清理脚本
function clean_kubepilot() {
    log_info "执行 kubepilot 清理脚本..."

    if [[ ! -d "${KUBEPILOT_ROOT}" ]]; then
        log_warn "目录不存在: ${KUBEPILOT_ROOT}，跳过"
        return 0
    fi

    cd "${KUBEPILOT_ROOT}" || {
        log_error "无法进入目录: ${KUBEPILOT_ROOT}"
        return 1
    }

    if [[ -f "scripts/clean-kube.sh" ]]; then
        log_info "执行 clean-kube.sh..."
        bash scripts/clean-kube.sh || log_warn "clean-kube.sh 执行失败"
    else
        log_warn "脚本不存在: scripts/clean-kube.sh"
    fi

    if [[ -f "scripts/uninstall-containerd.sh" ]]; then
        log_info "执行 uninstall-containerd.sh..."
        bash scripts/uninstall-containerd.sh || log_warn "uninstall-containerd.sh 执行失败"
    else
        log_warn "脚本不存在: scripts/uninstall-containerd.sh"
    fi

    cd "${SCRIPT_ROOT}" || true
}

# 清理 /etc/hosts 中的记录
function clean_hosts() {
    log_info "清理 ${HOSTS_FILE} 中的记录..."

    if [[ ! -f "${HOSTS_FILE}" ]]; then
        log_warn "文件不存在: ${HOSTS_FILE}，跳过"
        return 0
    fi

    # 备份 hosts 文件
    local backup_file
    backup_file="${HOSTS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "${HOSTS_FILE}" "${backup_file}"
    log_info "已备份 hosts 文件到: ${backup_file}"

    # 删除带有 hostalias-set-by-pilotctl 注释的行
    sed -i.tmp '/hostalias-set-by-pilotctl/d' "${HOSTS_FILE}"
    rm -f "${HOSTS_FILE}.tmp"

    log_info "已清理 hosts 文件中的记录"
}

# 清理 VIP 地址
function clean_vip() {
    local vip="$1"

    if [[ -z "${vip}" ]]; then
        log_debug "VIP 地址为空，跳过清理"
        return 0
    fi

    log_info "清理 VIP 地址: ${vip}..."

    if ! command -v ip >/dev/null 2>&1; then
        log_warn "ip 命令不存在，跳过 VIP 清理"
        return 0
    fi

    ip addr flush to "${vip}" || log_warn "清理 VIP 地址失败"
    log_info "已清理 VIP 地址"
}

# 清理其他目录和文件
function clean_other() {
    log_info "清理其他目录和文件..."

    local dirs=(
        "/root/.kubepilot"
        "/root/.kube/"
        "/kube-db"
        "/kube/"
        "/var/lib/kubepilot/"
    )

    for dir in "${dirs[@]}"; do
        if [[ -e "${dir}" ]]; then
            log_info "删除: ${dir}"
            rm -rf "${dir}" || log_warn "删除失败: ${dir}"
        else
            log_debug "目录不存在，跳过: ${dir}"
        fi
    done

    log_info "已清理其他目录和文件"
}

# 主函数
function main() {
    # 解析参数
    parse_args "$@"

    log_info "开始执行集群清理..."
    log_warn "此操作将删除集群相关数据，请确认后继续"

    # 获取 VIP 地址
    log_info "从 ${HOSTS_FILE} 获取 VIP 地址..."
    local vip
    vip=$(get_vip) || true
    
    if [[ -n "${vip}" ]]; then
        log_info "找到 VIP 地址: ${vip}"
    else
        log_warn "未找到 VIP 地址，跳过 VIP 清理"
    fi

    # 执行 kubepilot 清理脚本
    clean_kubepilot || log_warn "kubepilot 清理失败"

    # 清理 hosts 文件
    clean_hosts || log_warn "hosts 文件清理失败"

    # 清理 VIP 地址
    clean_vip "${vip}" || log_warn "VIP 清理失败"

    # 清理其他目录和文件
    clean_other || log_warn "其他清理失败"

    log_info "集群清理完成"
}

# 执行主函数
main "$@"
