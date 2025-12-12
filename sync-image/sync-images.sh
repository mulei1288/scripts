#!/bin/bash

# Docker镜像同步脚本
# 功能：从Harbor仓库同步镜像到本地Registry
# 作者：Shell Scripts Collection
# 版本：v1.0.0

set -euo pipefail

# 配置参数
SOURCE_REGISTRY="dev.bingosoft.net"
TARGET_REGISTRY="registry.kube.io:5000"
IMAGES_FILE="imgs.txt"
LOG_FILE="sync-images.log"
MAX_RETRIES=10
RETRY_DELAY=5
SKIP_EXIST_CHECK=true

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 统计变量
TOTAL_IMAGES=0
SUCCESS_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0

# 日志函数
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() {
    log "INFO" "${BLUE}$*${NC}"
}

log_success() {
    log "SUCCESS" "${GREEN}$*${NC}"
}

log_warning() {
    log "WARNING" "${YELLOW}$*${NC}"
}

log_error() {
    log "ERROR" "${RED}$*${NC}"
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖工具..."
    
    if ! command -v skopeo &> /dev/null; then
        log_error "skopeo 未安装，请先安装 skopeo"
        echo "安装方法："
        echo "  Ubuntu/Debian: sudo apt-get install skopeo"
        echo "  CentOS/RHEL: sudo yum install skopeo"
        echo "  macOS: brew install skopeo"
        exit 1
    fi
    
    log_success "依赖检查完成"
}

# 检查镜像清单文件
check_images_file() {
    if [[ ! -f "${IMAGES_FILE}" ]]; then
        log_error "镜像清单文件 ${IMAGES_FILE} 不存在"
        exit 1
    fi
    
    # 统计有效镜像数量
    TOTAL_IMAGES=$(grep -v '^#' "${IMAGES_FILE}" | grep -v '^$' | wc -l)
    log_info "发现 ${TOTAL_IMAGES} 个镜像需要同步"
}

# 解析镜像名称和标签
parse_image() {
    local full_image=$1
    local image_without_registry=${full_image#${SOURCE_REGISTRY}/}
    echo "${image_without_registry}"
}

# 检查目标镜像是否已存在
check_image_exists() {
    local target_image=$1

    # 尝试检查镜像是否存在，如果检查失败则假设镜像不存在
    if timeout 10 skopeo inspect --insecure-policy --tls-verify=false --raw "docker://${TARGET_REGISTRY}/${target_image}" &>/dev/null; then
        return 0  # 镜像存在
    else
        return 1  # 镜像不存在或检查失败
    fi
}

# 同步单个镜像
sync_image() {
    local source_image=$1
    local target_image_path=$(parse_image "${source_image}")
    local target_image="${TARGET_REGISTRY}/${target_image_path}"
    
    log_info "开始同步镜像: ${source_image}"
    
    # 检查镜像是否已存在（如果检查失败则继续同步）
    if [[ "${SKIP_EXIST_CHECK}" != "true" ]]; then
        if check_image_exists "${target_image_path}"; then
            log_warning "镜像已存在，跳过: ${target_image}"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            return 0
        fi
    fi
    
    local retry_count=0
    while [[ ${retry_count} -lt ${MAX_RETRIES} ]]; do
        if skopeo copy \
            --insecure-policy \
            --src-tls-verify=false \
            --dest-tls-verify=false \
            --all \
            "docker://${source_image}" \
            "docker://${target_image}" 2>>"${LOG_FILE}"; then
            
            log_success "同步成功: ${source_image} -> ${target_image}"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            return 0
        else
            retry_count=$((retry_count + 1))
            if [[ ${retry_count} -lt ${MAX_RETRIES} ]]; then
                log_warning "同步失败，${RETRY_DELAY}秒后重试 (${retry_count}/${MAX_RETRIES}): ${source_image}"
                sleep ${RETRY_DELAY}
            else
                log_error "同步失败，已达最大重试次数: ${source_image}"
                FAILED_COUNT=$((FAILED_COUNT + 1))
                return 1
            fi
        fi
    done
}

# 显示进度
show_progress() {
    local current=$1
    local total=$2

    # 防止除零错误
    if [[ ${total} -eq 0 ]]; then
        echo "进度: [--------------------------------------------------] 0% (0/0)"
        return
    fi

    local percentage=$((current * 100 / total))
    local bar_length=50
    local filled_length=$((percentage * bar_length / 100))

    # 构建进度条字符串
    local progress_bar=""
    local i=0

    # 添加已完成部分
    while [[ $i -lt ${filled_length} ]]; do
        progress_bar+="="
        i=$((i + 1))
    done

    # 添加未完成部分
    while [[ $i -lt ${bar_length} ]]; do
        progress_bar+="-"
        i=$((i + 1))
    done

    # 输出进度信息（使用echo避免printf问题）
    echo -ne "\r进度: [${progress_bar}] ${percentage}% (${current}/${total})"
}

# 主同步函数
sync_images() {
    log_info "开始同步镜像..."
    
    local current_count=0
    
    while IFS= read -r line; do
        # 跳过注释行和空行
        # 去除行首尾空白字符
        line=$(echo "${line}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # 跳过空行或以#开头的注释行
        if [[ -z "${line}" ]] || [[ "${line:0:1}" == "#" ]]; then
            continue
        fi

        # 使用更兼容的算术语法
        current_count=$((current_count + 1))
        show_progress "${current_count}" "${TOTAL_IMAGES}"

        sync_image "${line}"

    done < "${IMAGES_FILE}"
    
    echo  # 换行
    log_info "镜像同步完成"
}

# 显示统计信息
show_statistics() {
    echo
    log_info "========== 同步统计 =========="
    log_info "总镜像数: ${TOTAL_IMAGES}"
    log_success "成功同步: ${SUCCESS_COUNT}"
    log_warning "跳过镜像: ${SKIPPED_COUNT}"
    log_error "失败镜像: ${FAILED_COUNT}"
    log_info "日志文件: ${LOG_FILE}"
    echo
    
    if [[ ${FAILED_COUNT} -gt 0 ]]; then
        log_warning "存在失败的镜像，请检查日志文件获取详细信息"
        return 1
    else
        log_success "所有镜像同步完成！"
        return 0
    fi
}

# 清理函数
cleanup() {
    log_info "清理临时文件..."
}

# 信号处理
trap cleanup EXIT
trap 'log_error "脚本被中断"; exit 130' INT TERM

# 显示帮助信息
show_help() {
    cat << EOF
Docker镜像同步脚本

用法: $0 [选项]

选项:
    -f, --file FILE     指定镜像清单文件 (默认: imgs.txt)
    -s, --source REG    指定源仓库地址 (默认: dev.bingosoft.net)
    -t, --target REG    指定目标仓库地址 (默认: 127.0.0.1:5000)
    -r, --retries NUM   指定重试次数 (默认: 3)
    -d, --delay SEC     指定重试延迟秒数 (默认: 5)
    --check-exist       启用镜像存在性检查，跳过已存在的镜像（默认强制同步）
    -h, --help          显示此帮助信息

示例:
    $0                                    # 使用默认配置（强制同步所有镜像）
    $0 -f custom-imgs.txt                 # 指定镜像清单文件
    $0 -s harbor.example.com -t localhost:5000  # 指定源和目标仓库
    $0 --check-exist                      # 启用存在性检查，跳过已存在镜像

镜像清单文件格式:
    - 每行一个完整的镜像地址
    - 以 # 开头的行为注释
    - 空行将被忽略
    - 支持多架构镜像同步（自动同步所有架构）

EOF
}

# 参数解析
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--file)
                IMAGES_FILE="$2"
                shift 2
                ;;
            -s|--source)
                SOURCE_REGISTRY="$2"
                shift 2
                ;;
            -t|--target)
                TARGET_REGISTRY="$2"
                shift 2
                ;;
            -r|--retries)
                MAX_RETRIES="$2"
                shift 2
                ;;
            -d|--delay)
                RETRY_DELAY="$2"
                shift 2
                ;;
            --check-exist)
                SKIP_EXIST_CHECK=false
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 主函数
main() {
    echo "=========================================="
    echo "    Docker镜像同步脚本 v1.0.0"
    echo "=========================================="
    echo
    
    parse_arguments "$@"
    
    log_info "配置信息:"
    log_info "  源仓库: ${SOURCE_REGISTRY}"
    log_info "  目标仓库: ${TARGET_REGISTRY}"
    log_info "  镜像清单: ${IMAGES_FILE}"
    log_info "  最大重试: ${MAX_RETRIES}"
    log_info "  重试延迟: ${RETRY_DELAY}秒"
    log_info "  日志文件: ${LOG_FILE}"
    echo
    
    check_dependencies
    check_images_file
    sync_images
    show_statistics
}

# 执行主函数
main "$@"
