#!/bin/bash

interface=$1

if [[ -z "$interface" ]]; then
  # Use the ifconfig command to get network interface information
  ifconfig_output=$(ifconfig)

  # Use grep and awk to extract the name of the active interface
  interface=$(ip -o link show | awk '$2 != "lo:" && $9 == "UP" {print $2}' | cut -d ":" -f 1)

  if [[ -z "$interface" ]]; then
    echo "Error: failed to auto-detect active network interface."
    exit 1
  fi
fi

# Scan the local network interface for devices
devices="`sudo arp-scan --interface=$interface --localnet | sed '1,2d'`"
selected="`(echo "$devices" | fzf)`"

if [[ -z "$selected" ]]; then
  exit 1
fi

# Get the IP address of the selected device
ip=$(sudo arp-scan --interface=$interface --localnet | grep "$selected" | awk '{print $1}')
echo $ip

