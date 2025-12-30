# 1. 清空白板
iptables -F
iptables -X
iptables -Z

# 2. 本机回环（必须最先）
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# 3. 允许已建立连接的回程包（SSH 不卡）
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 4. 放行公司内网（SSH + 文件传输）
iptables -A INPUT  -s 10.98.24.0/22 -j ACCEPT
iptables -A OUTPUT -d 10.98.24.0/22 -j ACCEPT

# 5. 放行 Docker 所有网段（含 docker0 172.17.0.0/16）
iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT   # 官方预留段，覆盖 172.17~172.31

# 6. 默认拒绝外网（DROP 放最后兜底）
iptables -A OUTPUT -d 0.0.0.0/0 -j DROP