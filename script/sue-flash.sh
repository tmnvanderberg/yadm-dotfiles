#!/bin/bash

# Function to check if a string is a valid IP address
is_valid_ip() {
  local ip="$1"
  if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    # Split the IP address into octets
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
      if ((octet < 0 || octet > 255)); then
        return 1  # Invalid octet value
      fi
    done
    return 0  # Valid IP address
  else
    return 1  # Invalid format
  fi
}

# Check if fzf is installed
if ! command -v fzf &>/dev/null; then
    echo "Error: fzf is not installed. Please install fzf."
    exit 1
fi

# Function to find .swu files
find_swu_file() {
    local selected_file
    selected_file=$(find . -type l -name "image.swu" 2>/dev/null | fzf --prompt "Select .swu file: ")
    
    if [ -z "$selected_file" ]; then
        return 1
    fi
    
    echo "$selected_file"
    return 0
}

# Attempt to find .swu file in the current directory or its subdirectories
if selected_file=$(find_swu_file); then
    echo "Selected file: $selected_file"
fi

# arg can be ip or interface for discovery
if is_valid_ip "$1"; then
    echo "valid ip given, using"
    device_ip="$1"
else
    echo "no valid ip, assuming it's an interface"
    device_ip=$(arp-ip $1) # can be empty for interface auto-try
fi

# SSH to the device and run fwup
ssh root@$device_ip "nsdk_cli invoke firmwareupdate:startLocalUpdate"

# Wait for the device to reboot (you might need to customize this)
sleep 15

# Use curl to simulate the file upload through the web interface
curl -F "image=@$selected_file" http://$device_ip/handle_post_request

# You might need to customize the URL and form field names depending on your device's web interface

# Add additional logic to verify the update process if needed
# For example, you can check the device's status page or log files

echo "Firmware update completed."
