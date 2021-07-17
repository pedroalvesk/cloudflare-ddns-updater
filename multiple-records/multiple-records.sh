#!/bin/bash

records=(
    "mydomain.com" 
    "www.mydomain.com"
    "sub1.mydomain.com"
    "sub2.mydomain.com"
)

for i in "${records[@]}"
do
	result=$(/bin/bash cloudflare-update-record.sh $i)
done