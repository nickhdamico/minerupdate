#!/bin/sh

# EDIT ME
FIRMWARE_URL="https://raw.githubusercontent.com/minerstat/minerstat-asic-hub/master/firmware/Antminer-S9-LPM-20181102.tar.gz"
FIRMWARE_FILE_NAME="Antminer-S9-LPM-20181102"

# CHECK FOR DEPENDENCIES
ERROR="0"

if ! which jq > /dev/null
then
	ERROR="1"
fi

if ! which sshpass > /dev/null
then
	ERROR="1"
fi

if ! which curl > /dev/null
then
	ERROR="1"
fi

if [ "$ERROR" != "0" ]; then
	echo "Need to install dependencies: "
	echo "The install script will ask your root password. "
	echo "sudo apt-get -y install jq sshpass curl"
	sudo apt-get -y install jq sshpass curl
fi

# ASK USER INPUT
echo "Please enter your ACCESS KEY"
read ACCESS_KEY
echo ""

echo "Please enter your group/location [Default: asic] [Enter to skip]"
read GROUP
echo ""

if [ -z "$ACCESS_KEY" -a "$ACCESS_KEY" != " " ]; then
	echo "No accesskey provided"
	exit 0
fi

if [ -z "$GROUP" -a "$GROUP" != " " ]; then
	GROUP="asic"
	echo "WARNING: No group/location provided."
	echo "WARNING: The software will be installed on all of your ASIC workers."
fi

# PING API
id=0
row=$(curl -s "https://api.minerstat.com/v2/stats/$ACCESS_KEY?filter=asic&group=$GROUP")

# CHECK FOR ERROR FIRST
ERROR=$(echo $row | jq -r ".error")
if [ ! -z "$ERROR" -a "$ERROR" != "null" ]; then
	echo "----------------------------------------"
	echo $ERROR
	echo "----------------------------------------"
	exit 1
fi

# CALCULATE OBJECTS
IP=$(echo $row | jq -r ".[] | .info.os.localip")
COUNT=$(echo $IP | wc -w)

if [ "$COUNT" -gt "0" ]; then
	ARRAY=$(echo $row | jq 'to_entries|map([.key] + .value.a|map(tostring)|join(" "))')
	#echo "DEBUG OUTPUT, IP LIST:"
	#echo $ARRAY
	
	for i in $(echo $ARRAY | jq  -r '.[]')    
	do
    	echo ""
   		IP=$(echo $row | jq -r " .[\"$i\"].info.os.localip")
   		LOGIN=$(echo $row | jq -r " .[\"$i\"].info.auth.user")
   		PASS=$(echo $row | jq -r " .[\"$i\"].info.auth.pass")
   		
   		echo "----------------------------------------"
   		echo "$IP: Logging in with $LOGIN / $PASS [$i]"
   		
			INSTALL="echo 'RESPONSE: Installing..'; cd /tmp && curl --insecure -O $FIRMWARE_URL && chmod 777 *.tar.gz && tar -xvf $FIRMWARE_FILE_NAME.tar.gz; ls; ./runme.sh; sleep 1; /sbin/reboot -f &"
			echo "$IP: Updating firmware"

		sshpass -p$PASS ssh $LOGIN@$IP -p 22 -oStrictHostKeyChecking=no -oConnectTimeout=20 "$INSTALL"
		if [ $? -ne 0 ]; then
			echo "$IP: ERROR"
		else
			echo "$IP: OK"
		fi
		
		echo "----------------------------------------"
   		
	done
   	
else
	echo "You have no workers on $ACCESS_KEY account.";
	echo "Common issue: Wrong Group/Location were used.";
fi

# END
