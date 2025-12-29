#!/usr/bin/env bash

# Copyright 2024 scripts
#
# Licensed under the Apache License, Version 2.0

# 脚本说明：打包安装包的脚本
#
# 用法：
#   package.sh --type <kube|docker>
#
# 选项：
#   --type <kube|docker>  指定打包类型（必需）
#   -h, --help            显示帮助信息
#
# 示例：
#   package.sh --type kube
#   package.sh --type docker

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
OUTPUT_DIR="/opt/installer-package/output"
readonly SCRIPT_NAME
readonly VERSION="1.0.0"

# 全局变量
TYPE=""

# 日志函数
function log_info() {
    echo "[INFO] $*"
}

function log_error() {
    echo "[ERROR] $*" >&2
}

# 显示帮助信息
function show_help() {
    cat <<EOF
用法: ${SCRIPT_NAME} --type <kube|docker>

说明：
  打包安装包的脚本，支持 kube 和 docker 两种类型

选项：
  --type <kube|docker>  指定打包类型（必需）
  -h, --help            显示帮助信息

示例：
  ${SCRIPT_NAME} --type kube
  ${SCRIPT_NAME} --type docker

版本: ${VERSION}
EOF
}

# 打包 kube 安装包
function package_kube() {
    log_info "开始打包 kube 安装包..."

    local package_dir="${SCRIPT_ROOT}/deliver-manifest"

    if [[ ! -d "${package_dir}" ]]; then
        log_error "目录不存在: ${package_dir}"
        exit 1
    fi

    cd "${package_dir}"
    log_info "执行 make 命令..."
    make PRODUCT=kube VERSION=v1.6.0-gkd MULTIARCH=system
    \mv ${package_dir}/_output/kube-installer.tar.gz ${OUTPUT_DIR}/kube-installer/
    log_info "kube 安装包打包完成"
}

# 打包 docker 安装包
function package_docker() {
    log_info "开始打包 docker 安装包..."

    local package_dir="${SCRIPT_ROOT}/docker-deliver-manifest"
    local docker_dir="${package_dir}/docker"

    if [[ ! -d "${docker_dir}" ]]; then
        log_error "目录不存在: ${docker_dir}"
        exit 1
    fi

    cd "${docker_dir}"
    log_info "执行 export-images.sh..."
    ./export-images.sh

    cd "${package_dir}"
    log_info "打包 docker 目录..."
    tar -zcvf docker-installer.tar.gz docker
    \mv docker-installer.tar.gz ${OUTPUT_DIR}/docker-installer/
    log_info "docker 安装包打包完成"
}

# 解析命令行参数
function parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)
                TYPE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 主函数
function main() {
    # 解析参数
    parse_args "$@"

    # 检查必需参数
    if [[ -z "${TYPE}" ]]; then
        log_error "缺少必需参数: --type"
        show_help
        exit 1
    fi

    # 根据类型执行打包
    case "${TYPE}" in
        kube)
            package_kube
            ;;
        docker)
            package_docker
            ;;
        *)
            log_error "不支持的打包类型: ${TYPE}"
            log_error "支持的类型: kube, docker"
            exit 1
            ;;
    esac

    log_info "打包任务完成"
}

# 执行主函数
main "$@"
