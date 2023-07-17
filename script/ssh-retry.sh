#!/bin/bash

# Check if IP address is provided as a command-line argument
if [ -z "$1" ]; then
    echo "Usage: $0 <ip_address>"
    exit 1
fi

# Remote server details
remote_host="$1"
remote_user="root"
remote_port="22"

# SSH options
ssh_options="-o ConnectTimeout=10"

# Function to attempt SSH connection
function try_ssh {
    echo "Attempting SSH connection to $remote_user@$remote_host..."
    ssh $ssh_options -p $remote_port $remote_user@$remote_host
    exit_status=$?
    if [ $exit_status -eq 0 ]; then
        echo "SSH connection succeeded!"
        exit 0
    else
        echo "SSH connection failed. Retrying in 5 seconds..."
        sleep 5
    fi
}

# Main loop to retry SSH connection
while true; do
    try_ssh
done
