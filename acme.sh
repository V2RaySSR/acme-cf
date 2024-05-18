#!/bin/bash

# 颜色定义
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

printf "${GREEN}====================自动申请SSL证书=========================${NC}\n"
printf "${BLUE} 本脚本支持：Debian9+ / Ubuntu16.04+ / Centos7+${NC}\n"
printf "${BLUE} 原创：www.v2rayssr.com （已开启禁止国内访问）${NC}\n"
printf "${BLUE} YouTube频道：波仔分享${NC}\n"
printf "${BLUE} 本脚本禁止在国内任何网站转载${NC}\n"
printf "${GREEN}==========================================================${NC}\n"

# 默认密钥文件路径
DEFAULT_KEY_FILE="/root/1.key"
DEFAULT_CERT_FILE="/root/1.crt"

check_acme_installation() {
    if [ -d "/root/.acme.sh" ]; then
        if [ -f "/root/.acme.sh/account.conf" ]; then
            CF_KEY=$(grep 'SAVED_CF_Key' /root/.acme.sh/account.conf | cut -d'=' -f2)
            CF_EMAIL=$(grep 'SAVED_CF_Email' /root/.acme.sh/account.conf | cut -d'=' -f2)
            if [ -n "$CF_KEY" ] && [ -n "$CF_EMAIL" ]; then
                CF_KEY_DISPLAY="*****${CF_KEY: -8}"
                printf "${YELLOW}ACME 已安装。${NC}\n"
                printf "${YELLOW}已读取到的 Cloudflare API 密钥: ${CF_KEY_DISPLAY}${NC}\n"
                printf "${YELLOW}已读取到的 Cloudflare 邮箱地址: $CF_EMAIL${NC}\n"
                read -p "是否使用这组账号继续？(y/n): " USE_EXISTING_ACCOUNT
                if [[ "$USE_EXISTING_ACCOUNT" == "y" || "$USE_EXISTING_ACCOUNT" == "Y" ]]; then
                    return 0
                else
                    return 1
                fi
            else
                printf "${YELLOW}ACME 已安装，但未能读取到 Cloudflare API 密钥和邮箱信息。${NC}\n"
                return 1
            fi
        else
            printf "${YELLOW}ACME 已安装，但未找到配置文件。${NC}\n"
            return 1
        fi
    else
        printf "${YELLOW}ACME 未安装。即将安装 ACME 脚本，生成环境请注意覆盖。${NC}\n"
        return 1
    fi
}

input_parameters() {
    read -p "请输入主域名 (例如: example.com): " DOMAIN
    read -p "请输入注册 Cloudflare 帐户的邮箱地址: " EMAIL
    read -p "请输入 Cloudflare API 密钥: " API_KEY
    read -p "请输入密钥文件路径 (按回车使用默认路径 $DEFAULT_KEY_FILE): " KEY_FILE
    KEY_FILE=${KEY_FILE:-$DEFAULT_KEY_FILE}
    read -p "请输入证书文件路径 (按回车使用默认路径 $DEFAULT_CERT_FILE): " CERT_FILE
    CERT_FILE=${CERT_FILE:-$DEFAULT_CERT_FILE}
}

install_socat() {
    if [[ -x "$(command -v yum)" ]]; then
        yum install -y socat
    elif [[ -x "$(command -v apt-get)" ]]; then
        apt-get update -qy  # 禁用 apt-get update 命令的输出
        apt-get install -y socat
    else
        printf "${RED}未知的 Linux 发行版，无法安装 socat。${NC}\n"
        exit 1
    fi
}

install_acme() {
    install_socat
    curl https://get.acme.sh | sh
}

register_account_email() {
    /root/.acme.sh/acme.sh --register-account -m "$EMAIL" --server zerossl
}

write_cloudflare_config() {
    sed -i '$aSAVED_CF_Key='"$API_KEY" /root/.acme.sh/account.conf
    sed -i '$aSAVED_CF_Email='"$EMAIL" /root/.acme.sh/account.conf
}

request_certificate() {
    /root/.acme.sh/acme.sh --issue --dns dns_cf -d "*.$DOMAIN"
}

install_certificate() {
    /root/.acme.sh/acme.sh --installcert -d "*.$DOMAIN" --key-file "$KEY_FILE" --fullchain-file "$CERT_FILE"
}

main() {
    check_acme_installation
    if [ $? -ne 0 ]; then
        input_parameters
    else
        read -p "请输入域名 (例如: v2rayssr.com): " DOMAIN
        EMAIL=$CF_EMAIL
        API_KEY=$CF_KEY
        read -p "请输入密钥文件路径 (按回车使用默认路径 $DEFAULT_KEY_FILE): " KEY_FILE
        KEY_FILE=${KEY_FILE:-$DEFAULT_KEY_FILE}
        read -p "请输入证书文件路径 (按回车使用默认路径 $DEFAULT_CERT_FILE): " CERT_FILE
        CERT_FILE=${CERT_FILE:-$DEFAULT_CERT_FILE}
    fi

    if [ ! -d "/root/.acme.sh" ]; then
        install_acme
    fi
    register_account_email
    write_cloudflare_config
    request_certificate
    if [ -f "/root/.acme.sh/*.${DOMAIN}_ecc/ca.cer" ]; then
        install_certificate
        printf "${GREEN}证书申请成功。${NC}\n"
        printf "${GREEN}您的证书文件: ${CERT_FILE}${NC}\n"
        printf "${GREEN}您的密钥文件: ${KEY_FILE}${NC}\n"
    else
        printf "${RED}证书未能下发。${NC}\n"
    fi
}

main
