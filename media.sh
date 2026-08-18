#!/bin/bash

UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36";
CURL_OPTS=(--retry 2 --max-time 10 --retry-max-time 20)
DisneyCountryList='HK TW US JP SG AU TR CA CO NZ KR GB DE BR SE'
netname=`ip a | grep  'WARP\|wgcf' | awk 'NR==1 {print $2}' | cut -d':' -f1`
if cat /etc/XrayR/config.yml | grep -q 'RouteConfigPath' && cat /etc/XrayR/route.json | grep -B 1 'geosite:netflix' | grep -q 'IPv6'; then
	useNICNF='-6'
elif cat /etc/XrayR/config.yml | grep -q 'RouteConfigPath' && cat /etc/XrayR/route.json | grep -B 1 'geosite:netflix' | grep -q 'IPv4'; then
	useNICNF='-4'
else
	useNICNF='-4'
fi
if cat /etc/XrayR/config.yml | grep -q 'RouteConfigPath' && cat /etc/XrayR/route.json | grep -B 1 'geosite:disney' | grep -q 'IPv6'; then
	useNICDS='-6'
elif cat /etc/XrayR/config.yml | grep -q 'RouteConfigPath' && cat /etc/XrayR/route.json | grep -B 1 'geosite:disney' | grep -q 'IPv4'; then
	useNICDS='-4'
else
	useNICDS='-4'
fi
if cat /etc/XrayR/config.yml | grep -q 'RouteConfigPath' && cat /etc/XrayR/route.json | grep -B 1 'geosite:google' | grep -q 'IPv6'; then
	useNICYB='-6'
elif cat /etc/XrayR/config.yml | grep -q 'RouteConfigPath' && cat /etc/XrayR/route.json | grep -B 1 'geosite:google' | grep -q 'IPv4'; then
	useNICYB='-4'
else
	useNICYB='-4'
fi
if cat /etc/XrayR/config.yml | grep -q 'RouteConfigPath' && cat /etc/XrayR/route.json | grep -B 1 'domain:openai.com' | grep -q 'IPv6'; then
	useNICAI='-6'
elif cat /etc/XrayR/config.yml | grep -q 'RouteConfigPath' && cat /etc/XrayR/route.json | grep -B 1 'domain:openai.com' | grep -q 'IPv4'; then
	useNICAI='-4'
else
	useNICAI='-4'
fi

function Test_Netflix() {
   local tmpresult1=$(curl "${CURL_OPTS[@]}" $useNICNF --user-agent "${UA_Browser}" -fsL "https://www.netflix.com/title/81280792" 2>&1)
   local tmpresult2=$(curl "${CURL_OPTS[@]}" $useNICNF --user-agent "${UA_Browser}" -fsL "https://www.netflix.com/title/70143836" 2>&1)
   local result1=$(echo "$tmpresult1" | grep -oP '"metaData":\{[^}]*"isAvailable":\K(true|false)' | tail -n 1)
   local result2=$(echo "$tmpresult2" | grep -oP '"metaData":\{[^}]*"isAvailable":\K(true|false)' | tail -n 1)
   if [[ "$result1" == "false" ]] && [[ "$result2" == "false" ]]; then
      echo -n -e "\r Netflix$useNICNF: Originals Only \n"
      return 0
   elif [ -z "$result1" ] && [ -z "$result2" ]; then
      echo -n -e "\r Netflix$useNICNF: No \n"
      return 0
   elif [[ "$result1" == "true" ]]; then
      local region1=$(echo "$tmpresult1" | grep -oP '"requestCountry":\{[^}]*"id":"\K[A-Za-z]{2}' | tail -n 1)
      echo -n -e "\r Netflix$useNICNF: $region1 \n"
      return 1
   elif [[ "$result2" == "true" ]]; then
      local region2=$(echo "$tmpresult2" | grep -oP '"requestCountry":\{[^}]*"id":"\K[A-Za-z]{2}' | tail -n 1)
      echo -n -e "\r Netflix$useNICNF: $region2 \n"
      return 1
   else
      echo -n -e "\r Netflix$useNICNF: Failed (Network Connection) \n"
      return 0
   fi
}

function Test_Disney() {
   if ! command -v python &> /dev/null; then
      ln -s /usr/bin/python3 /usr/bin/python
   fi
   local PreAssertion=$(curl "${CURL_OPTS[@]}" $useNICDS --user-agent "${UA_Browser}" -s -X POST "https://disney.api.edge.bamgrid.com/devices" -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -H "content-type: application/json; charset=UTF-8" -d '{"deviceFamily":"browser","applicationRuntime":"chrome","deviceProfile":"windows","attributes":{}}' 2>&1)
   local assertion=$(echo $PreAssertion | python -m json.tool 2> /dev/null | grep assertion | cut -f4 -d'"')
   local PreDisneyCookie=$(curl "${CURL_OPTS[@]}" $useNICDS -s "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/cookies" | sed -n '1p')
   local disneycookie=$(echo $PreDisneyCookie | sed "s/DISNEYASSERTION/${assertion}/g")
   local TokenContent=$(curl "${CURL_OPTS[@]}" $useNICDS --user-agent "${UA_Browser}" -s -X POST "https://disney.api.edge.bamgrid.com/token" -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -d "$disneycookie")
   local isBanned=$(echo $TokenContent | python -m json.tool 2> /dev/null | grep 'forbidden-location')
   local is403=$(echo $TokenContent | grep '403 ERROR')

   if [ -n "$isBanned" ] || [ -n "$is403" ];then
      echo -n -e "\r Disney$useNICDS: 403-No \n"
      return 0
   fi

   local fakecontent=$(curl "${CURL_OPTS[@]}" $useNICDS -s "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/cookies" | sed -n '8p')
   local refreshToken=$(echo $TokenContent | python -m json.tool 2> /dev/null | grep 'refresh_token' | awk '{print $2}' | cut -f2 -d'"')
   local disneycontent=$(echo $fakecontent | sed "s/ILOVEDISNEY/${refreshToken}/g")
   local tmpresult=$(curl "${CURL_OPTS[@]}" $useNICDS --user-agent "${UA_Browser}" -X POST -sSL "https://disney.api.edge.bamgrid.com/graph/v1/device/graphql" -H "authorization: ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -d "$disneycontent" 2>&1)
   local previewcheck=$(curl "${CURL_OPTS[@]}" $useNICDS -s -o /dev/null -L -w '%{url_effective}\n' "https://disneyplus.com" | grep preview)
   local isUnabailable=$(echo $previewcheck | grep 'unavailable')	

   if [[ "$tmpresult" == "curl"* ]];then
      echo -n -e "\r Disney$useNICDS: Failed (Network Connection) \n"
      return 0
   fi

   local region2=$(echo $tmpresult | python -m json.tool 2> /dev/null | grep 'countryCode' | cut -f4 -d'"' | tail -n 1)
   local inSupportedLocation=$(echo $tmpresult | python -m json.tool 2> /dev/null | grep 'inSupportedLocation' | awk '{print $2}' | cut -f1 -d',' | tail -n 1)
   if [ -n "$region2" ] && [[ "$inSupportedLocation" == "true" ]];then
      echo -n -e "\r Disney$useNICDS: $region2 \n"
      return 1
   elif [ -n "$region2" ] && [[ "$inSupportedLocation" == "false" ]] && [ -z "$isUnabailable" ];then
      echo -n -e "\r Disney$useNICDS: $region2 Soon \n"
      return 1
   elif [ -n "$region2" ] && [ -n "$isUnabailable" ];then
      echo -n -e "\r Disney$useNICDS: No \n"
      return 0
   elif [ -z "$region2" ];then
      echo -n -e "\r Disney$useNICDS: No \n"
      return 0
   else
      echo -n -e "\r Disney$useNICDS: Failed \n"
      return 0
   fi
}

function Test_Google() {
   local GG_result=$(curl "${CURL_OPTS[@]}" $useNICYB --user-agent "${UA_Browser}" -sSL -H "Accept-Language: en" -b "YSC=ZyA1G52eg5M; VISITOR_PRIVACY_METADATA=CgJERRIA; CONSENT=PENDING+115; SOCS=CAISOAgDEitib3FfaWRlbnRpdHlmcm9udGVuZHVpc2VydmVyXzIwMjMwOTE3LjA5X3AwGgV6aC1DTiACGgYIgI-uqAY; GPS=1; VISITOR_INFO1_LIVE=H3oPP45EiqU; PREF=f4=4000000&tz=Asia.Shanghai" "https://www.youtube.com/premium" 2>&1)
   if [[ "$GG_result" == "curl"* ]]; then
      echo -n -e "\r Google$useNICYB: Failed(Network Connection) \n"
      return 0
   fi
   local isCN=$(echo $GG_result | grep 'www.google.cn')
   if [ -n "$isCN" ]; then
      echo -n -e "\r Google$useNICYB: No(CN) \n"
      return 0
   fi
   local isNotAvailable=$(echo $GG_result | grep 'Premium is not available in your country')
   # local region=$(echo $GG_result | grep "countryCode" | sed 's/.*"countryCode"//' | cut -f2 -d'"')
   # local isAvailable=$(echo $GG_result | egrep '/month|/.month')
   local region=$(echo $GG_result | grep -woP '"INNERTUBE_CONTEXT_GL"\s{0,}:\s{0,}"\K[^"]+' | tail -n 1)
   # local isAvailable=$(echo $GG_result | grep -i 'ad-free')
   if [ -n "$isNotAvailable" ]; then
      echo -n -e "\r Google$useNICYB: No($region) \n"
      return 0
   elif [ -n "$region" ]; then
      echo -n -e "\r Google$useNICYB: $region \n"
      return 1
   else
      echo -n -e "\r Google$useNICYB: Failed \n"
      return 0
   fi
}

function Test_Openai() {
   local result1=$(curl "${CURL_OPTS[@]}" $useNICAI -sS "https://chat.openai.com/auth/login" | egrep 'you have been blocked|If you are using a VPN')
   # local result2=$(curl "${CURL_OPTS[@]}" $useNICAI -sI "https://chat.openai.com/auth/login" | grep 'HTTP/2 200')
   local result3=$(curl "${CURL_OPTS[@]}" $useNICAI -fsL --write-out %{http_code} --output /dev/null "https://chat.openai.com/public-api/conversation_limit" 2>&1)
   local region=$(curl "${CURL_OPTS[@]}" $useNICAI -sS https://chat.openai.com/cdn-cgi/trace | grep "loc=" | awk -F= '{print $2}' | tail -n 1)
   # if [ -z "$result1" ] && [ -n "$result2" ] && [ "$result3" != "403" ]; then
   if [ -z "$result1" ] ; then
      echo -n -e "\r OpenAI$useNICAI: $region \n"
      return 1
   else
      echo -n -e "\r OpenAI$useNICAI: BLOCKED!"
      return 0
   fi
}

function Loop() {
   local max_retries=30
   local i=1

   while [ $i -le $max_retries ]; do
      Test_Netflix > /dev/null 2>&1
      local res_nf=$?
      Test_Google > /dev/null 2>&1
      local res_google=$?
      Test_Disney > /dev/null 2>&1
      local res_disney=$?

      if [ $((res_nf + res_google + res_disney)) -eq 3 ]; then
         if [ $i -gt 1 ]; then
            echo -n -e "\r ip失效.更新$((i - 1))次\n"
         fi
         Test_Netflix
         Test_Google
         Test_Disney
         Test_Openai
         break
      else
         # 切换 IP
         if [[ ${netname} == "wgcf" ]]; then systemctl restart wg-quick@wgcf
         elif [[ ${netname} == "WARP" ]]; then systemctl restart warp-go
         elif [[ ${netname} == "CloudflareWARP" ]]; then systemctl restart warp-svc
         fi

         sleep 3
         ((i++))
      fi
      
   done

   if [ $i -gt $max_retries ]; then
      echo -n -e "\r 老子抓不到ip了,躺平吧 \n"
   fi
   
   
}


if [ "$1" = "nf" ];then
   Test_Netflix
elif [ "$1" = "disney" ];then
   Test_Disney
elif [ "$1" = "google" ];then
   Test_Google
elif [ "$1" = "openai" ];then
   Test_Openai
elif [ "$1" = "loop" ];then
   Loop
else
   Test_Netflix
   Test_Disney
   Test_Google
   Test_Openai
fi
