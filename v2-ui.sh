#!/usr/bin/env bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error：${plain} This script must be run with the root user！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}The system version is not detected, contact the script author！${plain}\n" && exit 1
fi

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ] ; then
    echo "The software does not support 32-bit systems (x86), please use a 64-bit system (x86_64) and contact the author if the detection is incorrect"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Use a CentOS 7 or later system！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Use a Ubuntu 16 or later system！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Use a Debian 8 or later system!${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [Default $2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar unzip -y
    else
        apt install wget curl tar unzip -y
    fi
}

uninstall_old_v2ray() {
    if [[ -f /usr/bin/v2ray/v2ray ]]; then
        confirm "If an older version of v2ray is detected, it will be deleted if it is uninstalled /usr/bin/v2ray/ and /etc/systemd/system/v2ray.service" "Y"
        if [[ $? != 0 ]]; then
            echo "V2-ui cannot be installed without uninstall"
            exit 1
        fi
        echo -e "${green}Uninstall the old version v2ray${plain}"
        systemctl stop v2ray
        rm /usr/bin/v2ray/ -rf
        rm /etc/systemd/system/v2ray.service -f
        systemctl daemon-reload
    fi
    if [[ -f /usr/local/bin/v2ray ]]; then
        confirm "V2ray installed in other ways, whether to uninstall, v2-ui comes with its own official xray kernel, and is recommended to prevent port conflicts with it" "Y"
        if [[ $? != 0 ]]; then
            #echo -e "${red}你选择了不卸载，请自行确保其它脚本安装的 v2ray 与 v2-ui ${green}自带的官方 xray 内核${red}不会端口冲突${plain}"
			echo -e "${red}If you choose not to uninstall, make sure that the v2ray installed by the other scripts does not conflict port ${plain} with the official xray kernel${red} that comes with v2-ui ${green}"
        else
            echo -e "${green}Start uninstalling v2ray installed in other ways${plain}"
            systemctl stop v2ray
            bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove
            systemctl daemon-reload
        fi
    fi
}

#close_firewall() {
#    if [[ x"${release}" == x"centos" ]]; then
#        systemctl stop firewalld
#        systemctl disable firewalld
#    elif [[ x"${release}" == x"ubuntu" ]]; then
#        ufw disable
#    elif [[ x"${release}" == x"debian" ]]; then
#        iptables -P INPUT ACCEPT
#        iptables -P OUTPUT ACCEPT
#        iptables -P FORWARD ACCEPT
#        iptables -F
#    fi
#}

install_v2-ui() {
    systemctl stop v2-ui
    cd /usr/local/
    if [[ -e /usr/local/v2-ui/ ]]; then
        rm /usr/local/v2-ui/ -rf
    fi

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/sprov065/v2-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Detecting the v2-ui version failed, possibly exceeding the Github API limit, try again later, or manually specify a v2-ui version installation${plain}"
            exit 1
        fi
        echo -e "The latest version of v2-ui has been detected: {last_version}, and the installation has begun"
        wget -N --no-check-certificate -O /usr/local/v2-ui-linux.tar.gz https://github.com/sprov065/v2-ui/releases/download/${last_version}/v2-ui-linux.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download v2-ui, make sure your server is able to download Github files${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/sprov065/v2-ui/releases/download/${last_version}/v2-ui-linux.tar.gz"
        echo -e "Start installing v2-ui v$1"
        wget -N --no-check-certificate -O /usr/local/v2-ui-linux.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download v2-ui v$1, make sure this version exists ${plain}"
            exit 1
        fi
    fi

    tar zxvf v2-ui-linux.tar.gz
    rm v2-ui-linux.tar.gz -f
    cd v2-ui
    chmod +x v2-ui bin/xray-v2-ui
    cp -f v2-ui.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable v2-ui
    systemctl start v2-ui
    echo -e "${green}v2-ui v${last_version}${plain} The installation is complete and the panel is started，"
    echo -e ""
    echo -e "In the case of a clean installation, the default web port is ${green}65432${plain}, and the username and password are both by default"
    echo -e "Make sure that this port is not occupied by another program, and make sure that the 65432 port is released $'plain'"
    echo -e "To modify 65432 to a different port, enter the v2-ui command to modify it, and also make sure that the port you modified is released"
    echo -e ""
    echo -e "If it's an update panel, access the panel the way you did before"
    echo -e ""
    curl -o /usr/bin/v2-ui -Ls https://raw.githubusercontent.com/sprov065/v2-ui/master/v2-ui.sh
    chmod +x /usr/bin/v2-ui
    echo -e "v2-ui Management Script Usage: "
    echo -e "----------------------------------------------"
    echo -e "v2-ui              - Show management menu (more features)"
    echo -e "v2-ui start        - Start the v2-ui panel"
    echo -e "v2-ui stop         - Stop the v2-ui panel"
    echo -e "v2-ui restart      - Restart the v2-ui panel"
    echo -e "v2-ui status       - View the v2-ui status"
    echo -e "v2-ui enable       - Set v2-ui to boot"
    echo -e "v2-ui disable      - Cancel v2-ui power-on"
    echo -e "v2-ui log          - View the v2-ui log"
    echo -e "v2-ui update       - Update the v2-ui panel"
    echo -e "v2-ui install      - Install the v2-ui panel"
    echo -e "v2-ui uninstall    - Uninstall the v2-ui panel"
    echo -e "----------------------------------------------"
}

echo -e "${green}Start the installation${plain}"
install_base
uninstall_old_v2ray
#close_firewall
install_v2-ui $1
