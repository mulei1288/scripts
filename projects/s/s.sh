#!/bin/bash

# ---------- 参数校验 ----------
if [ -z "$1" ]; then
    echo "Usage: s <ip>"
    exit 1
fi

# ---------- 连接参数 ----------
user=root
ip=$1

passwords=(
    "bingo@word1"
    "pass@hci1"
)

# ---------- 清理 known_hosts ----------
ssh-keygen -f ~/.ssh/known_hosts -R "$ip" >/dev/null 2>&1

# ---------- 尝试连接 ----------
for pass in "${passwords[@]}"; do
    sshpass -p "$pass" ssh \
        -o PreferredAuthentications=password \
        -o PubkeyAuthentication=no \
        -o NumberOfPasswordPrompts=1 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=1 \
        -o ServerAliveInterval=1 \
        -o ServerAliveCountMax=1 \
        "$user@$ip"

    rc=$?

    # 0: 正常退出
    # 130: Ctrl+C（说明已经成功连上）
    if [[ $rc -eq 0 || $rc -eq 130 ]]; then
        exit 0
    fi
done

# ---------- 全部失败 ----------
echo "❌ SSH login failed: all passwords are invalid"
exit 1