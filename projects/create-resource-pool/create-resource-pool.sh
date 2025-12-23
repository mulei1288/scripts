#!/usr/bin/env bash
#
# 脚本名称: create-resource-pool.sh
# 功能描述: 将所有 worker 节点加入到一个 worker 资源池
# 版本: v1.0.0
# 使用方法: ./create-resource-pool.sh
#

set -e

# 日志函数
function log_info() {
    echo "[INFO] $*"
}

function log_error() {
    echo "[ERROR] $*" >&2
}

# 主函数
function main() {
    log_info "开始创建 worker 资源池"

    # 获取机器架构并转换为支持的格式
    local arch
    local raw_arch
    raw_arch=$(uname -m)

    case "${raw_arch}" in
        x86_64|amd64)
            arch="amd64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        *)
            log_error "不支持的架构: ${raw_arch}"
            exit 1
            ;;
    esac

    log_info "检测到机器架构: ${raw_arch} -> ${arch}"

    # 获取所有 worker 节点（带重试）
    log_info "获取所有 worker 节点..."
    local worker_nodes
    local attempt=1
    local max_attempts=3

    while [[ ${attempt} -le ${max_attempts} ]]; do
        log_info "尝试获取节点列表 (${attempt}/${max_attempts})..."
        if worker_nodes=$(kubectl get nodes --selector='!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].metadata.name}' 2>&1); then
            break
        fi
        log_error "获取失败，等待 2 秒后重试..."
        sleep 2
        ((attempt++))
    done

    if [[ ${attempt} -gt ${max_attempts} ]]; then
        log_error "获取 worker 节点失败，已达到最大重试次数"
        exit 1
    fi

    if [[ -z "${worker_nodes}" ]]; then
        log_error "未找到 worker 节点"
        exit 1
    fi

    log_info "找到 worker 节点: ${worker_nodes}"

    # 生成资源池配置文件
    local config_file="work-resource-pool.yaml"
    log_info "生成资源池配置文件: ${config_file}"

    cat > "${config_file}" <<EOF
apiVersion: bingokube.bingosoft.net/v1
kind: ResourcePool
metadata:
  labels:
    bingokube.bingosoft.net/pool: work-pool
    bingokube.bingosoft.net/tenant: ""
  name: work-pool
spec:
  description: The worker in the cluster. Cannot be deleted.
  isShare: true
  nodes:
EOF

    # 添加节点信息
    for node in ${worker_nodes}; do
        cat >> "${config_file}" <<EOF
  - arch: ${arch}
    name: ${node}
EOF
    done

    # 添加其他配置
    cat >> "${config_file}" <<EOF
  poolName: worker资源池
  priority: 5
EOF

    log_info "配置文件生成完成"

    # 应用配置（带重试）
    log_info "应用资源池配置..."
    attempt=1

    while [[ ${attempt} -le ${max_attempts} ]]; do
        log_info "尝试应用配置 (${attempt}/${max_attempts})..."
        if kubectl apply -f "${config_file}"; then
            log_info "worker 资源池创建成功"
            return 0
        fi
        log_error "应用失败，等待 2 秒后重试..."
        sleep 2
        ((attempt++))
    done

    log_error "应用资源池配置失败，已达到最大重试次数"
    exit 1
}

# 执行主函数
main "$@"
