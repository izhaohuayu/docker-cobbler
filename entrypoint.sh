#!/bin/bash
set -ex

echo "=== Starting Cobbler Container ==="

# 配置变量检查
SERVER="${SERVER:-${SERVER_IP_V4:-127.0.0.1}}"

# 创建必要目录
mkdir -p /var/log/cobbler
mkdir -p /var/log/httpd  
mkdir -p /run/httpd
mkdir -p /var/lib/cobbler/config
mkdir -p /var/lib/cobbler/triggers
: > /var/log/cobbler/cobbler.log || true

# 如挂载卷为空则从镜像默认数据恢复
for v in /var/lib/cobbler /var/www/cobbler /var/lib/dhcpd; do
  if [ -d "${v}.save" ] && [ -z "$(ls -A "$v" 2>/dev/null)" ]; then
    echo "Restoring initial data into $v from ${v}.save ..."
    cp -a "${v}.save/." "$v/" || true
  fi
done

# 配置 Cobbler
echo "Configuring Cobbler..."
sed -i "s/^server: 127.0.0.1/server: $SERVER/g" /etc/cobbler/settings.yaml
sed -i "s/^next_server_v4: 127.0.0.1/next_server_v4: $SERVER/g" /etc/cobbler/settings.yaml

# 设置密码
if [ -n "$ROOT_PASSWORD" ]; then
    CRYPTED_PASSWORD=$(openssl passwd -1 "$ROOT_PASSWORD")
    sed -i "s#^default_password.*#default_password_crypted: \"$CRYPTED_PASSWORD\"#g" /etc/cobbler/settings.yaml
fi

# 修复 httpd 配置（设置 ServerName）
echo "ServerName $SERVER" >> /etc/httpd/conf/httpd.conf

# 启动 rsyslog
if [ -x /usr/sbin/rsyslogd ]; then
    /usr/sbin/rsyslogd || true
fi

# 启动 httpd
mkdir -p /var/log/httpd /run/httpd
: > /var/log/httpd/error_log || true
: > /var/log/httpd/access_log || true

echo "Starting httpd..."
/usr/sbin/httpd
sleep 2

# 验证 httpd 启动
if ! pgrep -x httpd > /dev/null; then
    echo "ERROR: httpd failed to start"
    test -f /var/log/httpd/error_log && cat /var/log/httpd/error_log || true
    exit 1
fi

# 启动 cobblerd  
echo "Starting cobblerd..."
/usr/bin/cobblerd -F &
COBBLER_PID=$!

# 等待 cobblerd 启动
echo "Waiting for cobblerd..."
for i in {1..30}; do
    if cobbler --version >/dev/null 2>&1; then
        echo "Cobblerd is ready!"
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 2
done

# 同步配置
echo "Syncing cobbler configuration..."
cobbler sync || echo "WARNING: Initial sync failed"

echo "=== Cobbler Started Successfully ==="
echo "Server IP: $SERVER"
echo "Web UI: http://$SERVER/cobbler_web"
echo "Username: cobbler"
echo "Password: cobbler"

# 显示服务状态
echo "=== Service Status ==="
pgrep -a httpd
pgrep -a cobblerd

# 保持容器运行
tail -f /var/log/cobbler/cobbler.log /var/log/httpd/access_log /var/log/httpd/error_log