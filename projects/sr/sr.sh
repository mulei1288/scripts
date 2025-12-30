#!/bin/bash

# ---------- 信号处理：捕获 Ctrl+C 立即退出 ----------
trap 'echo ""; echo "❌ 用户中断操作"; exit 130' INT TERM

# ---------- 参数校验 ----------
if [ $# -lt 2 ]; then
    echo "Usage: sr [rsync options] <source> <target>"
    exit 1
fi

user=root

passwords=(
    "bingo@word1"
    "pass@hci1"
)

# ---------- 提取 IP（清理 known_hosts 用） ----------
extract_ip() {
    echo "$1" | sed -n 's/.*@\{0,1\}\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p'
}

for arg in "$@"; do
    ip=$(extract_ip "$arg")
    [ -n "$ip" ] && ssh-keygen -f ~/.ssh/known_hosts -R "$ip" >/dev/null 2>&1
done

# ---------- 默认 rsync 参数 ----------
DEFAULT_RSYNC_OPTS=(-avz --progress -h)

# ---------- 尝试 rsync ----------
for pass in "${passwords[@]}"; do
    sshpass -p "$pass" rsync "${DEFAULT_RSYNC_OPTS[@]}" "$@" \
        -e "ssh -l $user \
            -o PreferredAuthentications=password \
            -o PubkeyAuthentication=no \
            -o NumberOfPasswordPrompts=1 \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout=5 \
            -o ServerAliveInterval=2 \
            -o ServerAliveCountMax=2"

    rc=$?

    if [[ $rc -eq 0 ]]; then
        exit 0
    fi
done

echo "❌ rsync failed: all passwords are invalid"
exit 1
