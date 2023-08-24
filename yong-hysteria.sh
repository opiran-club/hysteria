#!/bin/bash
hyygV="23.3.17 V 5.9"
remoteV=`wget -qO- https://gitlab.com/rwkgyg/hysteria-yg/raw/main/hysteria.sh | sed  -n 2p | cut -d '"' -f 2`
chmod +x /root/hysteria.sh 
red='\033[0;31m'
yellow='\033[0;33m'
bblue='\033[0;34m'
plain='\033[0m'
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
readp(){ read -p "$(yellow "$1")" $2;}
[[ $EUID -ne 0 ]] && yellow "Please run the script as root" && exit
#[[ -e /etc/hosts ]] && grep -qE '^ *172.65.251.78 gitlab.com' /etc/hosts || echo -e '\n172.65.251.78 gitlab.com' >> /etc/hosts
yellow " Please wait for 3 seconds... Scanning VPS type and parameters..."
if [[ -f /etc/redhat-release ]]; then
release="Centos"
elif cat /etc/issue | grep -q -E -i "debian"; then
release="Debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
elif cat /proc/version | grep -q -E -i "debian"; then
release="Debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
else 
red "Your current system is not supported. Please choose Ubuntu, Debian, or Centos." && exit
fi
vsid=`grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1`
sys(){
[ -f /etc/os-release ] && grep -i pretty_name /etc/os-release | cut -d \" -f2 && return
[ -f /etc/lsb-release ] && grep -i description /etc/lsb-release | cut -d \" -f2 && return
[ -f /etc/redhat-release ] && awk '{print $0}' /etc/redhat-release && return;}
op=`sys`
version=`uname -r | awk -F "-" '{print $1}'`
main=`uname  -r | awk -F . '{print $1}'`
minor=`uname -r | awk -F . '{print $2}'`

bit=`uname -m`
if [[ $bit = x86_64 ]]; then
cpu=amd64
elif [[ $bit = aarch64 ]]; then
cpu=arm64
elif [[ $bit = s390x ]]; then
cpu=s390x
else
red "VPS CPU architecture is $bit, this script doesn't support the current CPU architecture. Please use an amd64 or arm64 CPU architecture to run the script." && exit
fi
vi=`systemd-detect-virt`
rm -rf /etc/localtime
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

wgcfgo(){
wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
sureipadress
else
systemctl stop wg-quick@wgcf >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
sureipadress
systemctl start wg-quick@wgcf >/dev/null 2>&1
systemctl restart warp-go >/dev/null 2>&1
systemctl enable warp-go >/dev/null 2>&1
systemctl start warp-go >/dev/null 2>&1
fi
}

start(){
if [[ $vi = openvz ]]; then
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ 'in error state' ]] && [[ ! $TUN =~ 'The file handle is in bad interpreter' ]]; then 
red "TUN is not enabled, trying to add TUN support" && sleep 2
cd /dev
mkdir net
mknod net/tun c 10 200
chmod 0666 net/tun
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ 'in error state' ]] && [[ ! $TUN =~ 'The file handle is in bad interpreter' ]]; then 
green "Failed to add TUN support, consider contacting your VPS provider or enabling it in the control panel." && exit
else
green "Congratulations, added TUN support successfully, now adding TUN guardian functionality" && sleep 4
cat>/root/tun.sh<<-\EOF
#!/bin/bash
cd /dev
mkdir net
mknod net/tun c 10 200
chmod 0666 net/tun
EOF
chmod +x /root/tun.sh
grep -qE "^ *@restart root bash /root/tun.sh >/dev/null 2>&1" /etc/crontab || echo "@restart root bash /root/tun.sh >/dev/null 2>&1" >> /etc/crontab
green "TUN guardian functionality has been started"
fi
fi
fi
[[ $(type -P yum) ]] && yumapt='yum -y' || yumapt='apt -y'
[[ $(type -P curl) ]] || (yellow "It is detected that curl is not installed， and the upgrade installation is in progress" && $yumapt update;$yumapt install curl)
[[ $(type -P lsof) ]] || (yellow "It is detected that ISOF is not installed，and the upgrade installation is in progress" && $yumapt update;$yumapt install lsof)
[[ ! $(type -P qrencode) ]] && ($yumapt update;$yumapt install qrencode)
[[ ! $(type -P sysctl) ]] && ($yumapt update;$yumapt install procps)
[[ ! $(type -P iptables) ]] && ($yumapt update;$yumapt install iptables-persistent)
[[ ! $(type -P python3) ]] && (yellow "It is detected that python3 is not installed，and the upgrade installation is in progress" && $yumapt update;$yumapt install python3)
if [[ -z $(systemctl status netfilter-persistent 2>/dev/null | grep -w active) ]]; then
$yumapt update;$yumapt install netfilter-persistent
fi 
if [[ -z $(grep 'DiG 9' /etc/hosts) ]]; then
v4=$(curl -s4m6 ip.sb -k)
if [ -z $v4 ]; then
echo -e "nameserver 2a00:1098:2b::1\nnameserver 2a00:1098:2c::1\nnameserver 2a01:4f8:c2c:123f::1" > /etc/resolv.conf
fi
fi
systemctl stop firewalld.service >/dev/null 2>&1
systemctl disable firewalld.service >/dev/null 2>&1
setenforce 0 >/dev/null 2>&1
ufw disable >/dev/null 2>&1
iptables -P INPUT ACCEPT >/dev/null 2>&1
iptables -P FORWARD ACCEPT >/dev/null 2>&1
iptables -P OUTPUT ACCEPT >/dev/null 2>&1
iptables -t mangle -F >/dev/null 2>&1
iptables -F >/dev/null 2>&1
iptables -X >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
if [[ -n $(apachectl -v 2>/dev/null) ]]; then
systemctl stop httpd.service >/dev/null 2>&1
systemctl disable httpd.service >/dev/null 2>&1
service apache2 stop >/dev/null 2>&1
systemctl disable apache2 >/dev/null 2>&1
fi
}

inshy(){
if [[ -n $(systemctl status hysteria-server 2>/dev/null | grep -w active) && -f '/etc/hysteria/config.json' ]]; then
green "Hysteria has been installed， please execute the uninstall function first for reinstallation" && exit
fi
if [[ $release = Centos ]]; then
if [[ ${vsid} =~ 8 ]]; then
yum clean all && yum makecache
fi
yum install epel-release -y
else
$yumapt update
fi
systemctl stop hysteria-server >/dev/null 2>&1
systemctl disable hysteria-server >/dev/null 2>&1
rm -rf /usr/local/bin/hysteria /etc/hysteria /root/HY
wget -N https://gitlab.com/rwkgyg/hysteria-yg/raw/main/install_server.sh && bash install_server.sh
if [[ -f '/usr/local/bin/hysteria' ]]; then
blue "Successfully installed the hysteria kernel version：$(/usr/local/bin/hysteria -v | awk 'NR==1 {print $3}')\n"
else
red "Failed to install hysteria kernel" && rm -rf install_server.sh && exit
fi
rm -rf install_server.sh
}

inscertificate(){
green "The hysteria protocol certificate application method options are as follows:"
readp "1. www.bing.com self-signed certificate （press enter to default）\n2. acme one-click certificate application script（supports regular port 80 mode and dns api mode），certificates that have been applied for using this script will be automatically recognized\n3. Custom certificate Path（ex. root/ygkkkca）\n Whats Your Option?：" certificate
if [ -z "${certificate}" ] || [ $certificate == "1" ]; then
openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/private.key
openssl req -new -x509 -days 36500 -key /etc/hysteria/private.key -out /etc/hysteria/cert.crt -subj "/CN=www.bing.com"
ym=www.bing.com
certificatep='/etc/hysteria/private.key'
certificatec='/etc/hysteria/cert.crt'
blue "Confirmed certificate mode: www.bing.com self-signed certificate\n"
elif [ $certificate == "2" ]; then
if [[ -f /root/ygkkkca/cert.crt && -f /root/ygkkkca/private.key ]] && [[ -s /root/ygkkkca/cert.crt && -s /root/ygkkkca/private.key ]]; then
blue "After testing, this acme script has been used to apply for a certificate before"
readp "1. Directly use the root/ygkkkca directory to apply for a certificate （press Enter to default）\n2. Delete the original certificate and reapply for the acme certificate\n Whats Your Option：" certacme
if [ -z "${certacme}" ] || [ $certacme == "1" ]; then
ym=$(cat /root/ygkkkca/ca.log)
blue "Detected Domains：$ym ，directly quoted\n"
elif [ $certacme == "2" ]; then
curl https://get.acme.sh | sh
bash /root/.acme.sh/acme.sh --uninstall
rm -rf /root/ygkkkca
rm -rf ~/.acme.sh acme.sh
sed -i '/--cron/d' /etc/crontab
[[ -z $(/root/.acme.sh/acme.sh -v 2>/dev/null) ]] && green "acme.sh uninstall complete" || red "acme.sh uninstall failed"
sleep 2
wget -N https://gitlab.com/rwkgyg/acme-script/raw/main/acme.sh && bash acme.sh
ym=$(cat /root/ygkkkca/ca.log)
if [[ ! -f /root/ygkkkca/cert.crt && ! -f /root/ygkkkca/private.key ]] && [[ ! -s /root/ygkkkca/cert.crt && ! -s /root/ygkkkca/private.key ]]; then
red "Certificate request failed, script exits" && exit
fi
fi
else
wget -N https://gitlab.com/rwkgyg/acme-script/raw/main/acme.sh && bash acme.sh
ym=$(cat /root/ygkkkca/ca.log)
if [[ ! -f /root/ygkkkca/cert.crt && ! -f /root/ygkkkca/private.key ]] && [[ ! -s /root/ygkkkca/cert.crt && ! -s /root/ygkkkca/private.key ]]; then
red "Certificate request failed, script exits" && exit
fi
fi
certificatec='/root/ygkkkca/cert.crt'
certificatep='/root/ygkkkca/private.key'
elif [ $certificate == "3" ]; then
readp "Please enter the path of the placed public key file crt（/a/b/……/cert.crt）：" cerroad
blue "The path of the public key file crt：$cerroad "
readp "Please enter the path of the placed key file key（/a/b/……/private.key）：" keyroad
blue "The path of the key file key：$keyroad "
certificatec=$cerroad
certificatep=$keyroad
readp "Please enter the resolved domain name:" ym
blue "resolved domain name：$ym "
else 
red "Input error, please choose again" && inscertificate
fi
}

inspr(){
green "hysteria The transport protocol selection is as follows:"
readp "1. udp（Support range port hopping function，default）\n2. wechat-video\n3. faketcp（Only supports linux or Android clients and requires root privileges）\nplease choose：" protocol
if [ -z "${protocol}" ] || [ $protocol == "1" ];then
hysteria_protocol="udp"
elif [ $protocol == "2" ];then
hysteria_protocol="wechat-video"
elif [ $protocol == "3" ];then
hysteria_protocol="faketcp"
else 
red "Input error, please choose again" && inspr
fi
echo
blue "Confirmed Transport Protocol: ${hysteria_protocol}\n"
}

insport(){
fports(){
readp "\nAdd a starting port for a range(10000-65535，  < 65535))：" firstudpport
readp "\nAdd a port at the end of a range(10000-65535，  > 1000)：" endudpport
if [[ $firstudpport -ge $endudpport ]]; then
until [[ $firstudpport -le $endudpport ]]
do
[[ $firstudpport -ge $endudpport ]] && yellow "\nThe start port is smaller than the end port，人才！Please re-enter the start/end port" && readp "\nAdd a starting port for a range of ports(10000-65535)：" firstudpport && readp "\nAdd a port at the end of a range of ports(10000-65535，be larger than the starting port above)：" endudpport
done
fi
iptables -t nat -A PREROUTING -p udp --dport $firstudpport:$endudpport  -j DNAT --to-destination :$port
ip6tables -t nat -A PREROUTING -p udp --dport $firstudpport:$endudpport  -j DNAT --to-destination :$port
netfilter-persistent save >/dev/null 2>&1
blue "\nA range of ports that have been confirmed to be forwarded：$firstudpport to $endudpport\n"
}

iptables -t nat -F PREROUTING >/dev/null 2>&1
readp "Set hysteria to forward the main port （1-65535） （enter to skip the random port of 2000-65535）：" port
if [[ -z $port ]]; then
port=$(shuf -i 2000-65535 -n 1)
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\nport is busy，Please re-enter the port" && readp "Custom hysteria forwards the main port:" port
done
else
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\nport is busy，Please re-enter the port" && readp "Custom hysteria forwards the main port:" port
done
fi
blue "\nhas confirmed forwarding the main port：$port\n"
if [[ ${hysteria_protocol} == "udp" || $(cat /etc/hysteria/config.json 2>/dev/null | grep protocol | awk '{print $2}' | awk -F '"' '{ print $2}') == "udp" ]]; then
green "\ntested，Currently selected is udp protocol，Can choose to support range port automatic jumping function\n"
readp "1. Continue to use single port（default）\n2. use range port（Support automatic jump function）\nplease choose：" choose
if [ -z "${choose}" ] || [ $choose == "1" ]; then
echo
elif [ $choose == "2" ]; then
fports
else
red "Input error, please choose again" && insport
fi
else
green "\ntested，not currently udp protocol，Will continue to use single port\n"
fi
}

inspswd(){
readp "Set hysteria authentication password，Must be more than 6 characters（default random 6 characters）：" pswd
if [[ -z ${pswd} ]]; then
pswd=`date +%s%N |md5sum | cut -c 1-6`
else
if [[ 6 -ge ${#pswd} ]]; then
until [[ 6 -le ${#pswd} ]]
do
[[ 6 -ge ${#pswd} ]] && yellow "\nusername Must be more than 6 characters！please re enter" && readp "\nset up hysteria password：" pswd
done
fi
fi
blue "Verification password confirmed：${pswd}\n"
}

portss(){
if [[ -z $firstudpport ]]; then
clport=$port
else
clport="$port,$firstudpport-$endudpport"
fi
}

insconfig(){
green "set up in the configuration file……，wait 5 seconds"
v4=$(curl -s4m6 ip.sb -k)
[[ -z $v4 ]] && rpip=64 || rpip=46
cat <<EOF > /etc/hysteria/config.json
{
"listen": ":${port}",
"protocol": "${hysteria_protocol}",
"resolve_preference": "${rpip}",
"auth": {
"mode": "password",
"config": {
"password": "${pswd}"
}
},
"alpn": "h3",
"cert": "${certificatec}",
"key": "${certificatep}"
}
EOF

sureipadress(){
ip=$(curl -s4m6 ip.sb -k) || ip=$(curl -s6m6 ip.sb -k)
[[ -z $(echo $ip | grep ":") ]] && ymip=$ip || ymip="[$ip]" 
}

wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
sureipadress
else
systemctl stop wg-quick@wgcf >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
sureipadress
systemctl start wg-quick@wgcf >/dev/null 2>&1
systemctl restart warp-go >/dev/null 2>&1
systemctl enable warp-go >/dev/null 2>&1
systemctl start warp-go >/dev/null 2>&1
fi

if [[ $ym = www.bing.com ]]; then
Cymip=$ip;ins=true
elif [[ -n $(cat /root/ygkkkca/ca.log) ]]; then
ym=$(cat /root/ygkkkca/ca.log)
Cymip=$ym;ymip=$ym;ins=false
else
Cymip=$ym;ymip=$ym;ins=false
fi

portss
cat <<EOF > /root/HY/acl/v2rayn.json
{
"server": "${ymip}:${clport}",
"protocol": "${hysteria_protocol}",
"up_mbps": 20,
"down_mbps": 100,
"alpn": "h3",
"acl": "acl/routes.acl",
"mmdb": "acl/Country.mmdb",
"http": {
"listen": "127.0.0.1:10809",
"timeout" : 300,
"disable_udp": false
},
"socks5": {
"listen": "127.0.0.1:10808",
"timeout": 300,
"disable_udp": false
},
"auth_str": "${pswd}",
"server_name": "${ym}",
"insecure": ${ins},
"retry": 3,
"retry_interval": 3,
"fast_open": true,
"lazy_start": true,
"hop_interval": 60
}
EOF

cat <<EOF > /root/HY/acl/Cmeta-hy.yaml
  - name: "hysteria-ygkkk"
    type: hysteria
    server: ${Cymip}
    port: $port
    auth-str: ${pswd}
    alpn:
      - h3
    protocol: ${hysteria_protocol}
    up: 20
    down: 100
    sni: ${ym}
    skip-cert-verify: ${ins}
    fast-open: true
EOF
}

unins(){
systemctl stop hysteria-server.service >/dev/null 2>&1
systemctl disable hysteria-server.service >/dev/null 2>&1
rm -f /lib/systemd/system/hysteria-server.service /lib/systemd/system/hysteria-server@.service
rm -rf /usr/local/bin/hysteria /etc/hysteria /root/HY /root/install_server.sh /root/hysteria.sh /usr/bin/hy
sed -i '/systemctl restart hysteria-server/d' /etc/crontab
iptables -t nat -F PREROUTING >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
green "hysteria uninstall complete！"
}

uphysteriacore(){
if [[ -z $(systemctl status hysteria-server 2>/dev/null | grep -w active) || ! -f '/etc/hysteria/config.json' ]]; then
red "Not installed properly hysteria!" && exit
fi
wget -N https://gitlab.com/rwkgyg/hysteria-yg/raw/main/install_server.sh && bash install_server.sh
systemctl restart hysteria-server
VERSION="$(/usr/local/bin/hysteria -v | awk 'NR==1 {print $3}')"
blue "Current hysteria kernel version number：$VERSION"
rm -rf install_server.sh
}

stclre(){
if [[ ! -f '/etc/hysteria/config.json' ]]; then
red "Not installed properly hysteria!" && exit
fi
green "hysteria The service does the following"
readp "1. restart\n2. stop\n3. start\nplease choose：" action
if [[ $action == "1" ]];then
systemctl restart hysteria-server
green "hysteria server restart successfully"
hysteriastatus
white "$status\n"
elif [[ $action == "2" ]];then
systemctl stop hysteria-server
systemctl disable hysteria-server
green "hysteria server stop successfully"
hysteriastatus
white "$status\n"
elif [[ $action == "3" ]];then
systemctl enable hysteria-server
systemctl start hysteria-server
green "hysteria server enabled successfully"
hysteriastatus
white "$status\n"
else
red "error, please choose again" && stclre
fi
}

uphyyg(){
if [[ -z $(systemctl status hysteria-server 2>/dev/null | grep -w active) || ! -f '/etc/hysteria/config.json' ]]; then
red "Not installed properly hysteria!" && exit
fi
wget -N https://gitlab.com/rwkgyg/hysteria-yg/raw/main/hysteria.sh
chmod +x /root/hysteria.sh 
ln -sf /root/hysteria.sh /usr/bin/hy
green "Install script upgrade successfully" && hy
}

cfwarp(){
bash <(curl -Ls https://gitlab.com/rwkgyg/CFwarp/raw/main/CFwarp.sh)
}

acme(){
bash <(curl -Ls https://gitlab.com/rwkgyg/acme-script/raw/main/acme.sh)
}

changepr(){
if [[ -z $(systemctl status hysteria-server 2>/dev/null | grep -w active) || ! -f '/etc/hysteria/config.json' ]]; then
red "Not installed properlyhysteria!" && exit
fi
noprotocol=`cat /etc/hysteria/config.json 2>/dev/null | grep protocol | awk '{print $2}' | awk -F '"' '{ print $2}'`
echo
blue "currently in use protocol：$noprotocol"
echo
inspr
sed -i "s/$noprotocol/$hysteria_protocol/g" /etc/hysteria/config.json
sed -i "3s/$noprotocol/$hysteria_protocol/g" /root/HY/acl/v2rayn.json
sed -i "s/$noprotocol/$hysteria_protocol/g" /root/HY/URL.txt
sed -i "s/$noprotocol/$hysteria_protocol/g" /root/HY/acl/Cmeta-hy.yaml
systemctl restart hysteria-server
blue "hysteria active server of protocol by $noprotocol replace with $hysteria_protocol ，The configuration has been updated "
hysteriashare
}

changecertificate(){
if [[ -z $(systemctl status hysteria-server 2>/dev/null | grep -w active) || ! -f '/etc/hysteria/config.json' ]]; then
red "Not installed properlyhysteria!" && exit
fi
certclient(){
sureipadress(){
ip=$(curl -s4m6 ip.sb -k) || ip=$(curl -s6m6 ip.sb -k)
certificate=`cat /etc/hysteria/config.json 2>/dev/null | grep cert | awk '{print $2}' | awk -F '"' '{ print $2}'`
if [[ $certificate = '/etc/hysteria/cert.crt' ]]; then
if [[ -n $(curl -s6m6 ip.sb -k) ]]; then
oldserver=`cat /root/HY/acl/v2rayn.json 2>/dev/null | grep -w server | awk '{print $2}' | awk -F '"' '{ print $2}' | grep -o '\[.*\]' | cut -d '[' -f2|cut -d ']' -f1`
else
oldserver=`cat /root/HY/acl/v2rayn.json 2>/dev/null | grep -w server | awk '{print $2}' | awk -F '"' '{ print $2}'| cut -d ':' -f 1`
fi
else
oldserver=`cat /root/HY/acl/v2rayn.json 2>/dev/null | grep -w server | awk '{print $2}' | awk -F '"' '{ print $2}'| cut -d ':' -f 1`
fi
if [[ $certificate = '/etc/hysteria/cert.crt' ]]; then
ym=$(cat /root/ygkkkca/ca.log)
ymip=$(cat /root/ygkkkca/ca.log)
else
ym=www.bing.com
ymip=$ip
fi
}
wgcfgo
}

whcertificate(){
if [[ -n $(cat /etc/hysteria/config.json 2>/dev/null | sed -n 12p | grep -w ygkkkca) ]]; then
certificatepp='/root/ygkkkca/private.key'
certificatecc='/root/ygkkkca/cert.crt'
elif [[ -n $(cat /etc/hysteria/config.json 2>/dev/null | sed -n 12p | grep -w hysteria) ]]; then
certificatepp='/etc/hysteria/private.key'
certificatecc='/etc/hysteria/cert.crt'
else
readp "请enter原The path of the public key file crt（/a/b/……/cert.crt）：" cerroad
blue "The path of the public key file crt：$cerroad "
readp "请enter原The path of the key file key（/a/b/……/private.key）：" keyroad
blue "The path of the key file key：$keyroad "
certificatepp=$keyroad
certificatecc=$cerroad
fi
}

servername=`cat /root/HY/acl/v2rayn.json 2>/dev/null | grep -w server_name | awk '{print $2}' | awk -F '"' '{ print $2}'`
certificate=`cat /etc/hysteria/config.json 2>/dev/null | grep cert | awk '{print $2}' | awk -F '"' '{ print $2}'`
green "hysteria protocol Certificate modifying:"
readp "1. www.bing.comself-signed certificate（default）\n2. acme一key request certificate script（Support regular port 80 mode and dns api mode），If you have used this script to apply for the certificate, it will be automatically recognized\n3. custom certificate path（/root/ygkkkca）\nplease choose：" certificate
if [ -z "${certificate}" ] || [ $certificate == "1" ]; then
whcertificate
if [[ -f /etc/hysteria/cert.crt && -f /etc/hysteria/private.key ]]; then
ym=www.bing.com
blue "tested，Has applied for self-signed certificate，directly quoted\n"
else
openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/private.key
openssl req -new -x509 -days 36500 -key /etc/hysteria/private.key -out /etc/hysteria/cert.crt -subj "/CN=www.bing.com"
ym=www.bing.com
fi
certificatep='/etc/hysteria/private.key'
certificatec='/etc/hysteria/cert.crt'
certclient
sed -i '21s/false/true/g' /root/HY/acl/v2rayn.json
sed -i 's/false/true/g' /root/HY/URL.txt
sed -i 's/false/true/g' /root/HY/acl/Cmeta-hy.yaml
blue "Confirmed certificate mode: www.bing.comself-signed certificate\n"
elif [ $certificate == "2" ]; then
whcertificate
if [[ -f /root/ygkkkca/cert.crt && -f /root/ygkkkca/private.key ]] && [[ -s /root/ygkkkca/cert.crt && -s /root/ygkkkca/private.key ]]; then
blue "tested，Before A certificate has been applied for using this acme script"
readp "1. Directly use the root/ygkkkca directory to apply for a certificate（default）\n2. Delete the original of certificate，re apply for acme certificate\nplease choose：" certacme
if [ -z "${certacme}" ] || [ $certacme == "1" ]; then
ym=$(cat /root/ygkkkca/ca.log)
blue "Detected Domains：$ym ，directly quoted\n"
elif [ $certacme == "2" ]; then
curl https://get.acme.sh | sh
bash /root/.acme.sh/acme.sh --uninstall
rm -rf /root/ygkkkca
rm -rf ~/.acme.sh acme.sh
sed -i '/--cron/d' /etc/crontab
[[ -z $(/root/.acme.sh/acme.sh -v 2>/dev/null) ]] && green "acme.sh uninstall complete" || red "acme.sh uninstall failed"
sleep 2
wget -N https://gitlab.com/rwkgyg/acme-script/raw/main/acme.sh && bash acme.sh
ym=$(cat /root/ygkkkca/ca.log)
if [[ ! -f /root/ygkkkca/cert.crt && ! -f /root/ygkkkca/private.key ]] && [[ ! -s /root/ygkkkca/cert.crt && ! -s /root/ygkkkca/private.key ]]; then
red "Certificate request failed, script exits" && exit
fi
fi
else
wget -N https://gitlab.com/rwkgyg/acme-script/raw/main/acme.sh && bash acme.sh
ym=$(cat /root/ygkkkca/ca.log)
if [[ ! -f /root/ygkkkca/cert.crt && ! -f /root/ygkkkca/private.key ]] && [[ ! -s /root/ygkkkca/cert.crt && ! -s /root/ygkkkca/private.key ]]; then
red "Certificate request failed, script exits" && exit
fi
fi
certificatec='/root/ygkkkca/cert.crt'
certificatep='/root/ygkkkca/private.key'
certclient
sed -i '21s/true/false/g' /root/HY/acl/v2rayn.json
sed -i 's/true/false/g' /root/HY/URL.txt
sed -i 's/true/false/g' /root/HY/acl/Cmeta-hy.yaml
elif [ $certificate == "3" ]; then
whcertificate
readp "Please enter the path of the placed public key file crt（/a/b/……/cert.crt）：" cerroad
blue "The path of the public key file crt：$cerroad "
readp "Please enter the path of the placed key file key（/a/b/……/private.key）：" keyroad
blue "The path of the key file key：$keyroad "
certificatec=$cerroad
certificatep=$keyroad
readp "Please enter the resolved domain name:" ym
blue "resolved domain name：$ym "
certclient
sed -i '21s/true/false/g' /root/HY/acl/v2rayn.json
sed -i 's/true/false/g' /root/HY/URL.txt
sed -i 's/true/false/g' /root/HY/acl/Cmeta-hy.yaml
else 
red "Input error, please choose again" && changecertificate
fi

sureipadress(){
if [[ $certificate = '/etc/hysteria/cert.crt' && -n $(curl -s6m6 ip.sb -k) ]]; then
sed -i "2s/\[$oldserver\]/${ymip}/g" /root/HY/acl/v2rayn.json
sed -i "s/\[$oldserver\]/${ymip}/g" /root/HY/URL.txt
sed -i "3s/$oldserver/${ymip}/g" /root/HY/acl/Cmeta-hy.yaml
elif [[ $certificate = '/root/ygkkkca/cert.crt' && -n $(curl -s6m6 ip.sb -k) ]]; then
sed -i "2s/$oldserver/\[${ymip}\]/g" /root/HY/acl/v2rayn.json
sed -i "s/$oldserver/\[${ymip}\]/" /root/HY/URL.txt
sed -i "3s/$oldserver/${ymip}/g" /root/HY/acl/Cmeta-hy.yaml
elif [[ $certificate = '/root/ygkkkca/cert.crt' && -z $(curl -s6m6 ip.sb -k) ]]; then
sed -i "2s/$oldserver/${ymip}/g" /root/HY/acl/v2rayn.json
sed -i "s/$oldserver/${ymip}/" /root/HY/URL.txt
sed -i "3s/$oldserver/${ymip}/g" /root/HY/acl/Cmeta-hy.yaml
elif [[ $certificate = '/etc/hysteria/cert.crt' && -z $(curl -s6m6 ip.sb -k) ]]; then
sed -i "2s/$oldserver/${ymip}/g" /root/HY/acl/v2rayn.json
sed -i "s/$oldserver/${ymip}/g" /root/HY/URL.txt
sed -i "3s/$oldserver/${ymip}/g" /root/HY/acl/Cmeta-hy.yaml
fi
}
wgcfgo
sed -i "s/$servername/$ym/g" /root/HY/acl/v2rayn.json
sed -i "s/$servername/$ym/g" /root/HY/URL.txt
sed -i "11s/$servername/$ym/g" /root/HY/acl/Cmeta-hy.yaml
sed -i "s!$certificatepp!$certificatep!g" /etc/hysteria/config.json
sed -i "s!$certificatecc!$certificatec!g" /etc/hysteria/config.json
systemctl restart hysteria-server
hysteriashare
}

changeip(){
if [[ -z $(systemctl status hysteria-server 2>/dev/null | grep -w active) || ! -f '/etc/hysteria/config.json' ]]; then
red "Not installed properlyhysteria!" && exit
fi
ipv6=$(curl -s6m6 ip.sb -k)
ipv4=$(curl -s4m6 ip.sb -k)
chip(){
rpip=`cat /etc/hysteria/config.json 2>/dev/null | grep resolve_preference | awk '{print $2}' | awk -F '"' '{ print $2}'`
sed -i "4s/$rpip/$rrpip/g" /etc/hysteria/config.json
systemctl restart hysteria-server
}
green "Switch IPV4/IPV6 outbound priority selection as follows:"
readp "1. IPV4 priority\n2. IPV6 priority\n3. pure IPV4\n4. pure IPV6\nplease choose：" choose
if [[ $choose == "1" && -n $ipv4 ]]; then
rrpip="46" && chip && v4v6="IPV4 priority：$ipv4"
elif [[ $choose == "2" && -n $ipv6 ]]; then
rrpip="64" && chip && v4v6="IPV6 priority：$ipv6"
elif [[ $choose == "3" && -n $ipv4 ]]; then
rrpip="4" && chip && v4v6="pure IPV4：$ipv4"
elif [[ $choose == "4" && -n $ipv6 ]]; then
rrpip="6" && chip && v4v6="pure IPV6：$ipv6"
else 
red "Your choice does not currently exist of IPV4/IPV6 address，or enter mistake" && changeip
fi
blue "Make sure it is currently replaced of IP priority：${v4v6}\n"
}

changepswd(){
if [[ -z $(systemctl status hysteria-server 2>/dev/null | grep -w active) || ! -f '/etc/hysteria/config.json' ]]; then
red "Not installed properlyhysteria!" && exit
fi
oldpswd=`cat /etc/hysteria/config.json 2>/dev/null | grep -w password | awk '{print $2}' | awk -F '"' '{ print $2}' | sed -n 2p`
echo
blue "currently in use verify password：$oldpswd"
echo
inspswd
sed -i "8s/$oldpswd/$pswd/g" /etc/hysteria/config.json
sed -i "19s/$oldpswd/$pswd/g" /root/HY/acl/v2rayn.json
sed -i "s/$oldpswd/$pswd/g" /root/HY/URL.txt
sed -i "5s/$oldpswd/$pswd/g" /root/HY/acl/Cmeta-hy.yaml
systemctl restart hysteria-server
blue "hysteria active server of verify password by $oldpswd replace with $pswd ，The configuration has been updated "
hysteriashare
}

changeport(){
if [[ -z $(systemctl status hysteria-server 2>/dev/null | grep -w active) || ! -f '/etc/hysteria/config.json' ]]; then
red "Not installed properlyhysteria!" && exit
fi
oldport=`cat /root/HY/acl/v2rayn.json 2>/dev/null | grep -w server | awk '{print $2}' | awk -F '"' '{ print $2}'| awk -F ':' '{ print $NF}'`
servport=`cat /etc/hysteria/config.json 2>/dev/null  | awk '{print $2}' | sed -n 2p | tr -d ',:"'`
echo
blue "Currently using of forwarded port：$oldport All have been reset, please set up quickly"
echo
insport
portss
sed -i "2s/$servport/$port/g" /etc/hysteria/config.json
sed -i "2s/$oldport/$clport/g" /root/HY/acl/v2rayn.json
sed -i "s/$servport/$port/g" /root/HY/URL.txt
sed -i "4s/$servport/$port/g" /root/HY/acl/Cmeta-hy.yaml
systemctl restart hysteria-server
blue "hysteria active server of forward primary port by $servport replace with $port ，The configuration has been updated "
hysteriashare
}

changeserv(){
green "hysteria The configuration change options are as follows:"
readp "1. modify IP outbound priority（mode 4）\n2. modify transmission protocol（udp / wechat-video / faketcp）\n3. modify certificate type（self-signed certificate / ACME Certificate / custom path Certificate）\n4. Modify password\n5. Change a single port or enable range port hopping (will reset all ports)\n6. back\nplease choose：" choose
if [ $choose == "1" ];then
changeip
elif [ $choose == "2" ];then
changepr
elif [ $choose == "3" ];then
changecertificate
elif [ $choose == "4" ];then
changepswd
elif [ $choose == "5" ];then
changeport
elif [ $choose == "6" ];then
hy
else 
red "please re choose" && changeserv
fi
}

inshysteria(){
inshy ; inscertificate
mkdir -p /root/HY/acl
inspr ; insport ; inspswd
if [[ ! $vi =~ lxc|openvz ]]; then
sysctl -w net.core.rmem_max=8000000
sysctl -p
fi
insconfig
systemctl enable hysteria-server >/dev/null 2>&1
systemctl start hysteria-server >/dev/null 2>&1
systemctl restart hysteria-server >/dev/null 2>&1
if [[ -n $(systemctl status hysteria-server 2>/dev/null | grep -w active) && -f '/etc/hysteria/config.json' ]]; then
sed -i '/systemctl restart hysteria-server/d' /etc/crontab
echo "0 4 * * * systemctl restart hysteria-server >/dev/null 2>&1" >> /etc/crontab
chmod +x /root/hysteria.sh 
ln -sf /root/hysteria.sh /usr/bin/hy
wget -P /root/HY https://gitlab.com/rwkgyg/hysteria-yg/raw/main/GetRoutes.py 
python3 /root/HY/GetRoutes.py
mv -f Country.mmdb routes.acl /root/HY/acl
green "The acl routing rule file can also be downloaded from this link https://github.com/yonggekkk/Hysteria-yg/releases/download/main/acl.zip"
sleep 3
hysteriastatus
white "$status\n"
sureipadress(){
certificate=`cat /etc/hysteria/config.json 2>/dev/null | grep cert | awk '{print $2}' | awk -F '"' '{ print $2}'`
if [[ $certificate = '/etc/hysteria/cert.crt' ]]; then
ip=$(curl -s4m6 ip.sb -k) || ip=$(curl -s6m6 ip.sb -k)
[[ -z $(echo $ip | grep ":") ]] && ymip=$ip || ymip="[$ip]"
else
ymip=$(cat /root/ygkkkca/ca.log)
fi
}
wgcfgo
url="hysteria://${ymip}:${port}?protocol=${hysteria_protocol}&auth=${pswd}&peer=${ym}&insecure=${ins}&upmbps=10&downmbps=50&alpn=h3#hysteria-ygkkk"
echo ${url} > /root/HY/URL.txt
red "======================================================================================"
green "The installation of hysteria active server is complete, and the generated script of shortcut is HY" && sleep 3
blue "\nshare link save to /root/HY/URL.txt" && sleep 3
yellow "${url}\n"
green "The QR code sharing link is as follows (SagerNet / Matsuri / shadowrocket)" && sleep 3
qrencode -o - -t ANSIUTF8 "$(cat /root/HY/URL.txt)"
blue "\nv2rayn client configuration file v2rayn.json, Clash-Meta client configuration file Cmeta-hy.yaml /root/HY/acl\n" && sleep 3
blue "The content of the v2rayn client configuration file v2rayn.json is as follows, which can be copied directly" && sleep 3
yellow "$(cat /root/HY/acl/v2rayn.json)\n"
blue "CThe content of the lash-Meta client configuration file Cmeta-hy.yaml is as follows, which can be copied directly" && sleep 3
yellow "$(cat /root/HY/acl/Cmeta-hy.yaml)"
else
red "hysteria server installation failed, please run systemctl status hysteria-server to check the server log" && exit
fi
}

hysteriastatus(){
wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
[[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]] && wgcf=$(green "Not Enabled") || wgcf=$(green "Enable")
if [[ -n $(systemctl status hysteria-server 2>/dev/null | grep -w active) && -f '/etc/hysteria/config.json' ]]; then
noprotocol=`cat /etc/hysteria/config.json 2>/dev/null | grep protocol | awk '{print $2}' | awk -F '"' '{ print $2}'`
rpip=`cat /etc/hysteria/config.json 2>/dev/null | grep resolve_preference | awk '{print $2}' | awk -F '"' '{ print $2}'`
v4=$(curl -s4m6 ip.sb -k)
v6=$(curl -s6m6 ip.sb -k)
[[ -z $v4 ]] && showv4='IPV4 address is lost, please modify to IPV6 or reinstall hysteria' || showv4=$v4
[[ -z $v6 ]] && showv6='IPV6 address is lost, please modify to IPV4 or reinstall hysteria' || showv6=$v6
if [[ $rpip = 64 ]]; then
v4v6="IPV6 priority：$showv6"
elif [[ $rpip = 46 ]]; then
v4v6="IPV4 priority：$showv4"
elif [[ $rpip = 4 ]]; then
v4v6="pure IPV4：$showv4"
elif [[ $rpip = 6 ]]; then
v4v6="pure IPV6：$showv6"
fi
oldport=`cat /root/HY/acl/v2rayn.json 2>/dev/null | grep -w server | awk '{print $2}' | awk -F '"' '{ print $2}'| awk -F ':' '{ print $NF}'`
status=$(white "hysteria status：\c";green "Running";white "hysteriaprotocol：\c";green "$noprotocol";white " priority outboundIP：  \c";green "$v4v6   \c";white "active port：\c";green "$oldport";white "WARP status：    \c";eval echo \$wgcf)
elif [[ -z $(systemctl status hysteria-server 2>/dev/null | grep -w active) && -f '/etc/hysteria/config.json' ]]; then
status=$(white "hysteria status：\c";yellow "Not started, you can try , start or restart, uninstall and reinstall hysteria";white "WARP status：    \c";eval echo \$wgcf)
else
status=$(white "hysteria status：\c";red "Not Installed";white "WARP status：    \c";eval echo \$wgcf)
fi
}

hysteriashare(){
if [[ -z $(systemctl status hysteria-server 2>/dev/null | grep -w active) || ! -f '/etc/hysteria/config.json' ]]; then
red "Not installed properlyhysteria!" && exit
fi
red "======================================================================================"
oldport=`cat /root/HY/acl/v2rayn.json 2>/dev/null | grep -w server | awk '{print $2}' | awk -F '"' '{ print $2}'| awk -F ':' '{ print $NF}'`
green "\nThe current hysteria active is using the of port:" && sleep 2
blue "$oldport\n"
green "The current hysteria node sharing link is as follows, save to /root/HY/URL.txt" && sleep 2
yellow "$(cat /root/HY/URL.txt)\n"
green "The current hysteria node QR code sharing link is as follows (SagerNet / Matsuri / Little Rocket)" && sleep 2
qrencode -o - -t ANSIUTF8 "$(cat /root/HY/URL.txt)"
green "\nThe content of the current v2rayn client configuration file v2rayn.json is as follows, save to /root/HY/acl/v2rayn.json" && sleep 2
yellow "$(cat /root/HY/acl/v2rayn.json)\n"
green "The content of the current Clash-Meta client configuration file Cmeta-hy.yaml is as follows, save it to /root/HY/acl/Cmeta-hy.yaml" && sleep 2
yellow "$(cat /root/HY/acl/Cmeta-hy.yaml)"
}

hylog(){
echo
red "To exit Hysteria log view, press Ctrl+c"
echo
journalctl -u hysteria-server --output cat -f
}

start_menu(){
hysteriastatus
clear
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo ""
green "                                YONGKKK HYSTERIA"
echo ""
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "after the hysteria-yg script is successfully installed, enter the script again with a shortcut of hy"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green " 1. Install hysteria (required)"
green " 2. Uninstall hysteria"
white "------------------------------------------------ ----------------------------------"
green " 3. Change configuration (IP priority level, transmission protocol, certificate type, verify password, range port)"
green " 4. stop, open, restarthysteria"
green " 5. Update hysteria-yg installation script"
green " 6. Update hysteria kernel"
white "------------------------------------------------ ----------------------------------"
green " 7. Display the current hysteria sharing link, QR code, V2rayN configuration file, Clash-meta configuration file"
green " 8. ACME certificate management menu"
green " 9. Install WARP (optional)"
green "10. View hysteria operation log"
green " 0. exit script"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
if [[ -n $(systemctl status hysteria-server 2>/dev/null | grep -w active) && -f '/etc/hysteria/config.json' ]]; then
if [ "${hyygV}" = "${remoteV}" ]; then
echo -e "Current hysteria-yg install script version number：${bblue}${hyygV}${plain} ，Already the latest version\n"
else
echo -e "Current hysteria-yg install script version number：${bblue}${hyygV}${plain}"
echo -e "Check to latest hysteria-yg installation script version number：${yellow}${remoteV}${plain} ，可 choose5 to update\n"
fi
loVERSION="$(/usr/local/bin/hysteria -v | awk 'NR==1 {print $3}')"
hyVERSION="v$(curl -s https://data.jsdelivr.com/v1/package/gh/apernet/Hysteria | sed -n 4p | tr -d ',"' | awk '{print $1}')"
if [ "${loVERSION}" = "${hyVERSION}" ]; then
echo -e "Current hysteria installed kernel version number：${bblue}${loVERSION}${plain} ，Already the latest version"
else
echo -e "Current hysteria installed kernel version number：${bblue}${loVERSION}${plain}"
echo -e "Check to latest hysteria kernel version number：${yellow}${hyVERSION}${plain} ，You can choose6 to update"
fi
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
white "VPS system information is as follows:"
white "Operating system: $(blue "$op")" && white "Kernel version: $(blue "$version")" && white "CPU architecture: $(blue "$cpu")" && white "Virtualization type : $(blue "$vi")"
white "$status"
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo -e "              ${yellow}Translate By${plain} ${green} OPIran${plain}"
echo -e "             ${yellow}TG-Group${plain} ${green} @OPIranCluB${plain}"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

readp "Please enter the number:" Input
case "$Input" in     
 1 ) inshysteria;;
 2 ) unins;;
 3 ) changeserv;;
 4 ) stclre;;
 5 ) uphyyg;; 
 6 ) uphysteriacore;;
 7 ) hysteriashare;;
 8 ) acme;;
 9 ) cfwarp;;
10 ) hylog;;
 * ) exit 
esac
}
if [ $# == 0 ]; then
start
start_menu
fi
