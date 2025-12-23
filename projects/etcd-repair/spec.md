# 脚本规范：etcd-check

## 基本信息

- **脚本名称**：`etcd-repair.sh`
- **严格性级别**：简单
- **脚本类型**：可执行脚本
- **作者**：pengzhaozun
- **创建日期**：2025-12-19
- **版本**：v1.0.0

## 功能概述
修复 k8s的 etcd集群的异常member，先将异常的member移除，然后重新加入集群

核心流程：
- 相关内容备份
  - 备份/etc/kubernetes/manifests/etcd.yaml
  - 以正常的 etcd 节点为基准，先进行一次数据备份（直接备份到当前目录）
- 停掉 etcd 服务
  - systemctl stop kubelet
  - crictl ps -a | grep etcd
  - crictl stop <etcd-container-id>
- 将异常的 member 剔除，然后再重新加入集群
  - 先删除 etcd 数据
    - cd /var/lib/etcd/
    - mv member bak_member_$(date +%F-%H-%M)
  - 修改/etc/kubernetes/manifests/etcd.yaml
    ```bash
        - --initial-cluster=<节点A_名称>=https://<IP_A>:2380,<节点B_名称>=https://<IP_B>:2380,<节点C_名称>=https://<IP_C>:2380 # 需补全 initial-cluster 信息完整
        - --initial-cluster-state=existing   # 如缺失必须添加  
    ```
  - 移除 member：ectl member remove <异常节点_MEMBER_ID>
  - 添加 member：ectl member add <节点名称> --peer-urls=https://<节点IP>:2380
- 重新启动 etcd 服务
  - 执行systemctl restart kubelet
- 状态检测
  - ectl endpoint status -w table --cluster
  - ectl endpoint health --cluster

## 使用场景

- 场景 1：etcd 集群部分节点不可用
- 场景 2：数据不一致或丢失
- 场景 3：etcd 集群脑裂

## 使用方法
```bash
#进入到异常的 member 节点上
./etcd-repair.sh <异常节点 IP>
```

## 注意事项
- 备份时，需要过滤掉指定的异常节点 IP，然后指定--endpoint为一个正常的etcd节点来进行数据备份
