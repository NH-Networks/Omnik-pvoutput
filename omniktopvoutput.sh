#!/bin/bash
#
# Variables
# Set wirepush id 
wpid=xxxx
zerocheck=/opt/omnik/.zerocheck #used to check for lastupdate in case of zero output.
inverterip=10.10.32.1
logpath=/mnt/USB16GB/omnik/logs
# please change with correct sid and key from pvoutput.org account
sid=99999
key=c393599e8251e497da5c51c9xxxxxxxxxxxxxxxx
# please change to your weather location (Only Netherlands Support)
location=Almelo

# Functions
getpostdatastring () {
	# postdata String, change value's to match inverters output on status.js
	# NLDNXXXXXXXXXXXX,NL1-V1.0-XXXX-4,V2.0-XXXX,omnikXXXXtl ,X000,1070,790,160839,,1,
	postdatastring="${auth}&v1=$powertoday&v2=${Array[5]}&v5=$temp&t=$minute&d=$today"	
}

postdata () {
	if [ -f "$zerocheck" ]; then
		rm -f $zerocheck
	fi
	getpostdatastring
	echo "Running normal and posting data to pvoutput. Output power is ${Array[5]} Watt. outside Temp. is $temp Degrees."
	echo -n "$today $minute " >> "$logpath/$today-omniktopvoutput.log"
	curl -s "http://pvoutput.org/service/r2/addstatus.jsp?$postdatastring" >> "$logpath/$today-omniktopvoutput.log"
	echo "" >> "$logpath/$today-omniktopvoutput.log"
	exit
}

lastpostdata () {
	getpostdatastring
	echo "$zerocheck does not exist, post last 0 output to pvoutput"
	echo -n "$today $minute " >> "$logpath/$today-omniktopvoutput.log"
	curl -s "http://pvoutput.org/service/r2/addstatus.jsp?$postdatastring" >> "$logpath/$today-omniktopvoutput.log"
	echo "" >> "$logpath/$today-omniktopvoutput.log"
	touch $zerocheck
	exit 1
}

postnodata () {
	echo "$zerocheck exist"
	echo "Solar power is 0, No update to pvoutput"
	echo -n "$today $minute Solar power is 0, No update to pvoutput"  >> "$logpath/$today-omniktopvoutput.log"
	echo "" >> "$logpath/$today-omniktopvoutput.log"
	exit 1
}
getweather () {
	temp1=$(curl -s http://weerlive.nl/api/json-10min.php?locatie=$location | grep 'temp' | cut -d : -f 4 | cut -d , -f 1 | sed 's/"//g')
	temp=$(echo $temp1 | sed 's/[^0-9.]*//g')

	if [ -z "$temp" ]
	  then
	  	# failback temp if no data could be retrieved from api.
		temp=99
	fi
}


#Wait for Omnik Inverter to be online
while :; do
    ping -c 1 -W 30 $inverterip >/dev/null 2>&1
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

find $logpath/ -type f -daystart -mtime +2 -exec rm {} \;

url="http://$inverterip/js/status.js"

# get most recent webdata from Hosola / Omnik inverter
content=$(curl -s --connect-timeout 20 --retry 3 --retry-connrefused --retry-delay 2 --max-time 120 $url | tr ';' '\n' | grep -e "^myDeviceArray\[0\]" | sed -e 's/"//g' | sed 's/myDeviceArray\[0\] = //')

if [[ -z "$content" ]]; then
	# sleep for 20 sec to give inventer some time to recover and answer.
	sleep 20
    content=$(curl -s --connect-timeout 15 --retry 3 --retry-connrefused --retry-delay 2 --max-time 120 $url | tr ';' '\n' | grep -e "^myDeviceArray\[0\]" | sed -e 's/"//g' | sed 's/myDeviceArray\[0\] = //')
fi

if [[ -z "$content" ]]; then
	curl "https://wirepusher.com/send?id=$wpid&title=Omnik%20PVoutput%20Error&message=Data%20content%20is%20empty%20quiting%20script&type=pverror&message_id=15"
    exit 1
fi

# get current power value, put all available values in array
set -- "$content"
IFS=","; declare -a Array=($*)

# NLDNXXXXXXXXXXXX,NL1-V1.0-XXXX-4,V2.0-XXXX,omnikXXXXtl ,X000,1070,790,160839,,1,

auth="sid=$sid&key=$key"

powertoday=$((Array[6]*1*10))
echo "total power today $powertoday"

# if power value from inverter is 0
if (( ${Array[5]} == 0 )); then
	if [ -f "$zerocheck" ]; then
    	postnodata
	else
		getweather 
    	lastpostdata
	fi
fi

#all normal run postdata function.
getweather
postdata
exit
