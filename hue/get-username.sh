#!/bin/bash

TIMEOUT=30

# Get IP/Hostname
read -p "Enter the IP or hostname of the Philips Hue Bridge: " BRIDGE

# Ping the bridge to check the above input was valid
echo "Pinging the bridge to confirm connectivity..."
ping -q -c 3 ${BRIDGE} > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "The bridge did not respond to a ping test. Please confirm the bridge is running and configured, then rerun this script."
    exit 1
else
    echo "Ping successful."
fi

# Check that this is a Philips Hue Bridge
#if [[ $(curl -s "http://${BRIDGE}/api/") =~ .*unauthorized\ user.* ]]; then
#    echo "The device does not appear to be a Philips Hue Bridge"
#    exit 1
#fi

# Get username from server:
TIME=$(date +%s)
RESPONSE=$(curl -s -d '{"devicetype":"zabbix#server"}' "http://${BRIDGE}/api/")
echo "Waiting 30 seconds for the Link button on the Hue Bridge to be pressed"
while [[ "${RESPONSE}" =~ .*link\ button\ not\ pressed.* ]]; do
    TIMENOW=$(date +%s)
    TIMECHECK=$((${TIMENOW}-${TIMEOUT}))
    if [ ${TIMECHECK} -gt ${TIME} ]; then
        echo -e "\nTimeout"
        break
    fi
    echo -n "."
    sleep 1
    RESPONSE=$(curl -s -d '{"devicetype":"zabbix#server"}' "http://${BRIDGE}/api/")
done

# Test username can hit the API
echo ${RESPONSE}
# Output username
