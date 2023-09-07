#!/bin/bash

interface=$1

if [[ -z "$interface" ]]; then
  echo "Usage: arp-ssh enp10s0"
  exit 1
fi

# Scan the local network interface for devices
devices="`sudo arp-scan --interface=$interface --localnet | sed '1,2d'`"
selected="`(echo "$devices" | fzf)`"


if [[ -z "$selected" ]]; then
  exit 1
fi

# Get the IP address of the selected device
ip=$(sudo arp-scan --interface=$interface --localnet | grep "$selected" | awk '{print $1}')

echo "connecting to $selected"

# Connect to the device using SSH
ssh-retry $ip

