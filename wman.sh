#!/bin/bash

#imports
. scan.sh
. accepted.sh
. check_connection.sh
. lan_clients_count.sh
. connect_to_ap.sh

#variables
wlan_interface="wlan0"
wan_interface="br-wan"
wait_connect_time=10
recheck_time=15
aps_without_internet=()
aps_without_internet_clear=3600

#rm -rf /tmp/wman/
mkdir /tmp/wman/
touch /tmp/wman/current_ap_prioriry
touch /tmp/wman/aps_without_internet_i

function log(){
	local msg=$1
	echo $msg
	logger -t wman $msg
}

function try_connect_to_accepted(){
	# ������� �����, ���� � ��� ��� ���������
	for ap_string in "${accepted[@]}"
	do
		IFS=':' read -a ap <<< "$ap_string"
		local priority="${ap[0]}"
		local BSSID="${ap[1]}"
		local connect_to_better="${ap[2]}"
		if test ${aps_without_internet[$BSSID]+_}; then
			local aps_without_internet_i=$(</tmp/wman/aps_without_internet_i)
			if (( "$aps_without_internet_i" >= "$aps_without_internet_clear" )); then
				aps_without_internet=()
				echo 0 > /tmp/wl/aps_without_internet_i
			else
				# TODO ������� �� ���������� ����� ��� ���������
				echo "$(( aps_without_internet_i + 1 ))" > /tmp/wl/aps_without_internet_i
			fi
		else
			# ������������ � �����
			connect_to_ap "$BSSID"
			# �ģ� �����������
			sleep "$wait_connect_time"
			# �������� ����������
			if (( $( check_connection "$wlan_interface" ) == 1 )); then
				log "Connection to internet restored! Connected to $BSSID with priority $priority"
				echo "$priority" > /tmp/wman/current_ap_prioriry
				break
			else
				echo "$BSSID hasnt internet!"
				aps_without_internet+=("$BSSID")
			fi
		fi
	done
}

function main()
{
	# ���� ��� wan �����������
	if (( $( check_connection "$wan_interface" ) == 0 )); then
		log "wan interface hasnt internet"
		# ���� � ��� ��� ��������, �� wifi �� ���������
		if (( $( lan_clients_count ) > 0 )); then
			log "there are clients in lan"
			# ��������� ������� �����
			local current_ap_prioriry=$(</tmp/wman/current_ap_prioriry)
			if (( $( check_connection "$wlan_interface" ) == 0 )); then
				rm /tmp/wman/current_ap_prioriry
				log "Internet connection was losted!"
				scan "$wlan_interface"
				
				eval `accepted`
				
				try_connect_to_accepted
			else
				log "We have internet connection"
				local current_ap_line=$( sed "$(( $current_ap_prioriry + 1 ))q;d" /etc/wman/aps.conf )
				IFS=$'\t' read -a ap <<< "$current_ap_line"
				local connect_to_better="${ap[1]}"
				# ����� ������ ����� �����������
				if [[ $connect_to_better == "y" ]]; then
					#���� �����, ������������ ����
					log "Trying connect to better"
					scan "$wlan_interface"
					eval `accepted $current_ap_prioriry`
					try_connect_to_accepted
				fi
			fi
		else
			log "there are not clients in lan. shutdown wifi"
			rm /tmp/wman/current_ap_prioriry
			ifconfig "$wlan_interface" down
		fi
    fi
    
    #����������� �� ���� �������
    #sort -k3nr /tmp/ScannedAPs_Parsed.MP -o /tmp/ScannedAPs_Parsed.MP
    
    #���������� ������� ������ ������ �����
    #cat /tmp/ScannedAPs_Parsed.MP | grep '7094\|555'
    
    #AP 'ap1' o1:3f:33 Ololo -42 3
    #$ap1_show
    #$ap1_connect
}

while [ 1 ]; do
    main
	sleep $recheck_time
done