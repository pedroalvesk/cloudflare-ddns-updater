#!/bin/bash

log="cloudflare-$(date +'%Y-%m-%d').log"

###########################################
##  Timestamp on log
###########################################
message=$(date +"%D %T")
  	>&2 echo -e "\n${message}" >> "${log}"


###########################################
##  Check if we have enough arguments
###########################################
if [ "$#" -ne 5 ]; then
	message="Usage: $0 <auth_email> <auth_key> <zone_identifier> <record_name> <proxy>"
  	>&2 echo -e "${message}" >> "${log}"
exit 1
fi


###########################################
##  Variables
###########################################
auth_email=$1									# The email used to login 'https://dash.cloudflare.com'
auth_key=$2                     			    # Top right corner, "My profile" > "Global API Key"
zone_identifier=$3  		     				# Can be found in the "Overview" tab of your domain
record_name=$4           						# Which record you want to be synced
proxy=$5                  						# Set the proxy to true or false 


###########################################
## Check if we have an public IP
###########################################
ip=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com/ || curl -s https://ip4.seeip.org)
if [ "${ip}" == "" ]; then 
  message="No public IP found."
  >&2 echo -e "${message}" >> "${log}"
  exit 1
fi


###########################################
## Seek for the A record
###########################################
echo "Check Initiated" >> "${log}"
record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json")


###########################################
## Check if the domaine has an A record
###########################################
if [[ $record == *"\"count\":0"* ]]; then
  message=" Record does not exist, perhaps create one first? (${ip} for ${record_name})"
  >&2 echo -e "${message}" >> "${log}"
  exit 1
fi


###########################################
## Get the existing IP 
###########################################
old_ip=$(echo "$record" | grep -Po '(?<="content":")[^"]*' | head -1)
# Compare if they're the same
if [[ $ip == $old_ip ]]; then
  message=" IP ($ip) for ${record_name} has not changed."
  echo "${message}" >> "${log}"
  exit 0
fi


###########################################
## Set the record identifier from result
###########################################
record_identifier=$(echo "$record" | grep -Po '(?<="id":")[^"]*' | head -1)


###########################################
## Change the IP@Cloudflare using the API
###########################################
update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
	-H "X-Auth-Email: $auth_email" \
	-H "X-Auth-Key: $auth_key" \
	-H "Content-Type: application/json" \
	--data "{\"id\":\"$zone_identifier\",\"type\":\"A\",\"proxied\":${proxy},\"name\":\"$record_name\",\"content\":\"$ip\"}")


###########################################
## Report the status
###########################################
case "$update" in
*"\"success\":false"*)
  message="$ip $record_name DDNS failed for $record_identifier ($ip). DUMPING RESULTS:\n$update"
  >&2 echo -e "${message}" >> "${log}"
  exit 1;;
*)
  message="$ip $record_name DDNS updated."
  echo "${message}" >> "${log}"
  exit 0;;
esac
