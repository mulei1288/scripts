# 脚本规范：[create-resource-pool]

> 简洁版规范模板 - 适用于简单工具脚本（<100行，单一功能）

## 基本信息

- **脚本名称**：`create-resource-pool.sh`
- **严格性级别**：基础级
- **脚本类型**：可执行脚本
- **版本**：v1.0.0

## 功能描述

- 这个脚本用于将所有 worker 节点加入到一个 worker 资源池里

核心流程：
- 通过 kubectl 获取所有 worker 节点的节点名称
- 通过`uname -m`获取机器架构(所有机器架构一致，因此只需取本地就行)
- 生成资源池配置文件work-resource-pool.yaml
- 执行 kubectl apply -f work-resource-pool.yaml

## 使用方法

### 基本语法

```bash
create-resource-pool.sh
```

### 使用示例

```bash
# 示例 1：基本用法
create-resource-pool.sh
```


## 依赖工具
- bash 4.0+

## 注意事项

- 需要考虑失败重试，特别是执行 kubectl 时

## 资源池配置文件参考
```yaml
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
  - arch: [机器架构]
    name: [节点名称]
  poolName: worker资源池
  priority: 5

```
