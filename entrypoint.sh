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
SETTINGS_FILE="/etc/cobbler/settings.yaml"
[ -f "/etc/cobbler/settings" ] && SETTINGS_FILE="/etc/cobbler/settings"

echo "Using settings file: $SETTINGS_FILE"
sed -i "s/^server: .*/server: $SERVER/g" "$SETTINGS_FILE" || true
sed -i "s/^next_server_v4: .*/next_server_v4: $SERVER/g" "$SETTINGS_FILE" || true
# Desktop 模式下默认不托管 DHCP
sed -i "s/^manage_dhcp: .*/manage_dhcp: 0/g" "$SETTINGS_FILE" || true

# 设置安装默认 root 密码
if [ -n "$ROOT_PASSWORD" ]; then
    CRYPTED_PASSWORD=$(openssl passwd -1 "$ROOT_PASSWORD")
    sed -i "s#^default_password_crypted:.*#default_password_crypted: \"$CRYPTED_PASSWORD\"#g" /etc/cobbler/settings.yaml || true
fi

# 创建 Web UI 账户（cobbler/cobbler）
if [ ! -f /etc/cobbler/users.digest ]; then
  echo "Creating default Cobbler Web UI user 'cobbler'"
  htdigest -c -b /etc/cobbler/users.digest "Cobbler" cobbler cobbler || true
fi

# 修复 httpd 配置（设置 ServerName）
echo "ServerName $SERVER" >> /etc/httpd/conf/httpd.conf

# 配置 Apache 路由（如缺失则创建）
if [ ! -f /etc/httpd/conf.d/cobbler_api.conf ]; then
cat > /etc/httpd/conf.d/cobbler_api.conf <<'EOF'
WSGIDaemonProcess cobbler-api display-name=%{GROUP} processes=2 threads=15
WSGIScriptAlias /cobbler_api /var/www/cobbler/svc/services.py process-group=cobbler-api application-group=%{GLOBAL}
<Directory "/var/www/cobbler/svc">
    Require all granted
</Directory>
EOF
fi

if [ -d /usr/share/cobbler/web ] && [ ! -f /etc/httpd/conf.d/cobbler_web.conf ]; then
cat > /etc/httpd/conf.d/cobbler_web.conf <<'EOF'
Alias /cobbler_web /usr/share/cobbler/web
<Directory "/usr/share/cobbler/web">
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
    DirectoryIndex index.html index.htm
</Directory>
EOF
fi

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
COBBLERD_PATH="/usr/bin/cobblerd"
if [ ! -x "$COBBLERD_PATH" ] && [ -x "/usr/sbin/cobblerd" ]; then
  COBBLERD_PATH="/usr/sbin/cobblerd"
fi

echo "Starting cobblerd from $COBBLERD_PATH ..."
$COBBLERD_PATH -F &
COBBLER_PID=$!

# 等待 cobblerd 启动（通过 XMLRPC 健康检查）
echo "Waiting for cobblerd (XMLRPC) ..."
READY=0
for i in {1..30}; do
  if cobbler status >/dev/null 2>&1; then
    echo "Cobblerd is ready!"
    READY=1
    break
  fi
  echo "Waiting... ($i/30)"
  sleep 2
done
if [ "$READY" != "1" ]; then
  echo "cobblerd not ready after timeout. Last lines from /var/log/cobbler/cobbler.log:"
  tail -n 100 /var/log/cobbler/cobbler.log || true
fi

# 运行自检
echo "Running 'cobbler check'..."
cobbler check || true

# 同步配置
echo "Syncing cobbler configuration..."
cobbler sync || echo "WARNING: Initial sync failed"

echo "=== Cobbler Started Successfully ==="
echo "Server IP: $SERVER"
echo "Web UI: http://$SERVER:80/cobbler_web"
echo "Username: cobbler"
echo "Password: cobbler"

# 显示服务状态
echo "=== Service Status ==="
pgrep -a httpd
pgrep -a cobblerd

# 保持容器运行
tail -f /var/log/cobbler/cobbler.log /var/log/httpd/access_log /var/log/httpd/error_log