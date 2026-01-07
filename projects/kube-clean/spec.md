# 脚本规范：clean.sh

## 基本信息

- **脚本名称**：`clean.sh`
- **严格性级别**：简单
- **脚本类型**：可执行脚本
- **作者**：pengzhaozun
- **创建日期**：2025-12-19
- **版本**：v1.0.0

## 功能概述
集群清理脚本，用于清理无用的数据

## 执行流程

### 获取 VIP
```bash
# 从/etc/hosts获取，根据apiserver.cluster.local截取，举例如下，当前 VIP 为10.16.203.233
10.16.203.233 apiserver.cluster.local # hostalias-set-by-pilotctl
```

### 执行以下脚本
```bash
cd /var/lib/kubepilot/data/kube-cluster/rootfs
bash scripts/clean-kube.sh
bash scripts/uninstall-containerd.sh
```

### 清理/etc/hosts记录，带`hostalias-set-by-pilotctl`注释的
```
# 比如以下的记录：
10.16.203.128 node128 # hostalias-set-by-pilotctl
10.16.203.233 registry.nudt.edu.cn # hostalias-set-by-pilotctl
```

### 清理 VIP 记录
```bash
ip addr flush to <vip>
```

### 其他清理操作
```bash
rm -rf /root/.kubepilot
rm -rf /root/.kube/
rm -rf /kube-db
rm -rf /kube/
```

## 使用方法
```bash
./clean.sh
```

## 注意事项
