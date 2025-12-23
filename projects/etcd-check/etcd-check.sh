#!/usr/bin/env bash

# Copyright 2024 etcd-check
#
# Licensed under the Apache License, Version 2.0

# 脚本说明：etcd 集群健康检查和异常节点识别工具
#
# 用法：
#   etcd-check.sh [选项]
#
# 选项：
#   -v, --verbose        启用详细输出
#   -d, --debug          启用调试模式
#   -h, --help           显示帮助信息
#   --etcd-port PORT     指定 etcd 健康检查端口 (默认: 2381)
#   --etcd-client-port PORT  指定 etcd 客户端端口 (默认: 2379)
#
# 示例：
#   etcd-check.sh
#   etcd-check.sh --verbose
#   etcd-check.sh --etcd-port 2381 --etcd-client-port 2379

# 错误处理设置
set -o errexit   # 命令失败时立即退出
set -o nounset   # 使用未定义变量时报错
set -o pipefail  # 管道中任何命令失败都返回失败状态

# 环境初始化
unset CDPATH
umask 0022

# 定位脚本根目录（保留以备将来使用）
# SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

# 常量定义
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly VERSION="1.0.0"

# 全局变量（带默认值）
VERBOSE="${VERBOSE:-0}"
DEBUG="${DEBUG:-0}"
ETCD_HEALTH_PORT="${ETCD_HEALTH_PORT:-2381}"
ETCD_CLIENT_PORT="${ETCD_CLIENT_PORT:-2379}"

# 结果统计变量
declare -a HEALTHY_NODES=()
declare -a UNHEALTHY_NODES=()
declare -a UNREACHABLE_NODES=()
declare -a INCONSISTENT_NODES=()

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
  etcd 集群健康检查和异常节点识别工具
  
  功能：
  1. 自动发现 Kubernetes master 节点
  2. 检查 etcd 节点健康状态
  3. 验证 etcd 数据一致性
  4. 生成详细的检查报告

选项：
  -v, --verbose            启用详细输出
  -d, --debug              启用调试模式
  -h, --help               显示帮助信息
  --etcd-port PORT         指定 etcd 健康检查端口 (默认: 2381)
  --etcd-client-port PORT  指定 etcd 客户端端口 (默认: 2379)

示例：
  ${SCRIPT_NAME}                                    # 基本检查
  ${SCRIPT_NAME} --verbose                          # 详细输出
  ${SCRIPT_NAME} --etcd-port 2381 --debug          # 自定义端口并启用调试

版本: ${VERSION}
EOF
}

# 检查必需的工具
function check_prerequisites() {
    local required_tools=("kubectl" "curl")
    local optional_tools=("etcdctl" "timeout")
    local missing_tools=()
    local missing_optional=()

    # 检查必需工具
    for tool in "${required_tools[@]}"; do
        if ! command -v "${tool}" >/dev/null 2>&1; then
            missing_tools+=("${tool}")
        fi
    done

    # 检查可选工具
    for tool in "${optional_tools[@]}"; do
        if ! command -v "${tool}" >/dev/null 2>&1; then
            missing_optional+=("${tool}")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "缺少必需的工具: ${missing_tools[*]}"
        log_error "请安装缺少的工具后重试"
        return 1
    fi

    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        log_warn "缺少可选工具: ${missing_optional[*]}"
        log_warn "某些功能可能受限"
    fi

    # 检查 kubectl 连接
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "无法连接到 Kubernetes 集群，请检查 kubeconfig 配置"
        return 1
    fi

    log_debug "前置条件检查通过"
}

# 获取 master 节点信息
function get_master_nodes() {
    log_info "正在发现 master 节点..."
    
    local nodes_output
    if ! nodes_output=$(kubectl get nodes -o wide --no-headers 2>/dev/null); then
        log_error "无法获取节点信息"
        return 1
    fi

    # 解析节点信息，查找 master 节点
    local master_nodes=()
    while IFS= read -r line; do
        if [[ -z "${line}" ]]; then
            continue
        fi
        
        # 解析节点信息：NAME STATUS ROLES AGE VERSION INTERNAL-IP EXTERNAL-IP OS-IMAGE KERNEL-VERSION CONTAINER-RUNTIME
        local node_name
        local node_roles
        local internal_ip
        node_name=$(echo "${line}" | awk '{print $1}')
        node_roles=$(echo "${line}" | awk '{print $3}')
        internal_ip=$(echo "${line}" | awk '{print $6}')
        
        # 检查是否为 master 节点
        if [[ "${node_roles}" == *"control-plane"* ]] || [[ "${node_roles}" == *"master"* ]]; then
            master_nodes+=("${node_name}:${internal_ip}")
            log_debug "发现 master 节点: ${node_name} (${internal_ip})"
        fi
    done <<< "${nodes_output}"

    if [[ ${#master_nodes[@]} -eq 0 ]]; then
        log_error "未发现任何 master 节点"
        return 1
    fi

    log_info "发现 ${#master_nodes[@]} 个 master 节点"
    printf '%s\n' "${master_nodes[@]}"
}

# 简单的 JSON 解析函数（提取 health 字段值）
function parse_health_json() {
    local json_text="$1"
    
    # 使用 sed 提取 "health" 字段的值
    # 匹配模式: "health":true 或 "health":false 或 "health":"true" 等
    local health_value
    health_value=$(echo "${json_text}" | sed -n 's/.*"health"[[:space:]]*:[[:space:]]*\([^,}]*\).*/\1/p' | tr -d '"' | tr -d ' ')
    
    echo "${health_value}"
}

# 检查单个节点的 etcd 健康状态
function check_etcd_health() {
    local node_name="$1"
    local node_ip="$2"
    local health_url="http://${node_ip}:${ETCD_HEALTH_PORT}/health"
    
    log_debug "检查节点 ${node_name} (${node_ip}) 的健康状态..."
    
    local response
    local http_code
    
    # 使用 timeout 命令限制请求时间
    if command -v timeout >/dev/null 2>&1; then
        response=$(timeout 10 curl -s -w "%{http_code}" "${health_url}" 2>/dev/null || echo "000")
    else
        response=$(curl -s -w "%{http_code}" --max-time 10 "${health_url}" 2>/dev/null || echo "000")
    fi
    
    # 提取 HTTP 状态码
    http_code="${response: -3}"
    response_body="${response%???}"
    
    log_debug "节点 ${node_name} HTTP 响应码: ${http_code}"
    
    if [[ "${http_code}" == "200" ]]; then
        # 尝试解析 JSON 响应
        local health_status
        health_status=$(parse_health_json "${response_body}")
        
        log_debug "节点 ${node_name} 健康状态响应: ${health_status}"
        
        # 检查健康状态值
        if [[ "${health_status}" == "true" ]]; then
            log_debug "节点 ${node_name} 健康状态: 正常"
            return 0
        elif [[ "${health_status}" == "false" ]]; then
            log_warn "节点 ${node_name} 健康状态: 异常 (${health_status})"
            return 1
        else
            # 如果无法解析 JSON 或没有 health 字段，根据 HTTP 状态码判断
            log_debug "节点 ${node_name} 健康状态: 正常 (HTTP 200，无法解析详细状态)"
            return 0
        fi
    else
        log_warn "节点 ${node_name} 健康检查失败: HTTP ${http_code}"
        return 1
    fi
}

# 获取节点的 etcd key 数量
function get_etcd_key_count() {
    local node_name="$1"
    local node_ip="$2"
    
    log_debug "获取节点 ${node_name} 的 key 数量..."
    
    # 检查 etcdctl 是否可用
    if ! command -v etcdctl >/dev/null 2>&1; then
        log_warn "etcdctl 不可用，跳过数据一致性检查"
        return 1
    fi
    
    # 尝试不同的证书路径
    local cert_paths=(
        "/etc/kubernetes/pki/etcd"
        "/etc/etcd/pki"
        "/var/lib/etcd/pki"
    )
    
    local etcd_endpoint="https://${node_ip}:${ETCD_CLIENT_PORT}"
    
    for cert_path in "${cert_paths[@]}"; do
        if [[ -d "${cert_path}" ]]; then
            log_debug "尝试使用证书路径: ${cert_path}"
            
            local key_count
            if key_count=$(ETCDCTL_API=3 etcdctl \
                --endpoints="${etcd_endpoint}" \
                --cacert="${cert_path}/ca.crt" \
                --cert="${cert_path}/server.crt" \
                --key="${cert_path}/server.key" \
                get "" --prefix --keys-only 2>/dev/null | wc -l); then
                
                log_debug "节点 ${node_name} key 数量: ${key_count}"
                echo "${key_count}"
                return 0
            fi
        fi
    done
    
    log_warn "无法获取节点 ${node_name} 的 key 数量（证书或连接问题）"
    return 1
}

# 执行健康检查
function perform_health_check() {
    local master_nodes=("$@")
    
    log_info "开始执行 etcd 健康检查..."
    
    for node_info in "${master_nodes[@]}"; do
        local node_name="${node_info%%:*}"
        local node_ip="${node_info##*:}"
        
        if check_etcd_health "${node_name}" "${node_ip}"; then
            HEALTHY_NODES+=("${node_info}")
            if [[ "${VERBOSE}" == "1" ]]; then
                log_info "✓ 节点 ${node_name} 健康状态正常"
            fi
        else
            # 区分不可达和不健康
            local health_url="http://${node_ip}:${ETCD_HEALTH_PORT}/health"
            local response
            if command -v timeout >/dev/null 2>&1; then
                response=$(timeout 5 curl -s -w "%{http_code}" "${health_url}" 2>/dev/null || echo "000")
            else
                response=$(curl -s -w "%{http_code}" --max-time 5 "${health_url}" 2>/dev/null || echo "000")
            fi
            
            local http_code="${response: -3}"
            
            if [[ "${http_code}" == "000" ]]; then
                UNREACHABLE_NODES+=("${node_info}")
                log_error "✗ 节点 ${node_name} 不可达"
            else
                UNHEALTHY_NODES+=("${node_info}")
                log_error "✗ 节点 ${node_name} 健康状态异常"
            fi
        fi
    done
}

# 执行数据一致性检查
function perform_consistency_check() {
    local master_nodes=("$@")
    
    log_info "开始执行数据一致性检查..."
    
    if ! command -v etcdctl >/dev/null 2>&1; then
        log_warn "etcdctl 不可用，跳过数据一致性检查"
        return 0
    fi
    
    declare -A key_counts
    local reference_count=""
    
    # 获取所有健康节点的 key 数量
    for node_info in "${HEALTHY_NODES[@]}"; do
        local node_name="${node_info%%:*}"
        local node_ip="${node_info##*:}"
        
        local count
        if count=$(get_etcd_key_count "${node_name}" "${node_ip}"); then
            key_counts["${node_info}"]="${count}"
            
            if [[ -z "${reference_count}" ]]; then
                reference_count="${count}"
            fi
            
            log_debug "节点 ${node_name} key 数量: ${count}"
        else
            log_warn "无法获取节点 ${node_name} 的 key 数量"
        fi
    done
    
    # 比较 key 数量
    if [[ -n "${reference_count}" ]]; then
        for node_info in "${!key_counts[@]}"; do
            local node_name="${node_info%%:*}"
            local count="${key_counts[${node_info}]}"
            
            if [[ "${count}" != "${reference_count}" ]]; then
                INCONSISTENT_NODES+=("${node_info}")
                log_error "✗ 节点 ${node_name} 数据不一致 (key 数量: ${count}, 期望: ${reference_count})"
            else
                if [[ "${VERBOSE}" == "1" ]]; then
                    log_info "✓ 节点 ${node_name} 数据一致 (key 数量: ${count})"
                fi
            fi
        done
    fi
}

# 生成检查报告
function generate_report() {
    echo
    log_info "==================== etcd 集群检查报告 ===================="
    echo
    
    # 健康节点
    if [[ ${#HEALTHY_NODES[@]} -gt 0 ]]; then
        echo "✓ 健康节点 (${#HEALTHY_NODES[@]} 个):"
        for node_info in "${HEALTHY_NODES[@]}"; do
            local node_name="${node_info%%:*}"
            local node_ip="${node_info##*:}"
            echo "  - ${node_name} (${node_ip})"
        done
        echo
    fi
    
    # 异常节点汇总
    local total_issues=$((${#UNHEALTHY_NODES[@]} + ${#UNREACHABLE_NODES[@]} + ${#INCONSISTENT_NODES[@]}))
    
    if [[ ${total_issues} -eq 0 ]]; then
        log_info "🎉 所有节点状态正常，未发现异常！"
    else
        log_error "⚠️  发现 ${total_issues} 个异常节点："
        echo
        
        # 不可达节点
        if [[ ${#UNREACHABLE_NODES[@]} -gt 0 ]]; then
            echo "✗ 不可达节点 (${#UNREACHABLE_NODES[@]} 个):"
            for node_info in "${UNREACHABLE_NODES[@]}"; do
                local node_name="${node_info%%:*}"
                local node_ip="${node_info##*:}"
                echo "  - ${node_name} (${node_ip}) - 网络不可达或服务未启动"
            done
            echo
        fi
        
        # 不健康节点
        if [[ ${#UNHEALTHY_NODES[@]} -gt 0 ]]; then
            echo "✗ 不健康节点 (${#UNHEALTHY_NODES[@]} 个):"
            for node_info in "${UNHEALTHY_NODES[@]}"; do
                local node_name="${node_info%%:*}"
                local node_ip="${node_info##*:}"
                echo "  - ${node_name} (${node_ip}) - etcd 服务异常"
            done
            echo
        fi
        
        # 数据不一致节点
        if [[ ${#INCONSISTENT_NODES[@]} -gt 0 ]]; then
            echo "✗ 数据不一致节点 (${#INCONSISTENT_NODES[@]} 个):"
            for node_info in "${INCONSISTENT_NODES[@]}"; do
                local node_name="${node_info%%:*}"
                local node_ip="${node_info##*:}"
                echo "  - ${node_name} (${node_ip}) - 数据同步异常"
            done
            echo
        fi
        
        # 建议措施
        echo "建议措施："
        if [[ ${#UNREACHABLE_NODES[@]} -gt 0 ]]; then
            echo "  1. 检查不可达节点的网络连接和 etcd 服务状态"
        fi
        if [[ ${#UNHEALTHY_NODES[@]} -gt 0 ]]; then
            echo "  2. 检查不健康节点的 etcd 日志和配置"
        fi
        if [[ ${#INCONSISTENT_NODES[@]} -gt 0 ]]; then
            echo "  3. 检查数据不一致节点的同步状态，考虑重新同步"
        fi
    fi
    
    echo
    log_info "=========================================================="
    
    # 返回适当的退出码
    if [[ ${total_issues} -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# 解析命令行参数
function parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -d|--debug)
                DEBUG=1
                set -x
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --etcd-port)
                if [[ -n "${2:-}" ]]; then
                    ETCD_HEALTH_PORT="$2"
                    shift 2
                else
                    log_error "--etcd-port 需要指定端口号"
                    exit 1
                fi
                ;;
            --etcd-client-port)
                if [[ -n "${2:-}" ]]; then
                    ETCD_CLIENT_PORT="$2"
                    shift 2
                else
                    log_error "--etcd-client-port 需要指定端口号"
                    exit 1
                fi
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

# 清理函数
function cleanup() {
    log_debug "执行清理操作..."
    # 清理临时文件等
}

# 主函数
function main() {
    # 解析参数
    parse_args "$@"

    # 设置清理 trap
    trap cleanup EXIT

    log_info "etcd 集群检查工具 v${VERSION}"
    log_info "配置: 健康检查端口=${ETCD_HEALTH_PORT}, 客户端端口=${ETCD_CLIENT_PORT}"
    echo

    # 检查前置条件
    if ! check_prerequisites; then
        exit 1
    fi

    # 获取 master 节点
    local master_nodes=()
    mapfile -t master_nodes < <(get_master_nodes)
    if [[ ${#master_nodes[@]} -eq 0 ]]; then
        log_error "无法获取 master 节点信息"
        exit 1
    fi

    # 执行健康检查
    perform_health_check "${master_nodes[@]}"

    # 执行数据一致性检查
    perform_consistency_check "${master_nodes[@]}"

    # 生成报告
    if ! generate_report; then
        exit 1
    fi

    log_info "检查完成"
}

# 执行主函数
main "$@"