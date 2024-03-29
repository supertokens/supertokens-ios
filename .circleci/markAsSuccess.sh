frontendDriverJson=`cat ../frontendDriverInterfaceSupported.json`
frontendDriverLength=`echo $frontendDriverJson | jq ".versions | length"`
frontendDriverArray=`echo $frontendDriverJson | jq ".versions"`
echo "got frontend driver relations"

# get sdk version
version=`cat ../SuperTokensIOS.podspec | grep -e "s.version          =" -e "s.version="`
while IFS='"' read -ra ADDR; do
    counter=0
    for i in "${ADDR[@]}"; do
        if [ $counter == 1 ]
        then
            version=$i
        fi
        counter=$(($counter+1))
    done
done <<< "$version"

echo "calling /frontend PATCH to make testing passed"
responseStatus=`curl -s -o /dev/null -w "%{http_code}" -X PATCH \
    https://api.supertokens.io/0/frontend \
    -H 'Content-Type: application/json' \
    -H 'api-version: 0' \
    -d "{
        \"password\": \"$SUPERTOKENS_API_KEY\",
        \"version\":\"$version\",
        \"name\": \"ios\",
        \"testPassed\": true
    }"`
if [ $responseStatus -ne "200" ]
then
    echo "patch api failed"
    exit 1
fi