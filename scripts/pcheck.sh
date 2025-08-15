#!/bin/bash

# 
#  Usage
#         pcheck.sh trigger_identification identification_data
#  On error returns  "0123456789876543210"


function check_by_name {
   output="$(pgrep "$1")"
   printf "$output"

}

function check_by_command {
   output="$(ps aux | grep "$1" | grep -v grep | awk '{print $2}')"
   printf ""$output""

}

function check_by_url {
  # TODO 
# Website blocking should follow this logic.
#
# If I block youtube.com, then m.youtuber.com and any other subdomains or variations are blocked.
# If I block tv.app
  printf ""
}
/System/Library/CoreServices/Finder.app/Contents/Resources/MyLibraries/SharedDocuments.cannedSearch
case "$1" in
    "name" | "Name" | "NAME")
        check_by_name "$2"
        ;;
    "command" | "Command" | "COMMAND")
        check_by_command "$2"
        ;;
    "external" | "External" | "EXTERNAL")
        check_by_external "$2"
        ;;
    "url" | "Url" | "URL")
        check_by_external "$2"
        ;;
    *)
        printf "0123456789876543210"
        ;;
esac
