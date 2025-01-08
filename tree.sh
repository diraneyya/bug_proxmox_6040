#!/usr/bin/env bash

source './utils.sh'
if ! command_check 'tree' 'https://salsa.debian.org/debian/tree-packaging'; then exit $?; fi

if ! [ -d $1 ]; then exit 1; fi
if find -s $1 &>/dev/null; then SORT_OPTION='-s'; fi 
find $SORT_OPTION $1 -type f \
    -exec printf '\n{}\n\t' ';' \
    -exec head -c 8 '{}' ';' | \
    sed -e 's/^.*gitkeep$//' > .info_$1

SH=$(printf "\e[33m")
SH2=$(printf "\e[32;1m")
SH3=$(printf "\e[35;1m")
SD=$(printf "\e[2m")
CD=$(printf "\e[22m")
CH=$(printf "\e[0m")
declare -a SED_EXP
SED_EXP+=("2s/\(\|[-]\{2,4\}\) \(sample123\)/\1 $SH\2 $SD<- exclude my contents only$CH/")
SED_EXP+=("s/\(extracted1\)/$SH2\1 $SD<- paths in ${CD}tar$SD start with '\.\/'$CH/")
SED_EXP+=("s/\(extracted2\)/$SH3\1 $SD<- paths in ${CD}tar$SD start immediately$CH/")

INFO_PARAM="--infofile=.info_$1"
if ! tree $INFO_PARAM $1 &>/dev/null; then INFO_PARAM=; fi
tree $INFO_PARAM $1 | sed "${SED_EXP[@]/#/-e }"