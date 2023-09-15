#!/bin/bash

# Define the file name
file="image.swu"
url=""
json_file="info.json"
forced_update=false

# Parse command line arguments using a loop
while [[ $# -gt 0 ]]; do
    case "$1" in
        --file=*)
            file="${1#*=}"
            ;;
        --url=*)
            url="${1#*=}"
            ;;
        --force=*)
            forced_update="${1#*=}"
            if [[ "$forced_update" != "true" && "$forced_update" != "false" ]]; then
                echo "Error: Invalid argument for --force. Please use 'true' or 'false'."
                exit 1
            fi
            ;;
        --mac=*)
            mac="${1#*=}"
            ;;
        *)
            echo "Error: Invalid argument: $1"
            exit 1
            ;;
    esac
    shift
done

# Check if the --url argument is provided and not empty
if [ -z "$url" ]; then
    echo "Error: Missing or empty --url argument. Please provide a valid URL."
    exit 1
fi

# Use sed to extract the third line of the file
third_line=$(sed -n '3p' "$file")

# Use grep and regular expressions to extract the version variable
if [[ $third_line =~ version\ =\ \"([^\"]+)\" ]]; then
    version="${BASH_REMATCH[1]}"
    echo "Found version in $file: $version"
else
    echo "Error: Unable to extract version from the third line of $file."
    exit 1
fi

# Use stat to get the size of the file
file_size=$(stat -c %s "$file")
echo "File size of $file is $file_size bytes."

# If a MAC address is provided, append it to the file name (after extracting the info)
if [ -n "$mac" ]; then
    json_file="info.json_mac_$mac"
fi

# Generate the JSON content
json_content=$(cat <<EOF
{
    "version": "$version",
    "url": "$url",
    "imageSize": $file_size,
    "forcedUpdate": $forced_update
}
EOF
)

# Write the JSON content to the JSON file
echo "$json_content" > "$json_file"

echo "JSON file '$json_file' created with the following content:"
cat "$json_file"
