#!/bin/sh
#2019/08/30 by bkye
adbyby_enable=`nvram get adbyby_enable`
adbyby_ip_x=`nvram get adbyby_ip_x`
adbyby_rules_x=`nvram get adbyby_rules_x`
adbyby_set=`nvram get adbyby_set`
http_username=`nvram get http_username`
adbyby_update=`nvram get adbyby_update`
adbyby_update_hour=`nvram get adbyby_update_hour`
adbyby_update_min=`nvram get adbyby_update_min`
nvram set adbyby_adb=0
ipt_n="iptables -t nat"
#adbyby_dir="/tmp/adbyby"
PROG_PATH="/tmp/adbyby"
DATA_PATH="$PROG_PATH/data"
WAN_FILE="/etc/storage/dnsmasq-adbyby.d/03-adbyby-ipset.conf"
wan_mode=`nvram get adbyby_set`
#abp_mode=`nvram get adbyby_adb_update`
nvram set adbybyip_mac_x_0=""
nvram set adbybyip_ip_x_0=""
nvram set adbybyip_name_x_0=""
nvram set adbybyip_ip_road_x_0=""
nvram set adbybyrules_x_0=""
nvram set adbybyrules_road_x_0=""
adbyby_start()
{
	addscripts
	if [ ! -f "$PROG_PATH/adbyby" ]; then
	logger -t "adbyby" "adbyby程序文件不存在，正在解压..."
	tar -xzvf "/etc_ro/adbyby.tar.gz" -C "/tmp"
	logger -t "adbyby" "成功解压至：$PROG_PATH"
	fi
	#if [ $abp_mode -eq 1 ]; then
	#/tmp/adbyby/adblock.sh &
	#fi
	#/tmp/adbyby/adupdate.sh &
	add_rules
	$PROG_PATH/adbyby &>/dev/null &
	add_dns
	iptables-save | grep ADBYBY >/dev/null || \
	add_rule
	hosts_ads
	/sbin/restart_dhcpd
	add_cron
	logger -t "adbyby" "Adbyby启动完成。"
}

adbyby_close()
{
	del_rule
	del_cron
	del_dns
	killall -q adbyby
	if [ $mem_mode -eq 1 ]; then
	echo "stop mem mode"
	fi
	kill -9 $(ps | grep admem.sh | grep -v grep | awk '{print $1}') >/dev/null 2>&1
	/sbin/restart_dhcpd
	logger -t "adbyby" "Adbyby已关闭。"

}

add_rules()
{
	logger -t "adbyby" "正在检查规则是否需要更新!"
	rm -f /tmp/adbyby/data/*.bak

	touch /tmp/local-md5.json && md5sum /tmp/adbyby/data/lazy.txt /tmp/adbyby/data/video.txt > /tmp/local-md5.json
	touch /tmp/md5.json && curl -k -s -o /tmp/md5.json --connect-timeout 5 --retry 3 https://adbyby.coding.net/p/xwhyc-rules/d/xwhyc-rules/git/raw/master/md5.json

	lazy_local=$(grep 'lazy' /tmp/local-md5.json | awk -F' ' '{print $1}')
	video_local=$(grep 'video' /tmp/local-md5.json | awk -F' ' '{print $1}')
	lazy_online=$(sed  's/":"/\n/g' /tmp/md5.json  |  sed  's/","/\n/g' | sed -n '2p')
	video_online=$(sed  's/":"/\n/g' /tmp/md5.json  |  sed  's/","/\n/g' | sed -n '4p')

	if [ "$lazy_online"x != "$lazy_local"x -o "$video_online"x != "$video_local"x ]; then
	echo "MD5 not match! Need update!"
	logger -t "adbyby" "发现更新的规则,下载规则！"
	touch /tmp/lazy.txt && curl -k -s -o /tmp/lazy.txt --connect-timeout 5 --retry 3 https://raw.githubusercontent.com/luoluodaduan/AdbybyRules/master/lazy.txt
	touch /tmp/video.txt && curl -k -s -o /tmp/video.txt --connect-timeout 5 --retry 3 https://raw.githubusercontent.com/luoluodaduan/AdbybyRules/master/video.txt
	touch /tmp/local-md5.json && md5sum /tmp/lazy.txt /tmp/video.txt > /tmp/local-md5.json
	lazy_local=$(grep 'lazy' /tmp/local-md5.json | awk -F' ' '{print $1}')
	video_local=$(grep 'video' /tmp/local-md5.json | awk -F' ' '{print $1}')
	if [ "$lazy_online"x == "$lazy_local"x -a "$video_online"x == "$video_local"x ]; then
	echo "New rules MD5 match!"
	mv /tmp/lazy.txt /tmp/adbyby/data/lazy.txt
	mv /tmp/video.txt /tmp/adbyby/data/video.txt
	echo $(date +"%Y-%m-%d %H:%M:%S") > /tmp/adbyby.updated
	fi
	else
	echo "MD5 match! No need to update!"
	logger -t "adbyby" "没有更新的规则,本次无需更新！"
	fi

	rm -f /tmp/lazy.txt /tmp/video.txt /tmp/local-md5.json /tmp/md5.json
	logger -t "adbyby" "Adbyby规则更新完成"
	nvram set adbyby_ltime=`head -1 /tmp/adbyby/data/lazy.txt | awk -F' ' '{print $3,$4}'`
	nvram set adbyby_vtime=`head -1 /tmp/adbyby/data/video.txt | awk -F' ' '{print $3,$4}'`
	#nvram set adbyby_rules=`grep -v '^!' /tmp/adbyby/data/rules.txt | wc -l`

	#nvram set adbyby_utime=`cat /tmp/adbyby.updated 2>/dev/null`
	grep -v '^!' /etc/storage/adbyby_rules.sh | grep -v "^$" > $PROG_PATH/rules.txt
	grep -v '^!' /etc/storage/adbyby_blockip.sh | grep -v "^$" > $PROG_PATH/blockip.conf
	grep -v '^!' /etc/storage/adbyby_adblack.sh | grep -v "^$" > $PROG_PATH/adblack.conf
	grep -v '^!' /etc/storage/adbyby_adesc.sh | grep -v "^$" > $PROG_PATH/adesc.conf
	grep -v '^!' /etc/storage/adbyby_adhost.sh | grep -v "^$" > $PROG_PATH/adhost.conf
	logger -t "adbyby" "正在处理规则..."
	rm -f $DATA_PATH/user.bin
	rm -f $DATA_PATH/user.txt
	rulesnum=`nvram get adbybyrules_staticnum_x`
	if [ $adbyby_rules_x -eq 1 ]; then
	for i in $(seq 1 $rulesnum)
	do
		j=`expr $i - 1`
		rules_address=`nvram get adbybyrules_x$j`
		rules_road=`nvram get adbybyrules_road_x$j`
		if [ $rules_road -ne 0 ]; then
			logger -t "adbyby" "正在下载和合并第三方规则"
			curl -k -s -o /tmp/adbyby/user2.txt --connect-timeout 5 --retry 3 $rules_address
			grep -v '^!' /tmp/adbyby/user2.txt | grep -E '^(@@\||\||[[:alnum:]])' | sort -u | grep -v "^$" >> $DATA_PATH/user3adblocks.txt
			rm -f /tmp/adbyby/user2.txt
		fi
	done
	grep -v '^!' $DATA_PATH/user3adblocks.txt | grep -v "^$" >> $DATA_PATH/user.txt
	rm -f $DATA_PATH/user3adblocks.txt
	fi
	grep -v ^! $PROG_PATH/rules.txt >> $DATA_PATH/user.txt
	nvram set adbyby_user=`cat /tmp/adbyby/data/user.txt | wc -l`
}

add_cron()
{
	if [ $adbyby_update -eq 0 ]; then
	sed -i '/adbyby/d' /etc/storage/cron/crontabs/$http_username
	cat >> /etc/storage/cron/crontabs/$http_username << EOF
$adbyby_update_min $adbyby_update_hour * * * /bin/sh /usr/bin/adbyby.sh G >/dev/null 2>&1
EOF
	logger -t "adbyby" "设置每天$adbyby_update_hour时$adbyby_update_min分，自动更新规则！"
	fi
if [ $adbyby_update -eq 1 ]; then

	sed -i '/adbyby/d' /etc/storage/cron/crontabs/$http_username
	cat >> /etc/storage/cron/crontabs/$http_username << EOF
*/$adbyby_update_min */$adbyby_update_hour * * * /bin/sh /usr/bin/adbyby.sh G >/dev/null 2>&1
EOF
	logger -t "adbyby" "设置每隔$adbyby_update_hour时$adbyby_update_min分，自动更新规则！"
	fi
	if [ $adbyby_update -eq 2 ]; then
	sed -i '/adbyby/d' /etc/storage/cron/crontabs/$http_username
	fi
}

del_cron()
{
	sed -i '/adbyby/d' /etc/storage/cron/crontabs/$http_username
}

ip_rule()
{

	ipset -N adbyby_esc hash:ip
	$ipt_n -A ADBYBY -m set --match-set adbyby_esc dst -j RETURN
	num=`nvram get adbybyip_staticnum_x`
	if [ $adbyby_ip_x -eq 1 ]; then
	if [ $num -ne 0 ]; then
	logger -t "adbyby" "设置内网IP过滤控制"
	for i in $(seq 1 $num)
	do
		j=`expr $i - 1`
		ip=`nvram get adbybyip_ip_x$j`
		mode=`nvram get adbybyip_ip_road_x$j`
		case $mode in
		0)
			$ipt_n -A ADBYBY -s $ip -j RETURN
			logger -t "adbyby" "忽略$ip走AD过滤。"
			;;
		1)
			$ipt_n -A ADBYBY -s $ip -p tcp -j REDIRECT --to-ports 8118
			$ipt_n -A ADBYBY -s $ip -j RETURN
			logger -t "adbyby" "设置$ip走全局过滤。"
			;;
		2)
			ipset -N adbyby_wan hash:ip
			$ipt_n -A ADBYBY -m set --match-set adbyby_wan dst -s $ip -p tcp -j REDIRECT --to-ports 8118
			awk '!/^$/&&!/^#/{printf("ipset=/%s/'"adbyby_wan"'\n",$0)}' $PROG_PATH/adhost.conf > $WAN_FILE
			logger -t "adbyby" "设置$ip走Plus+过滤。"
			;;
		esac
	done
	fi
	fi

	case $wan_mode in
		0)	$ipt_n -A ADBYBY -p tcp -j REDIRECT --to-ports 8118
			;;
		1)
			ipset -N adbyby_wan hash:ip
			$ipt_n -A ADBYBY -m set --match-set adbyby_wan dst -p tcp -j REDIRECT --to-ports 8118
			;;
		2)
			$ipt_n -A ADBYBY -d 0.0.0.0/24 -j RETURN
			;;
	esac

	echo "create blockip hash:net family inet hashsize 1024 maxelem 65536" > /tmp/blockip.ipset
	awk '!/^$/&&!/^#/{printf("add blockip %s'" "'\n",$0)}' $PROG_PATH/blockip.conf >> /tmp/blockip.ipset
	ipset -! restore < /tmp/blockip.ipset 2>/dev/null
	iptables -I FORWARD -m set --match-set blockip dst -j DROP
	iptables -I OUTPUT -m set --match-set blockip dst -j DROP
}

add_dns()
{
	mkdir -p /etc/storage/dnsmasq-adbyby.d
	mkdir -p /tmp/dnsmasq.d
	anti_ad
	block_ios=`nvram get block_ios`
	block_douyin=`nvram get block_douyin`
	awk '!/^$/&&!/^#/{printf("ipset=/%s/'"adbyby_esc"'\n",$0)}' $PROG_PATH/adesc.conf > /etc/storage/dnsmasq-adbyby.d/06-dnsmasq.esc
	awk '!/^$/&&!/^#/{printf("address=/%s/'"0.0.0.0"'\n",$0)}' $PROG_PATH/adblack.conf > /etc/storage/dnsmasq-adbyby.d/07-dnsmasq.black
	[ $block_ios -eq 1 ] && echo 'address=/mesu.apple.com/0.0.0.0' >> /etc/storage/dnsmasq-adbyby.d/07-dnsmasq.black
	if [ $block_douyin -eq 1 ]; then
  cat <<-EOF >/etc/storage/dnsmasq-adbyby.d/08-dnsmasq.douyin
address=/api.amemv.com/0.0.0.0
address=/.snssdk.com/0.0.0.0
address=/.douyin.com/0.0.0.0
		EOF
	fi
	sed -i '/dnsmasq-adbyby/d' /etc/storage/dnsmasq/dnsmasq.conf
	cat >> /etc/storage/dnsmasq/dnsmasq.conf << EOF
conf-dir=/etc/storage/dnsmasq-adbyby.d
EOF
	if [ $wan_mode -eq 1 ]; then
	awk '!/^$/&&!/^#/{printf("ipset=/%s/'"adbyby_wan"'\n",$0)}' $PROG_PATH/adhost.conf > $WAN_FILE
	fi
	if ls /etc/storage/dnsmasq-adbyby.d/* >/dev/null 2>&1; then
	mkdir -p /tmp/dnsmasq.d
	#if [ $abp_mode -eq 1 ]; then
	#cp $PROG_PATH/dnsmasq.adblock /etc/storage/dnsmasq-adbyby.d/04-dnsmasq.adblock
	#sed -i '/youku.com/d' $PROG_PATH/dnsmasq.ads
	#cp $PROG_PATH/dnsmasq.ads /etc/storage/dnsmasq-adbyby.d/05-dnsmasq.ads
	#fi
	fi
	#sed -i '/mesu.apple.com/d' /etc/dnsmasq.conf && [ $block_ios -eq 1 ] && echo 'address=/mesu.apple.com/0.0.0.0' >> /etc/dnsmasq.conf
	#处理hosts文件
}

del_dns()
{
	sed -i '/dnsmasq-adbyby/d' /etc/storage/dnsmasq/dnsmasq.conf
	#sed -i '/tvhosts/d' /etc/storage/dnsmasq/dnsmasq.conf
	sed -i '/hosts/d' /etc/storage/dnsmasq/dnsmasq.conf
	rm -f /tmp/dnsmasq.d/dnsmasq-adbyby.conf
	rm -f /etc/storage/dnsmasq-adbyby.d/*
	rm -f /tmp/adbyby_host.conf
}

add_rule()
{
	$ipt_n -N ADBYBY
	$ipt_n -A ADBYBY -d 0.0.0.0/8 -j RETURN
	$ipt_n -A ADBYBY -d 10.0.0.0/8 -j RETURN
	$ipt_n -A ADBYBY -d 127.0.0.0/8 -j RETURN
	$ipt_n -A ADBYBY -d 169.254.0.0/16 -j RETURN
	$ipt_n -A ADBYBY -d 172.16.0.0/12 -j RETURN
	$ipt_n -A ADBYBY -d 192.168.0.0/16 -j RETURN
	$ipt_n -A ADBYBY -d 224.0.0.0/4 -j RETURN
	$ipt_n -A ADBYBY -d 240.0.0.0/4 -j RETURN
	ip_rule
	logger -t "adbyby" "添加8118透明代理端口。"
	$ipt_n -I PREROUTING -p tcp --dport 80 -j ADBYBY
	iptables-save | grep -E "ADBYBY|^\*|^COMMIT" | sed -e "s/^-A \(OUTPUT\|PREROUTING\)/-I \1 1/" > /tmp/adbyby.save
	if [ -f "/tmp/adbyby.save" ]; then
	logger -t "adbyby" "保存adbyby防火墙规则成功！"
	else
	logger -t "adbyby" "保存adbyby防火墙规则失败！可能会造成重启后过滤广告失效，需要手动关闭再打开ADBYBY！"
	fi
}

del_rule()
{
	$ipt_n -D PREROUTING -p tcp --dport 80 -j ADBYBY 2>/dev/null
	$ipt_n -F ADBYBY 2>/dev/null
	$ipt_n -X ADBYBY 2>/dev/null
	iptables -D FORWARD -m set --match-set blockip dst -j DROP 2>/dev/null
	iptables -D OUTPUT -m set --match-set blockip dst -j DROP 2>/dev/null
	ipset -F adbyby_esc 2>/dev/null
	ipset -X adbyby_esc 2>/dev/null
	ipset -F adbyby_wan 2>/dev/null
	ipset -X adbyby_wan 2>/dev/null
	ipset -F blockip 2>/dev/null
	ipset -X blockip 2>/dev/null
	logger -t "adbyby" "已关闭全部8118透明代理端口。"
}

reload_rule()
{
	config_load adbyby
	config_foreach get_config adbyby
	del_rule
	iptables-save | grep ADBYBY >/dev/null || \
	add_rule
}

adbyby_uprules()
{
	adbyby_close
	addscripts
	if [ ! -f "$PROG_PATH/adbyby" ]; then
	logger -t "adbyby" "adbyby程序文件不存在，正在解压..."
	tar -xzvf "/etc_ro/adbyby.tar.gz" -C "/tmp"
	logger -t "adbyby" "成功解压至：$PROG_PATH"
	fi
	#if [ $abp_mode -eq 1 ]; then
	#/tmp/adbyby/adblock.sh &
	#fi
	#/tmp/adbyby/adupdate.sh &
	add_rules
	$PROG_PATH/adbyby &>/dev/null &
	add_dns
	iptables-save | grep ADBYBY >/dev/null || \
	add_rule
	hosts_ads
	/sbin/restart_dhcpd
	#add_cron
}

#updateadb()
#{
#	/tmp/adbyby/adblock.sh &
#}
anti_ad(){
anti_ad=`nvram get anti_ad`
anti_ad_link=`nvram get anti_ad_link`
nvram set anti_ad_count=0
if [ "$anti_ad" = "1" ]; then
curl -k -s -o /etc/storage/dnsmasq-adbyby.d/anti-ad-for-dnsmasq.conf --connect-timeout 5 --retry 3 $anti_ad_link
if [ ! -f "/etc/storage/dnsmasq-adbyby.d/anti-ad-for-dnsmasq.conf" ]; then
	logger -t "adbyby" "anti_AD下载失败！"
else
	logger -t "adbyby" "anti_AD下载成功,处理中..."
nvram set anti_ad_count=`grep -v '^#' /etc/storage/dnsmasq-adbyby.d/anti-ad-for-dnsmasq.conf | wc -l`
fi
fi
}

hosts_ads(){
adbyby_hosts=`nvram get hosts_ad`
nvram set adbyby_hostsad=0
if [ "$adbyby_hosts" = "1" ]; then
rm -rf $PROG_PATH/hosts
grep -v '^#' /etc/storage/adbyby_host.sh | grep -v "^$" > $PROG_PATH/hostlist.txt
for ip in `cat $PROG_PATH/hostlist.txt`
do
logger -t "adbyby" "正在下载: $ip"
curl -k -s -o /tmp/host.txt --connect-timeout 5 --retry 3 $ip
if [ ! -f "/tmp/host.txt" ]; then
	logger -t "adbyby" "$ip 下载失败！"
else
	logger -t "adbyby" "hosts下载成功,处理中..."
grep -v '^#' /tmp/host.txt | grep -v "^$" >> $PROG_PATH/hosts
fi
done
rm -f /tmp/host.txt
logger -t "adbyby" "正在对hosts文件进行去重处理."
sort $PROG_PATH/hosts | uniq
nvram set adbyby_hostsad=`grep -v '^!' $PROG_PATH/hosts | wc -l`
sed -i '/hosts/d' /etc/storage/dnsmasq/dnsmasq.conf
cat >> /etc/storage/dnsmasq/dnsmasq.conf <<-EOF
	addn-hosts=$PROG_PATH/hosts
EOF
fi
}

addscripts()
{

	adbyby_rules="/etc/storage/adbyby_rules.sh"
	if [ ! -f "$adbyby_rules" ] || [ ! -s "$adbyby_rules" ] ; then
	cat > "$adbyby_rules" <<-\EEE
EEE
	chmod 755 "$adbyby_rules"
	fi

	adbyby_blockip="/etc/storage/adbyby_blockip.sh"
	if [ ! -f "$adbyby_blockip" ] || [ ! -s "$adbyby_blockip" ] ; then
	cat > "$adbyby_blockip" <<-\EEE
EEE
	chmod 755 "$adbyby_blockip"
	fi

	adbyby_adblack="/etc/storage/adbyby_adblack.sh"
	if [ ! -f "$adbyby_adblack" ] || [ ! -s "$adbyby_adblack" ] ; then
	cat > "$adbyby_adblack" <<-\EEE
EEE
	chmod 755 "$adbyby_adblack"
	fi

	adbyby_adesc="/etc/storage/adbyby_adesc.sh"
	if [ ! -f "$adbyby_adesc" ] || [ ! -s "$adbyby_adesc" ] ; then
	cat > "$adbyby_adesc" <<-\EEE
EEE
	chmod 755 "$adbyby_adesc"
	fi

	adbyby_adhost="/etc/storage/adbyby_adhost.sh"
	if [ ! -f "$adbyby_adhost" ] || [ ! -s "$adbyby_adhost" ] ; then
	cat > "$adbyby_adhost" <<-\EEE
EEE
	chmod 755 "$adbyby_adhost"
	fi
}

case $1 in
start)
	adbyby_start
	;;
stop)
	adbyby_close
	;;
A)
	add_rules
	;;
C)
	add_rule
	;;
D)
	add_dns
	;;
E)
	addscripts
	;;
F)
	hosts_ads
	;;
G)
	adbyby_uprules
	;;
#updateadb)
#	updateadb
#	;;
*)
	echo "check"
	;;
esac
