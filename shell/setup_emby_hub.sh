#!/bin/bash
set -euo pipefail

# 检查是否在bash环境下运行
if [ -z "${BASH_VERSION:-}" ]; then
    echo "错误：请使用bash运行此脚本，而非sh或其他shell"
    exit 1  # 此为环境错误，必须退出
fi

# 欢迎信息
echo "============================================="
echo "          Emby Hub 配置脚本                  "
echo "============================================="
echo "此脚本将帮助您生成Emby Hub的docker-compose配置文件"
echo "请根据提示输入必要信息，所有带*的为必填项"
echo "若输入错误，可重新输入，无需重启脚本"
echo "============================================="
echo

# 设置镜像（默认为amd64架构）
EMBY_HUB_IMAGE="ciwei123321/emby-hub:latest"
EMBY_HUB_WEB_IMAGE="ciwei123321/emby-hub-web:latest"

# 自定义数据存储路径（默认./data，路径不可用时重新输入）
echo "【数据存储路径】"
echo "设置Emby Hub的数据存储路径，默认使用当前目录下的data文件夹"
echo "建议选择有足够空间的位置，将存储配置、缓存和媒体信息等数据"
while true; do
    read -p "请输入数据存储路径 (默认: ./data): " DATA_PATH
    # 如果用户未输入，使用默认路径
    if [ -z "$DATA_PATH" ]; then
        DATA_PATH="./data"
    fi
    # 尝试创建路径
    if mkdir -p "$DATA_PATH"; then
        echo "数据将存储在: $DATA_PATH"
        break
    else
        echo "无法创建数据目录 $DATA_PATH，请重新输入路径"
    fi
done

echo -e "\n将使用以下镜像:"
echo "  - 主程序: $EMBY_HUB_IMAGE"
echo "  - 网页界面: $EMBY_HUB_WEB_IMAGE"
echo

# 输入Emby API密钥和服务器地址（合并IP和端口）
echo "【Emby服务器配置】"
echo "需要连接到您的Emby服务器，请准备好相关信息"
echo "API密钥可在Emby服务器的设置->高级->API秘钥"
while true; do
    read -p "Emby API密钥*: " EMBY_APIKEY
    if [ -n "$EMBY_APIKEY" ]; then
        break
    else
        echo "Emby API密钥不能为空，请重新输入"
    fi
done

# 新增：EMBY协议选择（http/https）
echo -e "\n请选择Emby服务器的连接协议（根据您的Emby部署方式选择）："
echo "  - http：适用于未启用SSL的Emby服务器（默认，如本地部署）"
echo "  - https：适用于已配置SSL证书的Emby服务器（如公网部署）"
while true; do
    read -p "请选择协议 (http/https)*: " EMBY_PROTOCOL
    EMBY_PROTOCOL=$(echo "$EMBY_PROTOCOL" | tr '[:upper:]' '[:lower:]')  # 转为小写
    if [ "$EMBY_PROTOCOL" = "http" ] || [ "$EMBY_PROTOCOL" = "https" ]; then
        echo "已选择协议：$EMBY_PROTOCOL"
        break
    else
        echo "输入错误，请重新输入'http'或'https'选择协议"
    fi
done

# 合并输入Emby服务器IP和端口，格式验证
echo -e "\n请输入Emby服务器的地址和端口，格式为 IP:端口"
echo "例如：192.168.1.100:8096（Emby默认端口为8096）"
echo "确保本机器能访问该服务器地址（若选https，需确认端口对应SSL服务）"
while true; do
    read -p "Emby服务器地址和端口 (IP:端口)*: " EMBY_SERVER
    if [ -z "$EMBY_SERVER" ]; then
        echo "服务器地址不能为空，请重新输入"
        continue
    fi

    # 简单验证格式是否包含:和端口部分
    if [[ "$EMBY_SERVER" =~ ^[^:]+:[0-9]+$ ]]; then
        break
    else
        echo "格式错误，请使用 IP:端口 格式（例如 192.168.1.100:8096）"
    fi
done

# 输入要复制权限的Emby用户ID（空值时重新输入）
echo "用户ID是Emby中用户的唯一标识，可在用户管理页面查看"
echo "此用户的权限将被用作模板复制给其他用户"
while true; do
    read -p "要复制权限的Emby用户ID*: " EMBY_COPYFROMUSERID
    if [ -n "$EMBY_COPYFROMUSERID" ]; then
        break
    else
        echo "Emby用户ID不能为空，请重新输入"
    fi
done

# 输入并验证TMDB API令牌（空值时重新输入）
echo -e "\n【TMDB配置】"
echo "TMDB（The Movie Database）提供电影和电视剧的元数据"
echo "需要在https://www.themoviedb.org/申请API令牌"
echo "注意：需要的是API Read Access Token（v4 auth）"
while true; do
    read -p "TMDB API令牌*: " TMDB_APITOKEN
    if [ -n "$TMDB_APITOKEN" ]; then
        break
    else
        echo "TMDB API令牌不能为空，请重新输入"
    fi
done

# 代理设置
echo -e "\n【代理设置（可选）】"
echo "如您的网络需要代理才能访问外部资源，请填写代理信息"
echo "如无代理，直接按回车跳过即可"
read -p "HTTP代理IP (如无代理可直接回车): " PROXY_IP
read -p "HTTP代理端口 (如无代理可直接回车): " PROXY_PORT

# 处理代理设置
if [ -z "$PROXY_IP" ] || [ -z "$PROXY_PORT" ]; then
    HTTP_PROXY_ENABLED="false"
    HTTP_PROXY=""
    HTTPS_PROXY=""
else
    HTTP_PROXY_ENABLED="true"
    HTTP_PROXY="http://$PROXY_IP:$PROXY_PORT"
    HTTPS_PROXY="http://$PROXY_IP:$PROXY_PORT"
    echo "已配置代理: $HTTP_PROXY"
fi

# 读取密码（带验证，错误时重新输入）
echo -e "\n【数据库配置】"
echo "设置MySQL数据库的root密码，用于容器内部数据库访问"
echo "请设置一个安全的密码，至少包含8个字符"
while true; do
    read -s -p "设置MySQL root密码*: " DB_ROOT_PASSWORD
    echo
    if [ -z "$DB_ROOT_PASSWORD" ]; then
        echo "密码不能为空，请重新输入"
        continue
    fi

    if [ ${#DB_ROOT_PASSWORD} -lt 8 ]; then
        echo "密码长度建议至少8个字符，请设置更安全的密码"
        continue
    fi

    read -s -p "确认MySQL root密码*: " DB_ROOT_PASSWORD_CONFIRM
    echo

    if [ "$DB_ROOT_PASSWORD" = "$DB_ROOT_PASSWORD_CONFIRM" ]; then
        break
    else
        echo "两次输入的密码不一致，请重新输入"
    fi
done

# 生成docker-compose.yml文件
echo -e "\n============================================="
echo "所有必要信息已收集完毕，正在生成配置文件..."
echo "============================================="

# 动态构建EMBY_URL（根据选择的协议拼接）
EMBY_URL="$EMBY_PROTOCOL://$EMBY_SERVER/emby/"

cat > docker-compose.yml << EOF
version: '3'
services:
  emby-hub:
    image: $EMBY_HUB_IMAGE
    privileged: true
    ports:
      - "8080:8080"
    volumes:
      - $DATA_PATH:/data
      - /etc/hosts:/etc/hosts
    container_name: emby-hub
    restart: always
    environment:
      - SPRING_DATASOURCE_URL=jdbc:mysql://db:3306/emby-hub?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=GMT%2B8&allowPublicKeyRetrieval=true
      - SPRING_DATASOURCE_USERNAME=root
      - SPRING_DATASOURCE_PASSWORD=$DB_ROOT_PASSWORD
      - EMBY_APIKEY=$EMBY_APIKEY
      - EMBY_URL=$EMBY_URL
      - EMBY_COPYFROMUSERID=$EMBY_COPYFROMUSERID
      - TMDB_APITOKEN=$TMDB_APITOKEN
      - TMDB_IMAGE_URL=https://image.tmdb.org/t/p/original
      - TZ=Asia/Shanghai
      - HTTP_PROXY_ENABLED=$HTTP_PROXY_ENABLED
      - HTTP_PROXY=$HTTP_PROXY
      - HTTPS_PROXY=$HTTPS_PROXY
      - NO_PROXY=172.17.0.1,127.0.0.1,localhost
      - LICENSE_FILE=/data/license.dat
    networks:
      - emby-hub-network
    links:
      - db
    depends_on:
      - db

  db:
    image: mysql:8.4.6
    container_name: mysql_container
    environment:
      MYSQL_ROOT_PASSWORD: $DB_ROOT_PASSWORD
      MYSQL_DATABASE: emby-hub
      TZ: "Asia/Shanghai"
      LANG: en_US.UTF-8
    command:
      - mysqld
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --group_concat_max_len=102400
    ports:
      - "3306:3306"
    volumes:
      - ./mysql-data:/var/lib/mysql
    restart: always
    networks:
      - emby-hub-network

  emby-hub-web:
    image: $EMBY_HUB_WEB_IMAGE
    container_name: emby-hub-web
    restart: always
    environment:
      - TZ=Asia/Shanghai
      - EMBY_HUB_API_URL=http://emby-hub:8080
      - LANG=en_US.UTF-8
      - IMAGE_URL=https://image.tmdb.org/t/p/
    ports:
      - "8081:8081"
    networks:
      - emby-hub-network
    links:
      - emby-hub
    depends_on:
      - emby-hub

networks:
  emby-hub-network:
EOF

# 检查文件是否生成成功
if [ -f "docker-compose.yml" ]; then
    echo -e "\n============================================="
    echo "配置文件生成成功: docker-compose.yml"
    echo "============================================="
    echo "使用信息："
    echo "  - 镜像: $EMBY_HUB_IMAGE 和 $EMBY_HUB_WEB_IMAGE"
    echo "  - 数据存储路径: $DATA_PATH"
    echo "  - 连接的Emby服务器: $EMBY_URL"
    echo "  - 服务端口: 8080 (主服务), 8081 (网页界面), 3306 (数据库)"
    echo
    echo "启动服务命令:"
    echo "  docker-compose up -d"
    echo
    echo "查看日志命令:"
    echo "  docker-compose logs -f"
    echo
    echo "停止服务命令:"
    echo "  docker-compose down"
    echo -e "=============================================\n"
else
    echo "错误：配置文件生成失败"
    exit 1
fi