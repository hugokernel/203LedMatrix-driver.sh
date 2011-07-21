#!/bin/bash
VERSION=0.5
BAUD=9600
VERBOSE=0
DEVICE=''

debug() {
	if [ $VERBOSE == 1 ]; then
		echo -n -e "$1"
	fi
}

preamble() {
	local command=$1
	local reply=''

    # Test device
    if [[ ! -e "$DEVICE" ]]; then
        echo "Device $DEVICE not found !"
        exit 0
    fi

	while true;
	do
		if [ $arg ]; then
			debug "Send command: '$command' with $arg"
		else
			debug "Send command: '$command' no arg"
		fi

		printf "$command" > "$DEVICE"

		debug ", waiting reply "
		while read -s -n1 -t2 CHAR;
		do
			reply=$CHAR
			break
		done < "$DEVICE"

		if [ "$reply" != "$command" ]; then
			debug "[No], trying to reset communication\n"
			printf " \r" > "$DEVICE"
			sleep 1
			continue
		else
			debug "[Ok]"
			break
		fi 
	done
}

sendCommand() {
	command=$1
	arg=$2

	preamble $command

	sleep 0.2
	printf "$arg" > "$DEVICE"
	printf " \r" > "$DEVICE"
	
	debug "\n"
}

writeMessage() {
	printf "e" > "$DEVICE"
}

readConf() {
	echo 'c' > "$DEVICE"

	while read -s -n100 -t1 CHAR;
	do
		echo -n $CHAR
	done < "$DEVICE"

	echo
}

setMessage() {
	local string=$1
	local size=$(printf "%03i" ${#string})
	retry=0

	while true;
	do
		while true;
		do
			preamble 'm'

			debug ", wait for ack"

			# Wait for ACK
			while read -s -n1 -t30 CHAR;
			do
				break 2;
			done < "$DEVICE";
		done

		debug ", sending message : « $string »"

		# Send string
		local str=$string
		while [ -n "$str" ]
		do
			printf "%c" "$str" > "$DEVICE"
			str=${str#?}
			sleep 0.05
		done

		# End of string
		printf "\r" > "$DEVICE"

		# Wait for ACK
		while read -s -n3 -t2 CHAR;
		do
			ret_size=$CHAR
		done < "$DEVICE";

		# Loop while size is not ok
		if [[ $retry -gt 2 || "$size" == "$ret_size" ]]; then
			debug ", All done !"
			break
		else
			retry=$(($retry + 1))
			if [[ $retry -gt 2 ]]; then
				debug ", max retry reached !"
			fi

			debug ", size error : $ret_size / $size, try to resend msg\n"
			continue
		fi
	done

	debug "\n"
}

setSpeed() {
	sendCommand 's' $1
}

setDirection() {
	sendCommand 'd' $1
}

setSpacing() {
	sendCommand 'l' $1
}

setIntensity() {
	sendCommand 'i' $1
}

setWatchDog() {
	sendCommand 'w' $1
}

setVerbose() {
	sendCommand 'v' $1
}

info() {
    cat <<EOF
LedMatrix driver - Version $VERSION
--
More information here :
http://www.digitalspirit.org/wiki/projets/ledmatrixhacking
EOF
}

usage() {
    cat <<EOF
Usage: $0 -x /dev/device [option] action

Actions :
 -m 	Set message	
 -s   	Set speed 
 -d 	Set direction
 -l 	Set letter spacing
 -i 	Set intensity
 -v 	Set verbose mode

 -e 	Write configuration in EEPROM
 -c 	Read configuration
 -w     Set Watchdog

 -V 	This script verbose mode
 -h 	Help
EOF
}

# No arg ?
[[ -z "$@" ]] && usage && exit 1

while getopts "hVx:m:s:d:l:i:w:cv:e" flag
do
  case $flag in
    x)  DEVICE="$OPTARG"
	    stty -F "$DEVICE" raw ispeed $BAUD ospeed $BAUD cs8 -ignpar -cstopb eol 255 eof 255
    	;;
    m)  setMessage "$OPTARG"
        ;;
    s)  setSpeed $OPTARG
        ;;
    d)  setDirection $OPTARG
        ;;
    l)  setSpacing $OPTARG
        ;;
    i) 	setIntensity $OPTARG
	    ;;
    e) 	writeMessage
    	;;
    w)  setWatchDog $OPTARG
	    ;;
    c) 	readConf
    	;;
    v)  setVerbose $OPTARG
    	;;
    V)  VERBOSE=1
	    ;;
    h)  info
        ;;
  esac
  sleep 0.1
done

