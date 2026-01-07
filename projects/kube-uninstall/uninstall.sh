#!/usr/bin/env bash
set -e

# 基于脚本路径解析清理脚本位置，避免依赖当前工作目录
SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# 指定需要执行的清理脚本列表
CLEANUP_SCRIPTS=(
    "kube-clean.sh"
    "cleanup-mounts.sh"
)

# 显示帮助信息
function show_help() {
    cat <<EOF
用法: $(basename "$0") [选项] [IP地址...]

说明:
  清理 Kubernetes 集群节点，支持清理所有节点或指定节点

选项:
  -h, --help           显示帮助信息

参数:
  IP地址               要清理的节点 IP 地址（可指定多个，空格分隔）
                       如果不指定，则清理所有集群节点

示例:
  $(basename "$0")                    # 清理所有集群节点
  $(basename "$0") 10.16.203.61       # 清理指定单个节点
  $(basename "$0") 10.16.203.61 10.16.203.62  # 清理多个指定节点

EOF
}

# 解析命令行参数
SPECIFIED_IPS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "错误: 未知选项 $1" >&2
            show_help
            exit 1
            ;;
        *)
            # 验证 IP 格式
            if [[ "$1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                SPECIFIED_IPS+=("$1")
            else
                echo "错误: 无效的 IP 地址格式: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# 获取节点 IP 列表
if [ ${#SPECIFIED_IPS[@]} -gt 0 ]; then
    # 使用指定的 IP 列表
    echo "使用指定的节点 IP 列表"
    NODE_IPS="${SPECIFIED_IPS[*]}"
else
    # 获取所有节点 IP
    echo "正在获取集群节点列表..."
    NODE_IPS=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")
fi


# ========== 清理节点 ==========
echo "=========================================="
echo "开始清理所有节点..."
echo "=========================================="

if [ -z "$NODE_IPS" ]; then
    echo "⚠️  警告: 无法获取节点列表，可能集群已不可用"
    echo "⚠️  将仅清理本地节点"
    NODE_IPS=$(hostname -I | awk '{print $1}')
fi

echo "找到以下节点:"
for ip in $NODE_IPS; do
    echo "  - $ip"
done
echo ""

# 对每个节点执行所有清理脚本
for node_ip in $NODE_IPS; do
    echo "----------------------------------------"
    echo "清理节点: $node_ip"
    echo "----------------------------------------"

    # 检查是否为本地节点
    CURRENT_IP=$(hostname -I | awk '{print $1}')

    for script_name in "${CLEANUP_SCRIPTS[@]}"; do
        cleanup_script="${SCRIPT_DIR}/${script_name}"
        echo "执行清理脚本: $script_name"

        # 检查脚本是否存在
        if [ ! -f "$cleanup_script" ]; then
            echo "⚠️  警告: 脚本 $script_name 不存在，跳过"
            continue
        fi

        if [ "$node_ip" == "$CURRENT_IP" ]; then
            # 本地执行
            chmod +x "$cleanup_script"
            if ! "$cleanup_script"; then
                echo "⚠️  警告: 脚本 $script_name 执行失败，但继续清理流程"
            fi
        else
            # 远程执行：先复制脚本，再执行
            remote_script="/tmp/$script_name"
            if scp -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$cleanup_script" "root@$node_ip:$remote_script" 2>/dev/null; then
                if ! ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "root@$node_ip" "chmod +x $remote_script && $remote_script" 2>/dev/null; then
                    echo "⚠️  警告: 节点 $node_ip 上的脚本 $script_name 执行失败，但继续清理流程"
                fi
                # 清理远程脚本
                ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "root@$node_ip" "rm -f $remote_script" 2>/dev/null || true
            else
                echo "⚠️  警告: 无法连接到节点 $node_ip，跳过该节点"
                break
            fi
        fi
    done
    echo ""
done

echo "=========================================="
echo "节点清理完成"
echo "=========================================="
