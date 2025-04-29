#!/bin/bash
# ===== 检查依赖 =====
if [ "$(id -u)" != "0" ]; then
    echo "❌ 请使用 root 用户或加 sudo 执行本脚本"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "❌ 未找到 jq，请先安装：sudo apt install jq"
    exit 1
fi
echo '
      _                  _            _     
   __| |   ___     ___  | |_    ___  | |__  
  / _` |  / _ \   / __| | __|  / __| | `__ \ 
 | (_| | | (_) | | (__  | |_  | (__  | | | |
  \__,_|  \___/   \___|  \__|  \___| |_| |_|

            Made by Shuyingyang 
'

# ========== 配置 ==========

mode=${MODE:-"registry"}         # 可为 registry 或 proxy(proxy模式需要自己调配脚本)
registry=${REGISTRY:-"auto"}
http_proxy=${HTTP_PROXY:-""}
https_proxy=${HTTPS_PROXY:-""}
no_proxy=${NO_PROXY:-"localhost,127.0.0.1,.example.com"}

TEST_IMAGE="library/hello-world:latest"
TIMEOUT=30

REGISTRY_OFFICIAL="registry-1.docker.io"
REGISTRY_LIST_DEFAULT=(
    "1panel@docker.1panel.live"
    "rat@hub.rat.dev"
    "nastool@dk.nastool.de"
    "aidenxin@docker.aidenxin.xyz"
    "1ms@docker.1ms.run"
    "actima@docker.actima.top"
    "quan-ge@docker.120322.xyz"
    "znnu@dockerpull.cn"
    "hlmirror@docker.hlmirror.com"
    "CoderJia@docker-0.unsee.tech"
)

DOCKER_CONFIG="/etc/docker/daemon.json"
DOCKER_CONFIG_TMP="$DOCKER_CONFIG.tmp"
DOCKER_CONFIG_BAK="$DOCKER_CONFIG.doctch.bak"

# ========== 当前 Docker 配置读取 ==========

read_docker_info() {
    local info=$(docker info)
    docker_http_proxy=$(echo "$info" | grep 'HTTP Proxy' | awk -F ': ' '{print $2}')
    docker_https_proxy=$(echo "$info" | grep 'HTTPS Proxy' | awk -F ': ' '{print $2}')
    docker_no_proxy=$(echo "$info" | grep 'No Proxy' | awk -F ': ' '{print $2}')
    docker_registry_mirrors=$(echo "$info" | grep 'Registry Mirrors' -A 1 | tail -n 1 | sed 's/  //')
}

# ========== 测试官方是否能直连 ==========

test_direct_connect() {
    echo "正在测试 Docker Hub 直连..."
    if timeout --foreground 2 bash -c ">/dev/tcp/${REGISTRY_OFFICIAL}/443"; then
        docker rmi -f "${TEST_IMAGE}" >/dev/null 2>&1
        if timeout --foreground $TIMEOUT docker pull --disable-content-trust=true "${REGISTRY_OFFICIAL}/${TEST_IMAGE}" >/dev/null 2>&1; then
            echo -e "->直连成功"
            return 0
        fi
    fi
    echo "<-直连失败"
    return 1
}

# ========== 获取镜像源列表==========

get_registry_list() {
    echo "正在获取镜像列表"
    REGISTRY_LIST=("${REGISTRY_LIST_DEFAULT[@]}")
}

# ========== 测速，选最快镜像源 ==========

test_speed() {
    fastest_registry=""
    fastest_time=9999
    docker rmi -f "${TEST_IMAGE}" >/dev/null 2>&1
    for registry in "${REGISTRY_LIST[@]}"; do
        registry_url=$(echo "$registry" | cut -d'@' -f2)
        echo "测试 $registry_url ..."
        if timeout --foreground 2 bash -c ">/dev/tcp/$registry_url/443"; then
            start=$(date +%s)
            if timeout --foreground $TIMEOUT docker pull --disable-content-trust=true "${registry_url}/${TEST_IMAGE}" >/dev/null 2>&1; then
                end=$(date +%s)
                delta=$((end - start))
                echo "->成功 ${delta} 秒"
                if [ $delta -lt $fastest_time ]; then
                    fastest_time=$delta
                    fastest_registry=$registry_url
                fi
            else
                echo "<─ 拉取失败"
            fi
        else
            echo "<─ TCP连接失败"
        fi
        docker rmi -f "${registry_url}/${TEST_IMAGE}" >/dev/null 2>&1
    done
    [ -z "$fastest_registry" ] && echo "没有可用镜像源"
}

# ========== 安全修改 Docker 配置 ==========

safe_set_daemon() {
    [ ! -s "$DOCKER_CONFIG" ] && echo '{}' > "$DOCKER_CONFIG"
    [ ! -f "$DOCKER_CONFIG_BAK" ] && cp "$DOCKER_CONFIG" "$DOCKER_CONFIG_BAK"

    if [ "$mode" = "registry" ]; then
        echo "模式: 镜像加速"
        if test_direct_connect; then
            echo "可直连，不使用镜像源"
            return
        fi
        get_registry_list
        test_speed
        if [ -z "$fastest_registry" ]; then
            jq 'del(."registry-mirrors")' "$DOCKER_CONFIG" > "$DOCKER_CONFIG_TMP"
        else
            jq --arg reg "$fastest_registry" '. + { "registry-mirrors": ["https://\($reg)"] }' "$DOCKER_CONFIG" >"$DOCKER_CONFIG_TMP"
        fi
    else
        echo "模式: HTTP 代理"
        jq --arg http "$http_proxy" \
           --arg https "$https_proxy" \
           --arg no "$no_proxy" \
           '. + { "proxies": {
                "http-proxy": $http,
                "https-proxy": $https,
                "no-proxy": $no
           }}' "$DOCKER_CONFIG" > "$DOCKER_CONFIG_TMP"
    fi

    if [ -s "$DOCKER_CONFIG_TMP" ]; then
        mv "$DOCKER_CONFIG_TMP" "$DOCKER_CONFIG"
        echo "Docker 配置已更新：$DOCKER_CONFIG"
        echo "正在重启 Docker 服务..."
        systemctl restart docker && echo "-> Docker 重启成功"
    fi
}

# ========== 主入口 ==========

start() {
    read_docker_info
    safe_set_daemon
}

# ========== 启动命令 ==========

case "$1" in
start) start ;;
*) echo "Usage: $0 start" && exit 1 ;;
esac
