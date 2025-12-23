#!/usr/bin/env bash
#
# Shell 脚本远程测试工具
# 用途：将脚本拷贝到远程机器并执行测试
#

set -euo pipefail

# 默认配置
REMOTE_HOST="10.16.203.15"
REMOTE_USER="${REMOTE_USER:-root}"
REMOTE_PATH="${REMOTE_PATH:-/tmp}"
CLEANUP="${CLEANUP:-yes}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
function log_info() {
    echo -e "${BLUE}[信息]${NC} $*"
}

function log_success() {
    echo -e "${GREEN}[成功]${NC} $*"
}

function log_warn() {
    echo -e "${YELLOW}[警告]${NC} $*"
}

function log_error() {
    echo -e "${RED}[错误]${NC} $*" >&2
}

# 显示帮助信息
function show_help() {
    cat << EOF
用法: $0 <脚本路径> [选项]

参数:
    <脚本路径>          要测试的脚本文件路径（必需）

选项:
    -u, --user <用户>   远程用户名（默认: root）
    -p, --path <路径>   远程存放路径（默认: /tmp）
    -h, --host <主机>   远程主机地址（默认: 10.16.203.61）
    -n, --no-cleanup    测试后不清理远程文件
    -c, --check         测试前运行 shellcheck
    --help              显示此帮助信息

示例:
    # 基本用法
    $0 /path/to/script.sh

    # 指定远程用户和路径
    $0 /path/to/script.sh -u pengzz -p /opt/test

    # 测试前运行 shellcheck
    $0 /path/to/script.sh --check

    # 测试后保留远程文件
    $0 /path/to/script.sh --no-cleanup
EOF
}

# 解析参数
SCRIPT_PATH=""
RUN_SHELLCHECK="no"
SCRIPT_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)
            show_help
            exit 0
            ;;
        -u|--user)
            REMOTE_USER="$2"
            shift 2
            ;;
        -p|--path)
            REMOTE_PATH="$2"
            shift 2
            ;;
        -h|--host)
            REMOTE_HOST="$2"
            shift 2
            ;;
        -n|--no-cleanup)
            CLEANUP="no"
            shift
            ;;
        -c|--check)
            RUN_SHELLCHECK="yes"
            shift
            ;;
        --)
            shift
            SCRIPT_ARGS=("$@")
            break
            ;;
        -*)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "${SCRIPT_PATH}" ]]; then
                SCRIPT_PATH="$1"
            else
                SCRIPT_ARGS+=("$1")
            fi
            shift
            ;;
    esac
done

# 验证必需参数
if [[ -z "${SCRIPT_PATH}" ]]; then
    log_error "缺少脚本路径参数"
    show_help
    exit 1
fi

# 验证脚本文件
if [[ ! -f "${SCRIPT_PATH}" ]]; then
    log_error "脚本文件不存在: ${SCRIPT_PATH}"
    exit 1
fi

# 获取脚本名称
SCRIPT_NAME=$(basename "${SCRIPT_PATH}")
REMOTE_SCRIPT_PATH="${REMOTE_PATH}/${SCRIPT_NAME}"

# 显示测试信息
echo "=========================================="
log_info "开始远程测试"
echo "=========================================="
log_info "本地脚本: ${SCRIPT_PATH}"
log_info "远程主机: ${REMOTE_HOST}"
log_info "远程用户: ${REMOTE_USER}"
log_info "远程路径: ${REMOTE_SCRIPT_PATH}"
if [[ ${#SCRIPT_ARGS[@]} -gt 0 ]]; then
    log_info "脚本参数: ${SCRIPT_ARGS[*]}"
fi
echo "=========================================="
echo ""

# 可选：运行 shellcheck
if [[ "${RUN_SHELLCHECK}" == "yes" ]]; then
    log_info "运行 shellcheck 静态检查..."
    if command -v shellcheck &> /dev/null; then
        if shellcheck "${SCRIPT_PATH}"; then
            log_success "shellcheck 检查通过"
        else
            log_warn "shellcheck 发现问题，但继续测试"
        fi
    else
        log_warn "shellcheck 未安装，跳过静态检查"
    fi
    echo ""
fi

# 测试 SSH 连接
log_info "测试 SSH 连接..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "${REMOTE_USER}@${REMOTE_HOST}" "echo '连接成功'" &> /dev/null; then
    log_error "无法连接到远程主机 ${REMOTE_USER}@${REMOTE_HOST}"
    log_error "请检查："
    log_error "  1. 网络连接是否正常"
    log_error "  2. SSH 免密登录是否配置"
    log_error "  3. 远程主机地址是否正确"
    exit 1
fi
log_success "SSH 连接正常"
echo ""

# 拷贝脚本到远程机器
log_info "拷贝脚本到远程机器..."
if scp -q "${SCRIPT_PATH}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_SCRIPT_PATH}"; then
    log_success "脚本拷贝成功"
else
    log_error "脚本拷贝失败"
    exit 1
fi
echo ""

# 设置远程脚本执行权限
log_info "设置脚本执行权限..."
if ssh "${REMOTE_USER}@${REMOTE_HOST}" "chmod +x ${REMOTE_SCRIPT_PATH}"; then
    log_success "权限设置成功"
else
    log_error "权限设置失败"
    exit 1
fi
echo ""

# 执行远程脚本
log_info "执行远程脚本..."
echo "=========================================="
echo "脚本输出："
echo "=========================================="

START_TIME=$(date +%s)
EXIT_CODE=0

# 构建远程执行命令
REMOTE_CMD="bash ${REMOTE_SCRIPT_PATH}"
if [[ ${#SCRIPT_ARGS[@]} -gt 0 ]]; then
    REMOTE_CMD="${REMOTE_CMD} ${SCRIPT_ARGS[*]}"
fi

# 执行并捕获退出码
if ssh "${REMOTE_USER}@${REMOTE_HOST}" "${REMOTE_CMD}"; then
    EXIT_CODE=0
else
    EXIT_CODE=$?
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "=========================================="
echo ""

# 显示测试结果
echo "=========================================="
log_info "测试结果"
echo "=========================================="
log_info "退出码: ${EXIT_CODE}"
log_info "执行时间: ${DURATION} 秒"

if [[ ${EXIT_CODE} -eq 0 ]]; then
    log_success "脚本执行成功 ✓"
else
    log_error "脚本执行失败 ✗"
fi
echo "=========================================="
echo ""

# 清理远程文件
if [[ "${CLEANUP}" == "yes" ]]; then
    log_info "清理远程文件..."
    if ssh "${REMOTE_USER}@${REMOTE_HOST}" "rm -f ${REMOTE_SCRIPT_PATH}"; then
        log_success "远程文件已清理"
    else
        log_warn "远程文件清理失败"
    fi
else
    log_info "保留远程文件: ${REMOTE_SCRIPT_PATH}"
fi

echo ""
log_info "测试完成"

exit ${EXIT_CODE}
