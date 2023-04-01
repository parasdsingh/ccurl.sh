#!/bin/bash

# Define variables
tab_url_prefix="$1"
curl_command="${@:2}"
json_url="http://127.0.0.1:9222/json"

# Check if required tools are installed
if ! command -v curl > /dev/null; then
    echo "Error: curl is not installed. Please install it and try again."
    exit 1
fi

if ! command -v jq > /dev/null; then
    echo "Error: jq is not installed. Please install it and try again."
    exit 1
fi

if ! command -v websocat > /dev/null; then
    echo "Error: websocat is not installed. Please install it and try again."
    exit 1
fi

# Check if required arguments are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 [Tab URL Prefix] [cURL command ...]"
    exit 1
fi

# Find the URL of the first tab that matches the specified prefix
debug_url=$(curl "$json_url" -s | jq -r ".[] | select(.url | startswith(\"$tab_url_prefix\")) | .webSocketDebuggerUrl")
if ! [[ "$debug_url" =~ ^ws.* ]]; then
    echo "Error: Could not find tab starting with '$tab_url_prefix'. Is Chrome running?"
    exit 1
fi

# Check if multiple tabs match the specified prefix
if [[ "$(echo "$debug_url" | tr -cd ';' | wc -c)" -gt 1 ]]; then
    echo "Error: Pattern '$tab_url_prefix' is not precise enough. Multiple tabs/workers were found."
    exit 1
fi

# Get the cookies for the tab using websocat and format them for use in a cURL request
cookies=$(echo '{ "id":2, "method":"Network.getCookies", "params":{} }' | websocat -t - "$debug_url" | jq -r '.result.cookies[] | "\(.name)=\(.value)"' | tr '\n' ';' | sed 's/;$//')

# Execute the cURL command with the cookies
eval "curl -H \"Cookie: $cookies\" \"$curl_command\""

# Print a help message
cat <<EOF

Usage: $0 [Tab URL Prefix] [cURL command ...]

This script sends a cURL request with the cookies from the first tab in Google Chrome that matches the specified URL prefix.
