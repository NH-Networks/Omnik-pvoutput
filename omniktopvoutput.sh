#!/bin/bash
#
# variables
ip=10.10.32.1
logpath='/mnt/USB16GB/omnik/logs'

#Wait for Omnik Inverter to be online (Change to you own inverter ip address)
while :; do
    ping -c 1 -W $ip >/dev/null 2>&1
    if [ $? = 0 ]; then
        break
    else
        echo "Inverter Offline!"
    fi
    sleep 1
done

echo "Inverter Online!"

today=`date '+%Y%m%d'`
minute=`date '+%H:%M'`


# Delete's log logs files, change +3 for day's to keep, now set to 3 day's 
find $logpath/ -type f -mtime +3 -exec rm {} \;

# please change with correct location (Netherlands support only)
temp1=$(curl -s http://weerlive.nl/api/json-10min.php?locatie=Almelo | grep 'temp' | cut -d : -f 4 | cut -d , -f 1 | sed 's/"//g')
temp=$(echo $temp1 | sed 's/[^0-9.]*//g')

# if temp var is empty for some reason, temp will be set to 99.
if [ -z "$temp" ]
  then
	temp=99
fi

url="http://$ip/js/status.js"

# get most recent webdata from Hosola / Omnik inverter
content=$(curl -s --connect-timeout 30 --retry 3 --retry-connrefused --retry-delay 2 --max-time 120 $url | tr ';' '\n' | grep -e "^myDeviceArray\[0\]" | sed -e 's/"//g' | sed 's/myDeviceArray\[0\] = //')

if [[ -z "$content" ]]; then
	# Change send?id=XXXX to your own ID for pushmessage in case of error getting data from status.js
	curl "https://wirepusher.com/send?id=XXXX&title=Omnik%20PVoutput%20Error&message=Data%20content%20is%20empty%20quiting%20script&type=pverror&message_id=15"
    exit 1
fi

# get current power value, put all available values in array
set -- "$content"
IFS=","; declare -a Array=($*)

# NLDNXXXXXXXXXXXX,NL1-V1.0-XXXX-4,V2.0-XXXX,omnikXXXXtl ,X000,1070,790,160839,,1,

# please change with correct sid and key from pvoutput.org account
auth="sid=xxxxx&key=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# post power value to pvoutput site
# This can be Array[5] or Array[6], depends on model, for my 4K-TL3 it needs to be Array[5] for correct value's
postdatastring="${auth}&v2=${Array[5]}&v5=$temp&t=$minute&d=$today"

# Change value to same as above, Array[5] or Array[6]
if (( ${Array[5]} == 0 )); then
	echo "Solar power is 0, No update to pvoutput"
    echo -n "$today $minute Solar power is 0, No update to pvoutput"  >> "$logpath/$today-omniktopvoutput.log"
	echo "" >> "$logpath/$today-omniktopvoutput.log"
	exit
    return
fi

echo -n "$today $minute " >> "$logpath/$today-omniktopvoutput.log"
curl -s "http://pvoutput.org/service/r2/addstatus.jsp?$postdatastring" >> "$logpath/$today-omniktopvoutput.log"
echo "" >> "$logpath/$today-omniktopvoutput.log"
exit
