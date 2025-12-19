# Shell 脚本开发项目 - AI 开发指南

> 本文档是为 AI 开发者设计的完整指南，用于在这个脚本子项目管理仓库中开发高质量的 Shell 脚本。

**版本**: 1.0.0  
**最后更新**: 2024-12

---

## 目录

1. [项目概述](#1-项目概述)
2. [快速开始](#2-快速开始)
3. [项目结构](#3-项目结构)
4. [开发规范速查](#4-开发规范速查)
5. [参考函数库](#5-参考函数库)
6. [常见开发模式](#6-常见开发模式)
7. [AI 开发工作流](#7-ai-开发工作流)
8. [质量检查清单](#8-质量检查清单)
9. [参考资源](#9-参考资源)

---

## 1. 项目概述

### 1.1 项目定位

这是一个 **Shell 脚本子项目管理仓库**，而非单一脚本项目。

**核心特点**：
- **管理仓库**：维护多个独立的脚本子项目
- **参考资源**：提供规范、模板、参考实现
- **子项目独立**：每个子项目自包含，不依赖共享库

**重要说明**：
- `lib/` 目录是**参考资源**，不是共享库
- 子项目应该**复制需要的函数**，而非引用 lib/ 文件
- 每个子项目应该是**独立的、可移植的**

### 1.2 核心价值

本仓库为脚本开发提供：

1. **统一规范**
   - 三级严格性标准（基础/标准/企业级）
   - 详细的代码风格指南
   - 最佳实践和常见模式

2. **实用模板**
   - 可执行脚本模板（`templates/script-template.sh`）
   - 库文件模板（`templates/lib-template.sh`）
   - 需求规范模板（3 个版本）

3. **参考实现**
   - 通用函数库示例（`reference/lib/common.sh`）
   - Kubernetes 脚本示例
   - k3s 脚本示例

4. **AI 友好**
   - 结构化的开发指南
   - 清晰的决策树
   - 可直接复制的代码片段

### 1.3 技术栈

- **Shell**: Bash 4.0+
- **静态分析**: shellcheck
- **代码格式化**: shfmt
- **参考项目**: Kubernetes, k3s

### 1.4 子项目独立性原则

**为什么子项目要独立？**

1. **可移植性**：子项目可以独立部署到任何环境
2. **无依赖**：不依赖管理仓库的目录结构
3. **易维护**：每个子项目自包含，修改不影响其他项目
4. **版本控制**：子项目可以有自己的版本和发布周期

**如何保持独立？**

- ✅ 复制需要的函数到子项目内部
- ✅ 子项目有自己的 README 和 spec 文档
- ✅ 子项目可以独立运行和测试
- ❌ 不要引用管理仓库的 lib/ 文件
- ❌ 不要依赖管理仓库的目录结构

---

## 2. 快速开始

### 2.1 创建新子项目的完整流程

#### 步骤 1：创建子项目目录

```bash
# 在 projects/ 目录下创建新子项目
mkdir -p projects/my-project
cd projects/my-project
```

#### 步骤 2：复制模板文件

```bash
# 复制脚本模板
cp ../../templates/script-template.sh my-script.sh

# 复制规范模板（根据复杂度选择）
# 简单脚本（<100行）
cp ../../templates/spec-simple.md spec.md

# 标准脚本（100-500行）
cp ../../templates/spec-standard.md spec.md

# 复杂脚本（>500行）
cp ../../templates/spec-detailed.md spec.md
```

#### 步骤 3：填写需求规范

编辑 `spec.md`，填写：
- 脚本名称和用途
- 功能描述
- 参数说明
- 依赖工具
- 测试要点

#### 步骤 4：实现脚本

编辑 `my-script.sh`：

1. **更新文件头注释**
2. **从参考库复制需要的函数**
3. **实现主要逻辑**

#### 步骤 5：测试和验证

```bash
# 运行 shellcheck 检查
shellcheck my-script.sh

# 测试脚本
bash my-script.sh --help
```

### 2.2 如何使用参考资源

#### 使用 reference/lib/common.sh

**重要**：不要直接 source 这个文件！应该复制需要的函数。

**示例：复制日志函数**

```bash
# 在你的脚本中复制这些函数：
function log_info() {
    echo "[INFO] $*"
}

function log_error() {
    echo "[ERROR] $*" >&2
}
```

---

## 3. 项目结构

### 3.1 管理仓库结构

```
scripts/                           # 项目根目录
├── README.md                      # 项目说明
├── CLAUDE.md                      # AI 开发指南（本文档）
├── Makefile                       # 自动化任务
├── templates/                     # 脚本模板
├── projects/                      # 脚本子项目目录
├── docs/                          # 管理仓库文档
└── reference/                     # 参考资源
```

### 3.2 子项目标准结构

**简单子项目**：
```
projects/my-simple-project/
├── README.md
├── spec.md
└── script.sh
```

---

## 4. 开发规范速查

### 4.1 三级标准对比

| 检查项 | 基础级 | 标准级 | 企业级 |
|--------|--------|--------|--------|
| Shebang | `#!/usr/bin/env bash` | 同左 | 同左 |
| 错误处理 | `set -e` | `set -euo pipefail` | 同左 + ERR trap |
| 变量引用 | 使用双引号 | 同左 + local | 同左 + readonly |

### 4.2 必须遵循的规则

1. 使用 `#!/usr/bin/env bash`
2. 启用错误处理 `set -e`
3. 变量引用加引号 `"${var}"`
4. 使用 `${BASH_SOURCE[0]}` 定位脚本
5. 错误消息输出到 stderr `>&2`
6. 函数使用 `local` 声明局部变量

---

## 5. 参考函数库

### 5.1 日志函数（reference/lib/common.sh）

```bash
# 信息日志
function log_info() {
    echo "[INFO] $*"
}

# 错误日志
function log_error() {
    echo "[ERROR] $*" >&2
}

# 警告日志
function log_warn() {
    echo "[WARN] $*" >&2
}

# 调试日志（需要 DEBUG=1）
function log_debug() {
    if [[ "${DEBUG}" == "1" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}
```

### 5.2 平台检测函数

```bash
# 检测操作系统
function detect_os() {
    local host_os
    case "$(uname -s)" in
        Darwin) host_os=darwin ;;
        Linux) host_os=linux ;;
        *) echo "不支持的操作系统" >&2; exit 1 ;;
    esac
    echo "${host_os}"
}

# 检测架构
function detect_arch() {
    local host_arch
    case "$(uname -m)" in
        x86_64*|i?86_64*|amd64*) host_arch=amd64 ;;
        aarch64*|arm64*) host_arch=arm64 ;;
        arm*) host_arch=arm ;;
        *) echo "不支持的架构" >&2; exit 1 ;;
    esac
    echo "${host_arch}"
}
```

### 5.3 其他实用函数

详细的函数说明请参考 `reference/lib/common.sh` 文件。

---

## 6. 常见开发模式

### 6.1 参数解析模式

```bash
function parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                POSITIONAL_ARGS+=("$1")
                shift
                ;;
        esac
    done
}
```

### 6.2 错误处理模式

```bash
# 简单错误检查
if [[ ! -f "${config_file}" ]]; then
    log_error "配置文件不存在: ${config_file}"
    exit 1
fi

# 命令执行检查
if ! docker build -t "${image}" .; then
    log_error "Docker 构建失败"
    exit 1
fi
```

---

## 7. AI 开发工作流

### 7.1 完整开发流程

1. **需求分析**
   - 阅读用户需求
   - 选择严格性级别（基础/标准/企业）
   - 确定脚本类型

2. **创建规范文档**
   - 选择 spec 模板
   - 填写功能描述、参数、依赖
   - 定义验收标准

3. **实现脚本**
   - 复制对应模板
   - 从 reference/lib/common.sh 复制需要的函数
   - 遵循开发规范
   - 添加详细注释

4. **质量检查**
   - shellcheck 静态分析
   - 手动测试核心功能
   - 对照规范文档检查完整性

5. **文档完善**
   - 更新 spec 文档
   - 添加使用示例
   - 记录已知限制

6. **交付**
   - 提交代码和文档
   - 说明测试结果
   - 提供使用指南

### 7.2 决策树

**选择严格性级别**：
- 简单工具脚本（<100行） → 基础级 + spec-simple.md
- 生产环境脚本（100-500行） → 标准级 + spec-standard.md
- 企业级项目（>500行） → 企业级 + spec-detailed.md

**选择模板**：
- 可执行脚本 → templates/script-template.sh
- 库文件 → templates/lib-template.sh

---

## 8. 质量检查清单

### 8.1 代码规范检查

- [ ] 使用 `#!/usr/bin/env bash`
- [ ] 设置了 `set -euo pipefail`
- [ ] 所有变量引用使用双引号
- [ ] 使用 `${BASH_SOURCE[0]}` 定位脚本
- [ ] 错误消息重定向到 stderr
- [ ] 函数使用 `local` 声明局部变量
- [ ] 通过 shellcheck 检查

### 8.2 功能完整性检查

- [ ] 实现了 spec 文档中的所有功能
- [ ] 参数解析正确
- [ ] 错误处理完善
- [ ] 提供了清理函数
- [ ] 日志输出清晰

### 8.3 文档完整性检查

- [ ] 文件头注释说明用法
- [ ] 函数有文档注释
- [ ] spec 文档与实际实现一致
- [ ] 提供了使用示例

---

## 9. 参考资源

### 9.1 项目内参考

- **规范文档**：`docs/SHELL_STYLE_GUIDE.md`
- **通用库**：`reference/lib/common.sh`
- **模板文件**：`templates/`
- **Kubernetes 示例**：`reference/kubernetes/`
- **k3s 示例**：`reference/k3s/`

### 9.2 外部资源

- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/)
- [shellcheck Wiki](https://github.com/koalaman/shellcheck/wiki)

### 9.3 工具链

- **shellcheck**: 静态分析工具
- **shfmt**: 代码格式化工具

---

**版本历史**：
- v1.0.0 (2024-12): 初始版本

