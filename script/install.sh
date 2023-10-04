#!/bin/bash

# Check if the user has sufficient permissions to create symlinks in /usr/local/bin
if [ "$(id -u)" != "0" ]; then
  echo "You need root privileges to create symlinks in /usr/local/bin. Please run this script as root or with sudo."
  exit 1
fi

# Loop over each .sh file in the current directory
for sh_file in *.sh; do
  # Check if the file is a regular file
  if [ -f "$sh_file" ]; then
    # Define the symlink target path
    symlink_path="/usr/local/bin/$(basename "$sh_file" .sh)"

    # Create the symlink
    ln -s "$(pwd)/$sh_file" "$symlink_path"

    # Check if the symlink creation was successful
    if [ $? -eq 0 ]; then
      echo "Created symlink: $symlink_path"
    else
      echo "Failed to create symlink: $symlink_path"
    fi
  fi
done
