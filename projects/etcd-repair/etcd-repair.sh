#!/usr/bin/env bash

# Copyright 2024 etcd-repair
#
# Licensed under the Apache License, Version 2.0

# 脚本说明：修复 k8s 的 etcd 集群异常 member
#
# 用法：
#   etcd-repair.sh <异常节点IP>
#
# 选项：
#   -h, --help           显示帮助信息
#
# 示例：
#   etcd-repair.sh 10.16.203.30

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
readonly ETCD_YAML="/etc/kubernetes/manifests/etcd.yaml"
readonly ETCD_DATA_DIR="/var/lib/etcd"
readonly BACKUP_DIR="${SCRIPT_ROOT}/backup"

# 全局变量
ABNORMAL_NODE_IP=""
ABNORMAL_NODE_NAME=""
ABNORMAL_MEMBER_ID=""
NORMAL_NODE_IP=""
ETCD_ENDPOINT=""

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

# 显示帮助信息
function show_help() {
    cat <<EOF
用法: ${SCRIPT_NAME} <异常节点IP>

说明：
  修复 k8s 的 etcd 集群异常 member

  核心流程：
  1. 备份 etcd.yaml 和数据
  2. 停止 kubelet 和 etcd 容器
  3. 移除异常 member 并重新加入集群
  4. 重启服务并验证

参数：
  <异常节点IP>         需要修复的异常节点 IP 地址

选项：
  -h, --help           显示帮助信息

示例：
  ${SCRIPT_NAME} 10.16.203.30

版本: ${VERSION}
EOF
}

# 检查必需的工具
function check_prerequisites() {
    local required_tools=("etcdctl" "crictl" "systemctl" "kubectl" "grep" "awk" "sed")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "${tool}" >/dev/null 2>&1; then
            missing_tools+=("${tool}")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "缺少必需的工具: ${missing_tools[*]}"
        return 1
    fi
}

# 设置 etcdctl 环境变量
function setup_etcdctl_env() {
    log_info "设置 etcdctl 环境变量..."

    # 从 etcd pod 中提取证书路径
    export ETCDCTL_API=3
    export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
    export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
    export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key

    log_info "etcdctl 环境变量已设置"
}

# 选择正常节点
function select_normal_node() {
    log_info "选择正常节点..."

    # 通过 kubectl get node 获取所有 master 节点 IP
    local all_ips
    all_ips=$(kubectl get nodes -l node-role.kubernetes.io/master -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)

    if [[ -z "${all_ips}" ]]; then
        # 尝试使用 control-plane 标签
        all_ips=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
    fi

    if [[ -z "${all_ips}" ]]; then
        log_error "无法获取 master 节点列表"
        return 1
    fi

    # 过滤掉异常节点
    local normal_nodes=()
    for ip in ${all_ips}; do
        if [[ "${ip}" != "${ABNORMAL_NODE_IP}" ]]; then
            normal_nodes+=("${ip}")
        fi
    done

    if [[ ${#normal_nodes[@]} -eq 0 ]]; then
        log_error "没有可用的正常节点"
        return 1
    fi

    # 选择第一个正常节点
    NORMAL_NODE_IP="${normal_nodes[0]}"
    ETCD_ENDPOINT="https://${NORMAL_NODE_IP}:2379"

    log_info "选择正常节点: ${NORMAL_NODE_IP}"

    # 验证节点可用性
    if ! verify_node_available; then
        log_error "正常节点不可用: ${NORMAL_NODE_IP}"
        return 1
    fi

    return 0
}

# 验证节点可用性
function verify_node_available() {
    log_info "验证节点可用性: ${NORMAL_NODE_IP}"

    # 尝试连接 etcd
    if ! etcdctl --endpoints="${ETCD_ENDPOINT}" endpoint health >/dev/null 2>&1; then
        log_error "无法连接到 etcd: ${ETCD_ENDPOINT}"
        return 1
    fi

    log_info "节点可用: ${NORMAL_NODE_IP}"
    return 0
}

# 获取 initial-cluster 信息
function get_initial_cluster_info() {
    log_info "获取 initial-cluster 信息..." >&2

    # 从 etcd member list 获取所有成员信息
    local member_list
    member_list=$(etcdctl --endpoints="${ETCD_ENDPOINT}" member list)

    if [[ -z "${member_list}" ]]; then
        log_error "无法获取 member 列表"
        return 1
    fi

    # 使用 awk 解析 member 信息，构建 initial-cluster 字符串
    # member list 输出格式：ID, started, name, peer-urls, client-urls, is-learner
    local initial_cluster
    initial_cluster=$(echo "${member_list}" | awk -F', ' '{
        gsub(/^[ \t]+|[ \t]+$/, "", $3);
        gsub(/^[ \t]+|[ \t]+$/, "", $4);
        print $3"="$4
    }' | paste -sd ',' -)

    if [[ -z "${initial_cluster}" ]]; then
        log_error "无法构建 initial-cluster 信息"
        return 1
    fi

    log_info "initial-cluster: ${initial_cluster}" >&2
    echo "${initial_cluster}"
}

# 获取 etcd 集群信息
function get_cluster_info() {
    log_info "获取 etcd 集群信息..."

    # 使用正常节点的 endpoint
    if ! etcdctl --endpoints="${ETCD_ENDPOINT}" member list; then
        log_error "无法获取 etcd member 列表"
        return 1
    fi
}

# 获取异常节点的 member ID 和名称
function get_abnormal_member_info() {
    log_info "获取异常节点信息: ${ABNORMAL_NODE_IP}"

    # 使用正常节点的 endpoint
    local member_info
    member_info=$(etcdctl --endpoints="${ETCD_ENDPOINT}" member list | grep "${ABNORMAL_NODE_IP}" || true)

    if [[ -z "${member_info}" ]]; then
        log_error "未找到 IP 为 ${ABNORMAL_NODE_IP} 的 member"
        return 1
    fi

    # 解析 member ID 和名称
    ABNORMAL_MEMBER_ID=$(echo "${member_info}" | awk -F', ' '{print $1}')
    ABNORMAL_NODE_NAME=$(echo "${member_info}" | awk -F', ' '{print $3}')

    log_info "异常节点信息: ID=${ABNORMAL_MEMBER_ID}, Name=${ABNORMAL_NODE_NAME}"
}

# 备份 etcd 配置和数据
function backup_etcd() {
    log_info "开始备份 etcd 配置和数据..."

    local timestamp
    timestamp=$(date +%F-%H-%M-%S)
    local backup_path="${BACKUP_DIR}/${timestamp}"

    # 创建备份目录
    mkdir -p "${backup_path}"

    # 备份 etcd.yaml
    if [[ -f "${ETCD_YAML}" ]]; then
        log_info "备份 ${ETCD_YAML} 到 ${backup_path}/"
        cp "${ETCD_YAML}" "${backup_path}/etcd.yaml.bak"
    else
        log_warn "etcd.yaml 文件不存在: ${ETCD_YAML}"
    fi

    # 使用正常节点的 endpoint 备份 etcd 数据
    log_info "备份 etcd 数据到 ${backup_path}/snapshot.db (使用节点: ${NORMAL_NODE_IP})"
    if ! etcdctl --endpoints="${ETCD_ENDPOINT}" snapshot save "${backup_path}/snapshot.db"; then
        log_error "etcd 数据备份失败"
        return 1
    fi

    log_info "备份完成: ${backup_path}"
}

# 停止 etcd 服务
function stop_etcd_service() {
    log_info "停止 etcd 服务..."

    # 停止 kubelet
    log_info "停止 kubelet..."
    systemctl stop kubelet

    # 等待一会儿
    sleep 3

    # 获取 etcd 容器 ID
    log_info "查找 etcd 容器..."
    local etcd_container_id
    etcd_container_id=$(crictl ps -a | grep etcd | grep -v pause | awk '{print $1}' || true)

    if [[ -n "${etcd_container_id}" ]]; then
        log_info "停止 etcd 容器: ${etcd_container_id}"
        crictl stop "${etcd_container_id}" || true
    else
        log_warn "未找到 etcd 容器"
    fi

    log_info "etcd 服务已停止"
}

# 清理 etcd 数据目录
function cleanup_etcd_data() {
    log_info "清理 etcd 数据目录..."

    local timestamp
    timestamp=$(date +%F-%H-%M)

    if [[ -d "${ETCD_DATA_DIR}/member" ]]; then
        log_info "备份并删除 ${ETCD_DATA_DIR}/member"
        mv "${ETCD_DATA_DIR}/member" "${ETCD_DATA_DIR}/bak_member_${timestamp}"
    else
        log_warn "member 目录不存在: ${ETCD_DATA_DIR}/member"
    fi

    log_info "etcd 数据目录已清理"
}

# 修改 etcd.yaml 配置
function update_etcd_yaml() {
    log_info "修改 etcd.yaml 配置..."

    if [[ ! -f "${ETCD_YAML}" ]]; then
        log_error "etcd.yaml 文件不存在: ${ETCD_YAML}"
        return 1
    fi

    # 获取 initial-cluster 信息
    local initial_cluster
    initial_cluster=$(get_initial_cluster_info)

    if [[ -z "${initial_cluster}" ]]; then
        log_error "无法获取 initial-cluster 信息"
        return 1
    fi

    # 更新或添加 initial-cluster
    if grep -q "initial-cluster=" "${ETCD_YAML}"; then
        log_info "更新 initial-cluster 配置"
        sed -i "s|--initial-cluster=.*|--initial-cluster=${initial_cluster}|" "${ETCD_YAML}"
    else
        log_info "添加 initial-cluster 配置"
        # 在 initial-advertise-peer-urls 行后添加
        sed -i "/--initial-advertise-peer-urls=/a\    - --initial-cluster=${initial_cluster}" "${ETCD_YAML}"
    fi

    # 更新或添加 initial-cluster-state
    if grep -q "initial-cluster-state" "${ETCD_YAML}"; then
        log_info "更新 initial-cluster-state 为 existing"
        sed -i 's/--initial-cluster-state=.*/--initial-cluster-state=existing/' "${ETCD_YAML}"
    else
        log_info "添加 initial-cluster-state=existing 配置"
        sed -i '/--initial-cluster=/a\    - --initial-cluster-state=existing' "${ETCD_YAML}"
    fi

    log_info "etcd.yaml 配置已更新"
}

# 移除异常 member
function remove_abnormal_member() {
    log_info "移除异常 member: ${ABNORMAL_MEMBER_ID}"

    # 使用正常节点的 endpoint
    if ! etcdctl --endpoints="${ETCD_ENDPOINT}" member remove "${ABNORMAL_MEMBER_ID}"; then
        log_error "移除 member 失败"
        return 1
    fi

    log_info "member 已移除"
}

# 添加新 member
function add_new_member() {
    log_info "添加新 member: ${ABNORMAL_NODE_NAME}"

    local peer_url="https://${ABNORMAL_NODE_IP}:2380"

    # 使用正常节点的 endpoint
    if ! etcdctl --endpoints="${ETCD_ENDPOINT}" member add "${ABNORMAL_NODE_NAME}" --peer-urls="${peer_url}"; then
        log_error "添加 member 失败"
        return 1
    fi

    log_info "member 已添加"
}

# 重启 etcd 服务
function restart_etcd_service() {
    log_info "重启 etcd 服务..."

    log_info "启动 kubelet..."
    systemctl restart kubelet

    # 等待 etcd 启动
    log_info "等待 etcd 启动..."
    sleep 10

    log_info "etcd 服务已重启"
}

# 验证集群状态
function verify_cluster_status() {
    log_info "验证集群状态..."

    # 等待一会儿让集群稳定
    sleep 5

    log_info "检查 endpoint status..."
    if ! etcdctl --endpoints="${ETCD_ENDPOINT}" endpoint status -w table --cluster; then
        log_warn "endpoint status 检查失败"
    fi

    log_info "检查 endpoint health..."
    if ! etcdctl --endpoints="${ETCD_ENDPOINT}" endpoint health --cluster; then
        log_warn "endpoint health 检查失败"
    fi

    log_info "集群状态验证完成"
}

# 解析命令行参数
function parse_args() {
    if [[ $# -eq 0 ]]; then
        log_error "缺少必需的参数: 异常节点IP"
        show_help
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
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
                if [[ -z "${ABNORMAL_NODE_IP}" ]]; then
                    ABNORMAL_NODE_IP="$1"
                else
                    log_error "只能指定一个异常节点IP"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # 验证 IP 格式
    if [[ ! "${ABNORMAL_NODE_IP}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "无效的 IP 地址: ${ABNORMAL_NODE_IP}"
        exit 1
    fi
}

# 主函数
function main() {
    log_info "=========================================="
    log_info "etcd-repair 脚本开始执行"
    log_info "版本: ${VERSION}"
    log_info "=========================================="

    # 解析参数
    parse_args "$@"

    log_info "异常节点 IP: ${ABNORMAL_NODE_IP}"

    # 检查前置条件
    check_prerequisites

    # 设置 etcdctl 环境
    setup_etcdctl_env

    # 选择正常节点
    select_normal_node

    # 获取集群信息
    get_cluster_info

    # 获取异常节点信息
    get_abnormal_member_info

    # 确认操作
    log_warn "即将修复异常节点: ${ABNORMAL_NODE_NAME} (${ABNORMAL_NODE_IP})"
    log_warn "使用正常节点: ${NORMAL_NODE_IP}"
    log_warn "此操作将停止 kubelet 和 etcd 服务，并清理数据目录"
    read -p "确认继续? (yes/no): " -r
    if [[ ! "${REPLY}" =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "操作已取消"
        exit 0
    fi

    # 执行修复流程
    backup_etcd
    stop_etcd_service
    cleanup_etcd_data
    update_etcd_yaml
    remove_abnormal_member
    add_new_member
    restart_etcd_service
    verify_cluster_status

    log_info "=========================================="
    log_info "etcd-repair 脚本执行完成"
    log_info "异常节点 ${ABNORMAL_NODE_NAME} (${ABNORMAL_NODE_IP}) 修复完成"
    log_info "=========================================="
}

# 执行主函数
main "$@"
