# Shell 脚本开发规范

> 参考 k3s 和 Kubernetes 项目的最佳实践

## 1. 概述

本规范旨在帮助开发者编写高质量、可维护的 Shell 脚本。规范分为三个严格性级别：

- **基础级**（必须遵循）：适用于所有脚本
- **标准级**（推荐）：适用于生产环境脚本
- **企业级**（严格）：适用于大型项目

## 2. 基础规范（必须遵循）

### 2.1 Shebang 声明

**推荐做法：**
```bash
#!/usr/bin/env bash
```

**说明：**
- 使用 `#!/usr/bin/env bash` 提高可移植性（推荐）
- 明确使用 `bash` 而非 `sh`，除非需要 POSIX 兼容性
- 避免使用 `#!/bin/bash`，因为 bash 可能安装在不同位置

**示例（来自 Kubernetes）：**
```bash
#!/usr/bin/env bash
# Copyright 2014 The Kubernetes Authors.
```

### 2.2 错误处理（set 命令）

**基础级（必须）：**
```bash
set -e  # 命令失败时立即退出
```

**标准级（推荐）：**
```bash
set -o errexit   # 命令失败时立即退出
set -o nounset   # 使用未定义变量时报错
set -o pipefail  # 管道中任何命令失败都返回失败状态
```

**企业级（严格）：**
```bash
set -o errexit
set -o nounset
set -o pipefail
set -o errtrace  # 传播 ERR trap 到函数和子 shell

# 可选：调试模式
if [[ "${DEBUG:-}" = "1" ]]; then
    set -x
fi
```

**示例（来自 Kubernetes）：**
```bash
set -o errexit
set -o nounset
set -o pipefail
```

**示例（来自 k3s）：**
```bash
set -e

if [ "${DEBUG}" = 1 ]; then
    set -x
fi
```

### 2.3 环境初始化

**推荐做法：**
```bash
# 取消 CDPATH 避免路径问题
unset CDPATH

# 设置 umask 防止权限泄露
umask 0022

# 设置 locale 确保排序一致性
export LANG=C
export LC_ALL=C
```

**示例（来自 Kubernetes）：**
```bash
unset CDPATH
umask 0022
```

### 2.4 变量引用规范

**必须遵循：**
```bash
# ✅ 正确：始终使用双引号
echo "${variable}"
echo "${array[@]}"
command --arg="${value}"

# ❌ 错误：不使用引号（可能导致单词分割和路径展开）
echo $variable
echo ${array[@]}
command --arg=$value
```

**特殊情况：**
```bash
# 数组展开
for item in "${array[@]}"; do
    echo "${item}"
done

# 命令替换
result="$(command)"
```

### 2.5 项目根目录定位

**标准模式（推荐）：**
```bash
# 使用 BASH_SOURCE 而非 $0（在 source 时更可靠）
SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

# 如果脚本在子目录中，定位到项目根目录
PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
```

**示例（来自 Kubernetes）：**
```bash
KUBE_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd -P)
```

**说明：**
- 使用 `${BASH_SOURCE[0]}` 而非 `$0`
- `pwd -P` 解析符号链接获取真实路径
- 使用 `cd` 和子 shell 确保路径规范化

## 3. 代码组织

### 3.1 文件结构模板

**标准脚本结构：**
```bash
#!/usr/bin/env bash

# Copyright 声明
# License 信息

# 脚本说明
# Usage: script.sh [options] <args>
#
# 详细说明...

# 错误处理设置
set -o errexit
set -o nounset
set -o pipefail

# 环境初始化
unset CDPATH
SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

# 引用库文件（如果需要）
source "${SCRIPT_ROOT}/lib/common.sh"

# 常量定义
readonly MAX_RETRIES=3
readonly TIMEOUT=30

# 函数定义
function main() {
    # 主逻辑
    echo "执行主逻辑..."
}

# 执行主函数
main "$@"
```

### 3.2 库文件引用

**推荐模式：**
```bash
# 引用库文件
source "${SCRIPT_ROOT}/lib/common.sh"
source "${SCRIPT_ROOT}/lib/logging.sh"

# 或使用 . 命令（POSIX 兼容）
. "${SCRIPT_ROOT}/lib/common.sh"
```

**示例（来自 Kubernetes）：**
```bash
source "${KUBE_ROOT}/hack/lib/init.sh"
source "${KUBE_ROOT}/hack/lib/util.sh"
source "${KUBE_ROOT}/hack/lib/logging.sh"
```

### 3.3 函数定义

**基础级：**
```bash
# 简单函数
function check_prerequisites() {
    command -v docker >/dev/null 2>&1 || {
        echo "错误：未找到 docker 命令" >&2
        return 1
    }
}
```

**标准级（推荐）：**
```bash
# 带文档注释的函数
# 检查必需的工具是否存在
# 参数：
#   $1 - 工具名称
# 返回值：
#   0 - 工具存在
#   1 - 工具不存在
function check_tool() {
    local tool="${1}"

    if ! command -v "${tool}" >/dev/null 2>&1; then
        echo "错误：未找到 ${tool} 命令" >&2
        return 1
    fi

    return 0
}
```

**企业级（使用命名空间）：**
```bash
# 使用命名空间前缀避免函数名冲突
# 示例来自 Kubernetes
function kube::util::array_contains() {
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
```

## 4. 命名约定

### 4.1 变量命名

**常量（只读变量）：**
```bash
# 使用大写字母和下划线
readonly MAX_RETRIES=3
readonly DEFAULT_TIMEOUT=30
readonly KUBE_BUILD_IMAGE="kube-build:latest"
```

**环境变量和配置：**
```bash
# 大写字母，带默认值
VERBOSE="${VERBOSE:-0}"
DEBUG="${DEBUG:-}"
GO="${GO:-go}"

# 使用 :- 提供默认值（变量未设置或为空）
TIMEOUT="${TIMEOUT:-30}"

# 使用 - 提供默认值（仅变量未设置）
GO=${GO-go}
```

**局部变量：**
```bash
function process_data() {
    local input_file="$1"
    local -r output_file="$2"  # 只读局部变量
    local -a items=()          # 数组
    local result

    # 处理逻辑...
}
```

### 4.2 函数命名

**基础级：**
```bash
# 使用小写字母和下划线
function check_prerequisites() { ... }
function build_binary() { ... }
function cleanup_temp_files() { ... }
```

**企业级（使用命名空间）：**
```bash
# 使用命名空间前缀
function project::log::info() { ... }
function project::log::error() { ... }
function project::util::array_contains() { ... }
function project::build::compile() { ... }
```

## 5. 错误处理和日志

### 5.1 错误处理模式

**基础级：**
```bash
# 简单错误检查
if [[ ! -f "${config_file}" ]]; then
    echo "错误：配置文件不存在: ${config_file}" >&2
    exit 1
fi

# 命令执行检查
if ! docker build -t "${image}" .; then
    echo "错误：Docker 构建失败" >&2
    exit 1
fi
```

**标准级：**
```bash
# 使用 || 处理错误
command || {
    echo "错误：命令执行失败" >&2
    exit 1
}

# 参数验证
if [[ $# -lt 1 ]]; then
    echo "用法: $0 <参数>" >&2
    exit 1
fi
```

**企业级：**
```bash
# 安装错误处理器
function error_handler() {
    local line_number="$1"
    echo "错误：脚本在第 ${line_number} 行失败" >&2
    # 清理操作...
    exit 1
}

trap 'error_handler ${LINENO}' ERR
```

### 5.2 日志输出规范

**基础级：**
```bash
# 标准输出
echo "信息：开始处理..."

# 错误输出（重定向到 stderr）
echo "错误：处理失败" >&2

# 警告输出
echo "警告：配置项缺失，使用默认值" >&2
```

**标准级（推荐）：**
```bash
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

# 使用
log_info "开始构建..."
log_error "构建失败"
log_warn "使用默认配置"
```

**企业级（带时间戳和详细度控制）：**
```bash
# 示例来自 Kubernetes
function kube::log::status() {
    local V="${V:-0}"
    if [[ ${KUBE_VERBOSE:-0} < ${V} ]]; then
        return
    fi

    local timestamp
    timestamp=$(date +"[%m%d %H:%M:%S]")
    echo "+++ ${timestamp} $1"
    shift
    for message; do
        echo "    ${message}"
    done
}

function kube::log::error() {
    local timestamp
    timestamp=$(date +"[%m%d %H:%M:%S]")
    echo "!!! ${timestamp} ${1-}" >&2
    shift
    for message; do
        echo "    ${message}" >&2
    done
}

# 使用
V=2 kube::log::status "构建二进制文件" "平台: linux/amd64"
kube::log::error "构建失败" "退出码: 1"
```

## 6. 注释和文档

### 6.1 文件头注释

**推荐格式：**
```bash
#!/usr/bin/env bash

# Copyright 2024 项目名称
#
# Licensed under the Apache License, Version 2.0

# 脚本说明：构建 Docker 镜像
#
# 用法：
#   build-image.sh [选项] <镜像名称>
#
# 选项：
#   -t, --tag TAG        镜像标签（默认: latest）
#   -p, --platform PLAT  目标平台（默认: linux/amd64）
#   -h, --help           显示帮助信息
#
# 示例：
#   build-image.sh -t v1.0.0 myapp
#   build-image.sh --platform linux/arm64 myapp
```

### 6.2 函数文档

**推荐格式：**
```bash
# 等待 URL 响应
#
# 参数：
#   $1 - 要检查的 URL
#   $2 - 日志消息前缀（可选）
#   $3 - 检查间隔秒数（默认: 1）
#   $4 - 最大检查次数（默认: 30）
#
# 返回值：
#   0 - URL 响应成功
#   1 - 超时
#
# 示例：
#   wait_for_url "http://localhost:8080" "API" 2 60
function wait_for_url() {
    local url="$1"
    local prefix="${2:-}"
    local interval="${3:-1}"
    local max_attempts="${4:-30}"

    # 实现...
}
```

### 6.3 内联注释

**推荐做法：**
```bash
# 解释为什么这样做，而不是做什么
# ✅ 好的注释
# 禁用 CDPATH 防止 cd 命令行为异常
unset CDPATH

# 使用 umask 0022 确保创建的文件权限正确
umask 0022

# ❌ 不好的注释（重复代码）
# 设置变量 x 为 10
x=10
```

**shellcheck 指令：**
```bash
# 禁用特定的 shellcheck 警告（需要说明原因）
# shellcheck disable=SC2034  # 变量在其他脚本中使用
EXPORTED_VAR="value"

# shellcheck disable=SC2064  # 故意在定义时求值
trap "cleanup ${temp_dir}" EXIT
```

## 7. 常用工具函数库

### 7.1 数组操作

```bash
# 检查元素是否在数组中
# 示例来自 Kubernetes
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

# 使用示例
platforms=("linux/amd64" "linux/arm64" "darwin/amd64")
if array_contains "linux/amd64" "${platforms[@]}"; then
    echo "找到平台"
fi
```

### 7.2 平台检测

```bash
# 检测主机操作系统
function host_os() {
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

# 检测主机架构
function host_arch() {
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

# 使用示例
OS=$(host_os)
ARCH=$(host_arch)
echo "平台: ${OS}/${ARCH}"
```

### 7.3 临时目录管理

```bash
# 创建临时目录
function ensure_temp_dir() {
    if [[ -z ${TEMP_DIR:-} ]]; then
        TEMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t project.XXXXXX)
        trap cleanup_temp_dir EXIT
    fi
}

# 清理临时目录
function cleanup_temp_dir() {
    if [[ -n ${TEMP_DIR:-} ]]; then
        rm -rf "${TEMP_DIR}"
    fi
}

# 使用示例
ensure_temp_dir
echo "临时目录: ${TEMP_DIR}"
# 脚本退出时自动清理
```

### 7.4 重试机制

```bash
# 重试执行命令
# 参数：
#   $1 - 最大重试次数
#   $2+ - 要执行的命令
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

# 使用示例
retry 3 curl -f https://example.com/api
```

## 8. 高级模式

### 8.1 并行执行

```bash
# 并行执行多个任务
platforms=("linux/amd64" "linux/arm64" "darwin/amd64")

for platform in "${platforms[@]}"; do
    (
        echo "构建 ${platform}..."
        build_for_platform "${platform}"
    ) &
done

# 等待所有后台任务完成
wait

echo "所有构建完成"
```

**带错误处理的并行执行：**
```bash
# 示例来自 Kubernetes
for platform in "${platforms[@]}"; do
    (
        build_for_platform "${platform}"
    ) &> "/tmp/${platform//\//_}.log" &
done

# 等待并检查失败
local fails=0
for job in $(jobs -p); do
    wait "${job}" || ((fails++))
done

if [[ ${fails} -gt 0 ]]; then
    echo "错误：${fails} 个构建失败" >&2
    exit 1
fi
```

### 8.2 Trap 管理

```bash
# 添加多个 trap 处理器
# 示例来自 Kubernetes
function trap_add() {
    local trap_add_cmd="$1"
    shift

    for trap_add_name in "$@"; do
        local existing_cmd
        existing_cmd=$(trap -p "${trap_add_name}" | awk -F"'" '{print $2}')

        if [[ -z "${existing_cmd}" ]]; then
            trap "${trap_add_cmd}" "${trap_add_name}"
        else
            trap "${trap_add_cmd};${existing_cmd}" "${trap_add_name}"
        fi
    done
}

# 使用示例
trap_add cleanup_temp_dir EXIT
trap_add stop_services EXIT
```

### 8.3 进程替换

```bash
# 使用进程替换读取命令输出
while IFS= read -r line; do
    process_line "${line}"
done < <(find . -name "*.sh")

# 比较两个命令的输出
diff <(command1) <(command2)
```

## 9. 兼容性和可移植性

### 9.1 Bash 版本检查

```bash
# 检查 Bash 版本
function check_bash_version() {
    if ((BASH_VERSINFO[0] < 4)); then
        echo "错误：此脚本需要 Bash 4.0 或更高版本" >&2
        echo "当前版本: ${BASH_VERSION}" >&2
        exit 1
    fi
}

check_bash_version
```

### 9.2 跨平台工具检测

```bash
# 检测 GNU sed
function ensure_gnu_sed() {
    local sed_help
    sed_help="$(LANG=C sed --help 2>&1 || true)"

    if echo "${sed_help}" | grep -q "GNU\|BusyBox"; then
        SED="sed"
    elif command -v gsed &>/dev/null; then
        SED="gsed"
    else
        echo "错误：未找到 GNU sed" >&2
        return 1
    fi
}

# 使用
ensure_gnu_sed
"${SED}" -i 's/old/new/g' file.txt
```

### 9.3 工具依赖检查

```bash
# 检查必需的工具
function check_prerequisites() {
    local required_tools=("git" "docker" "jq")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "${tool}" >/dev/null 2>&1; then
            missing_tools+=("${tool}")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo "错误：缺少必需的工具: ${missing_tools[*]}" >&2
        return 1
    fi
}

check_prerequisites
```

## 10. 代码审查清单

### 基础级检查清单

- [ ] 使用 `#!/usr/bin/env bash` 作为 shebang
- [ ] 至少使用 `set -e` 启用错误处理
- [ ] 所有变量引用使用双引号 `"${var}"`
- [ ] 使用 `${BASH_SOURCE[0]}` 定位脚本位置
- [ ] 错误消息重定向到 stderr (`>&2`)
- [ ] 函数使用 `local` 声明局部变量

### 标准级检查清单

- [ ] 使用 `set -euo pipefail` 完整错误处理
- [ ] 取消 `CDPATH` 和设置 `umask`
- [ ] 提供文件头注释说明用法
- [ ] 函数有文档注释（参数、返回值）
- [ ] 使用日志函数而非直接 echo
- [ ] 常量使用 `readonly` 声明
- [ ] 提供清理函数和 trap 处理

### 企业级检查清单

- [ ] 函数使用命名空间前缀
- [ ] 实现分级日志系统（带时间戳）
- [ ] 提供详细的错误处理和堆栈跟踪
- [ ] 检查 Bash 版本和工具依赖
- [ ] 使用库文件组织代码
- [ ] 提供完整的使用文档和示例
- [ ] 通过 shellcheck 静态检查

## 11. 参考资源

### 参考项目
- **Kubernetes**: reference/kubernetes/hack/ 和 build/
- **k3s**: reference/k3s/scripts/

### 推荐工具
- **shellcheck**: Shell 脚本静态分析工具
- **shfmt**: Shell 脚本格式化工具

### 相关文档
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/)

---

**版本**: 1.0
**最后更新**: 2024
