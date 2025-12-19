# Shell 脚本开发项目

> 一个用于管理多个 Shell 脚本子项目的管理仓库，提供规范、模板和参考实现。

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-green.svg)](https://www.gnu.org/software/bash/)

## 项目简介

这是一个 **Shell 脚本子项目管理仓库**，旨在帮助开发者快速创建高质量、可维护的 Shell 脚本。

### 核心特点

- 📋 **三级开发规范**：基础级、标准级、企业级
- 📝 **实用模板**：脚本模板、库文件模板、需求规范模板
- 📚 **参考实现**：Kubernetes 和 k3s 的脚本示例
- 🤖 **AI 友好**：完整的 AI 开发指南
- 🔧 **工具函数库**：15+ 个常用工具函数示例

### 项目定位

**重要**：这是一个管理仓库，不是单一脚本项目。

- 每个子项目应该是**独立的、自包含的**
- `lib/` 目录是**参考资源**，不是共享库
- 子项目应该**复制需要的函数**，而非引用 lib/ 文件

## 快速开始

### 1. 创建新子项目

```bash
# 创建子项目目录
mkdir -p projects/my-project
cd projects/my-project

# 复制脚本模板
cp ../../templates/script-template.sh my-script.sh

# 复制规范模板（根据复杂度选择）
cp ../../templates/spec-simple.md spec.md      # 简单脚本（<100行）
# cp ../../templates/spec-standard.md spec.md  # 标准脚本（100-500行）
# cp ../../templates/spec-detailed.md spec.md  # 复杂脚本（>500行）
```

### 2. 填写需求规范

编辑 `spec.md`，填写脚本的功能描述、参数说明、依赖工具等。

### 3. 实现脚本

编辑 `my-script.sh`：

```bash
#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# 从 reference/lib/common.sh 复制需要的函数
function log_info() {
    echo "[INFO] $*"
}

function log_error() {
    echo "[ERROR] $*" >&2
}

# 实现主要逻辑
function main() {
    log_info "开始处理..."
    # 你的逻辑
}

main "$@"
```

### 4. 测试和验证

```bash
# 运行 shellcheck 检查
shellcheck my-script.sh

# 测试脚本
bash my-script.sh --help
bash my-script.sh <测试参数>
```

## 项目结构

```
scripts/                           # 项目根目录（管理仓库）
├── README.md                      # 项目说明（本文档）
├── CLAUDE.md                      # AI 开发指南
├── Makefile                       # 自动化任务
├── .gitignore                     # Git 忽略规则
│
├── templates/                     # 脚本模板
│   ├── script-template.sh         # 可执行脚本模板
│   ├── lib-template.sh            # 库文件模板
│   ├── spec-simple.md             # 简洁版规范模板
│   ├── spec-standard.md           # 标准版规范模板
│   └── spec-detailed.md           # 详尽版规范模板
│
├── projects/                      # 脚本子项目目录
│   └── [your-projects]/           # 你的子项目
│
├── docs/                          # 管理仓库文档
│   ├── SHELL_STYLE_GUIDE.md       # 开发规范（详细版）
│   ├── guides/                    # 开发指南
│   └── examples/                  # 示例子项目
│
└── reference/                     # 参考资源
    ├── README.md                  # 参考说明
    ├── lib/                       # 参考函数库
    │   └── common.sh              # 工具函数示例
    ├── kubernetes/                # Kubernetes 脚本示例
    └── k3s/                       # k3s 脚本示例
```

## 开发规范

### 三级严格性标准

| 级别 | 适用场景 | 主要要求 |
|------|---------|---------|
| **基础级** | 个人工具、一次性脚本 | Shebang、错误处理、变量引用 |
| **标准级** | 团队共享、生产环境 | 完整错误处理、日志函数、文档注释 |
| **企业级** | 关键系统、需要审计 | 命名空间、分级日志、完整文档 |

### 必须遵循的规则

1. ✅ 使用 `#!/usr/bin/env bash`
2. ✅ 启用错误处理 `set -euo pipefail`
3. ✅ 变量引用加引号 `"${var}"`
4. ✅ 使用 `${BASH_SOURCE[0]}` 定位脚本
5. ✅ 错误消息输出到 stderr `>&2`
6. ✅ 函数使用 `local` 声明局部变量

详细规范请参考 [`docs/SHELL_STYLE_GUIDE.md`](docs/SHELL_STYLE_GUIDE.md)

## 参考资源

### 项目内资源

- **AI 开发指南**：[`CLAUDE.md`](CLAUDE.md) - 为 AI 开发者提供的完整指南
- **开发规范**：[`docs/SHELL_STYLE_GUIDE.md`](docs/SHELL_STYLE_GUIDE.md) - 详细的代码风格指南
- **参考函数库**：[`reference/lib/common.sh`](reference/lib/common.sh) - 15+ 个工具函数示例
- **脚本模板**：[`templates/`](templates/) - 可直接使用的模板文件

### 外部资源

- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/)
- [shellcheck Wiki](https://github.com/koalaman/shellcheck/wiki)

### 工具链

- **shellcheck**: Shell 脚本静态分析工具
  ```bash
  # 安装
  brew install shellcheck  # macOS
  apt-get install shellcheck  # Ubuntu
  
  # 使用
  shellcheck script.sh
  ```

- **shfmt**: Shell 脚本格式化工具
  ```bash
  # 安装
  brew install shfmt  # macOS
  go install mvdan.cc/sh/v3/cmd/shfmt@latest  # Go
  
  # 使用
  shfmt -w -i 4 script.sh
  ```

## 常见问题

### Q: 为什么不能直接 source lib/common.sh？

**A**: 因为这是一个管理仓库，子项目应该是独立的、可移植的。如果直接 source lib/common.sh，子项目就依赖了管理仓库的目录结构，无法独立部署。

**正确做法**：复制需要的函数到子项目中。

### Q: 如何选择合适的规范级别？

**A**: 
- **基础级**：个人工具、一次性脚本（<100行）
- **标准级**：团队共享、生产环境（100-500行）
- **企业级**：关键系统、需要审计（>500行）

### Q: 如何使用参考实现？

**A**: 
1. 阅读 `reference/README.md` 了解参考实现的特点
2. 选择与你的需求相似的脚本
3. 学习其设计模式和代码组织
4. 复制有用的函数和模式到你的项目

### Q: 子项目可以有自己的 lib/ 目录吗？

**A**: 可以！如果你的子项目有多个脚本需要共享函数，可以创建子项目自己的 lib/ 目录。

## 贡献指南

欢迎贡献！请遵循以下步骤：

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

### 贡献内容

- 🐛 报告 Bug
- 💡 提出新功能建议
- 📝 改进文档
- 🔧 添加新的工具函数示例
- 📚 分享你的脚本示例

## 许可证

本项目采用 Apache License 2.0 许可证。详见 [LICENSE](LICENSE) 文件。

## 联系方式

- 项目主页：[GitHub Repository](https://github.com/your-org/scripts)
- 问题反馈：[GitHub Issues](https://github.com/your-org/scripts/issues)

---

**版本**: 1.0.0  
**最后更新**: 2024-12

