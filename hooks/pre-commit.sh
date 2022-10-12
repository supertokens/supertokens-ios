#!/bin/bash
# get current version----------
version=`cat SuperTokensIOS.podspec | grep -e "s.version          =" -e "s.version="`

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

# get version from code
codeversion=`cat SuperTokensIOS/Classes/Version.swift | grep -e "sdkVersion =" -e "sdkVersion="`
while IFS='"' read -ra ADDR; do
    counter=0
    for i in "${ADDR[@]}"; do
        if [ $counter == 1 ]
        then
            codeversion=$i
        fi
        counter=$(($counter+1))
    done
done <<< "$codeversion"

if [ $version != $codeversion ]
then
    RED='\033[0;31m'
    NC='\033[0m' # No Color
    printf "${RED}Version codes in podspec and Version.swift are not the same${NC}\n"
    exit 1
fi

# get git branch name-----------
branch_name="$(git symbolic-ref HEAD 2>/dev/null)" ||
branch_name="(unnamed branch)"     # detached HEAD

branch_name=${branch_name##refs/heads/}

# check if branch is correct based on the version-----------
if [ $branch_name == "master" ]
then
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
    printf "${YELLOW}committing to MASTER${NC}\n"
    exit 0
elif [[ $version == $branch_name* ]]
then
    continue=1
else
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
    printf "${YELLOW}Not committing to master or version branches${NC}\n"
fi
