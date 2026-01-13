#!/bin/bash

# 简化版 - 显示 key 和 value

PREFIX="/verse"

echo "正在检查前缀 '$PREFIX' 下的 values 是否包含 IP 地址..."
echo "=========================================================="

# 临时文件
TEMP_FILE="/tmp/etcd_output.txt"


# 定义 ectl 函数
ectl() {
    ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
        --cacert=/etc/kubernetes/pki/etcd/ca.crt \
        --cert=/etc/kubernetes/pki/etcd/server.crt \
        --key=/etc/kubernetes/pki/etcd/server.key "$@"
}


# 获取所有键值对
ectl get "$PREFIX" --prefix > "$TEMP_FILE"

count=0
found_ips=0
current_key=""

while IFS= read -r line; do
    # 如果是空行，跳过
    if [ -z "$line" ]; then
        continue
    fi

    # 如果行以 / 开头，认为是 key
    if [[ "$line" == /* ]]; then
        current_key="$line"
    else
        # 否则是 value (base64 编码)
        if [ -n "$current_key" ]; then
            count=$((count + 1))
            value_b64="$line"

            # 解码 base64
            value_decoded=$(echo "$value_b64" | base64 -d 2>/dev/null)

            # 检查是否包含 IP 地址
            if echo "$value_decoded" | grep -q -E '([0-9]{1,3}\.){3}[0-9]{1,3}'; then
                found_ips=$((found_ips + 1))
                echo "🔍 发现包含 IP 地址的键值对 #$found_ips:"
                echo "----------------------------------------"
                echo "Key: $current_key"
                echo "Base64 Value: $value_b64"
                echo "解码后的 Value: $value_decoded"
                echo

                # 提取并显示具体的 IP 地址
                echo "发现的 IP 地址:"
                echo "$value_decoded" | grep -o -E '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u
                echo "========================================"
                echo
            fi

            current_key=""
        fi
    fi
done < "$TEMP_FILE"

# 清理临时文件
rm -f "$TEMP_FILE"

echo "检查完成!"
echo "总共检查了 $count 个键值对"
echo "其中 $found_ips 个值的 value 包含 IP 地址"
