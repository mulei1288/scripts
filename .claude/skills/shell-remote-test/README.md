# Shell Remote Test Skill

## 功能说明

这个 skill 用于将 Shell 脚本自动拷贝到远程测试机器（10.16.203.61）并执行测试。

## 使用方法

### 在 Claude Code 中使用

#### 方式 1：直接调用 skill
```
/shell-remote-test /path/to/your/script.sh
```

#### 方式 2：自然语言触发
```
请帮我在测试机上测试这个脚本：/path/to/script.sh
```

Claude 会自动识别并使用这个 skill。

### 直接使用辅助脚本

你也可以直接运行辅助脚本：

```bash
# 基本用法
.claude/skills/shell-remote-test/remote-test.sh /path/to/script.sh

# 指定远程用户
.claude/skills/shell-remote-test/remote-test.sh /path/to/script.sh -u pengzz

# 指定远程路径
.claude/skills/shell-remote-test/remote-test.sh /path/to/script.sh -p /opt/test

# 测试前运行 shellcheck
.claude/skills/shell-remote-test/remote-test.sh /path/to/script.sh --check

# 测试后保留远程文件
.claude/skills/shell-remote-test/remote-test.sh /path/to/script.sh --no-cleanup

# 传递参数给脚本
.claude/skills/shell-remote-test/remote-test.sh /path/to/script.sh -- --verbose --config=/etc/app.conf
```

## 配置说明

### 默认配置
- **远程主机**: 10.16.203.61
- **远程用户**: root
- **远程路径**: /tmp
- **测试后清理**: 是

### 环境变量配置

你可以通过环境变量覆盖默认配置：

```bash
export REMOTE_USER=pengzz
export REMOTE_PATH=/opt/test
export CLEANUP=no

.claude/skills/shell-remote-test/remote-test.sh /path/to/script.sh
```

## 前置条件

1. **SSH 免密登录已配置**
   ```bash
   # 测试 SSH 连接
   ssh root@10.16.203.61 "echo 'SSH 连接正常'"
   ```

2. **远程机器可访问**
   ```bash
   # 测试网络连接
   ping -c 3 10.16.203.61
   ```

3. **远程路径存在且有写权限**
   ```bash
   # 检查远程路径
   ssh root@10.16.203.61 "ls -ld /tmp"
   ```

## 功能特性

### ✅ 已实现
- 自动拷贝脚本到远程机器
- 远程执行脚本并捕获输出
- 显示执行时间和退出码
- 测试后自动清理远程文件
- 彩色日志输出
- 错误处理和友好提示
- 支持传递参数给脚本
- 可选的 shellcheck 静态检查

### 🚀 未来增强
- 支持并行测试多个脚本
- 保存测试日志到本地
- 支持多个测试机器
- 测试结果对比
- 自动生成测试报告

## 故障排查

### 问题 1：SSH 连接失败
```
[错误] 无法连接到远程主机 root@10.16.203.61
```

**解决方法**：
1. 检查网络连接：`ping 10.16.203.61`
2. 检查 SSH 服务：`ssh root@10.16.203.61`
3. 检查 SSH 密钥：`ssh-add -l`

### 问题 2：SCP 拷贝失败
```
[错误] 脚本拷贝失败
```

**解决方法**：
1. 检查远程路径是否存在
2. 检查远程用户权限
3. 检查磁盘空间：`ssh root@10.16.203.61 "df -h"`

### 问题 3：脚本执行失败
```
[错误] 脚本执行失败 ✗
```

**解决方法**：
1. 查看脚本输出中的错误信息
2. 检查脚本依赖是否满足
3. 在远程机器上手动测试脚本

## 示例

### 示例 1：测试简单脚本
```bash
# 创建测试脚本
cat > /tmp/hello.sh << 'EOF'
#!/bin/bash
echo "Hello from remote machine!"
hostname
date
EOF

# 远程测试
.claude/skills/shell-remote-test/remote-test.sh /tmp/hello.sh
```

### 示例 2：测试带参数的脚本
```bash
# 创建测试脚本
cat > /tmp/greet.sh << 'EOF'
#!/bin/bash
NAME=${1:-World}
echo "Hello, ${NAME}!"
EOF

# 远程测试（传递参数）
.claude/skills/shell-remote-test/remote-test.sh /tmp/greet.sh -- Claude
```

### 示例 3：测试前运行 shellcheck
```bash
# 远程测试（先运行 shellcheck）
.claude/skills/shell-remote-test/remote-test.sh /tmp/script.sh --check
```

## 文件结构

```
.claude/skills/shell-remote-test/
├── SKILL.md          # Skill 配置文件（Claude Code 使用）
├── remote-test.sh    # 辅助脚本（实际执行测试）
└── README.md         # 本文档
```

## 版本历史

- **v1.0.0** (2024-12-23): 初始版本
  - 基本的远程测试功能
  - SSH/SCP 自动化
  - 错误处理和日志输出
  - shellcheck 集成
