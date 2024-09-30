#!/bin/bash

# Check if the required shell variable $MACHINE is set
if [ -z "$MACHINE" ]; then
  echo "Error: MACHINE environment variable is not set."
  exit 1
fi

# Check if the required IP argument is provided
if [ $# -lt 1 ]; then
  echo "Usage: $0 <target_device_ip>"
  echo "Example: $0 192.168.1.100"
  exit 1
fi

# Set variables
selected_machine=".build-$MACHINE"
target_device="root@$1"   # Replace 'user' with the actual username

# Define the target directory on the embedded device
target_directory="/usr/lib64"

# Check if the machine directory exists
if [ ! -d "$selected_machine" ]; then
  echo "Error: Machine directory '$selected_machine' not found."
  exit 1
fi

# Get list of .so files in the selected machine's src/modules subfolders
so_files=($(find "$selected_machine/src/modules/" -name "*.so"))

# Check if any .so files are found
if [ ${#so_files[@]} -eq 0 ]; then
  echo "No .so files found in $selected_machine/src/modules/"
  exit 1
fi

# Select .so file using fzf
selected_so=$(printf "%s\n" "${so_files[@]}" | fzf --prompt="Select an .so file: ")

# If a file was selected, copy it via scp
if [ -n "$selected_so" ]; then
  scp "$selected_so" "$target_device:$target_directory"
  if [ $? -eq 0 ]; then
    echo "Successfully copied $selected_so to $target_device:$target_directory"
  else
    echo "Failed to copy $selected_so"
  fi
else
  echo "No file selected."
fi

