#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Unicode symbols
CHECK_MARK="\xE2\x9C\x94"
CROSS_MARK="\xE2\x9C\x98"
ROCKET="\xF0\x9F\x9A\x80"
WRENCH="\xF0\x9F\x94\xA7"
HOURGLASS="\xE2\x8C\x9B"

script_url="https://raw.githubusercontent.com/vahidnfc33/airchain-node-ez-installer-script/main/fix.sh"
script_path=$(readlink -f "$0")
hash_file="$HOME/.fix_script_hash"
update_interval=300  # 5 minutes in seconds
error_check_interval=120  # 2 minutes in seconds

# Define service name and log search strings
service_name="stationd"
error_string="ERROR|error|Failed|ERR|with gas used|Failed to Init VRF|Client connection error: error while requesting node|Error in getting sender balance : http post error: Post|rpc error: code = ResourceExhausted desc = request ratelimited|rpc error: code = ResourceExhausted desc = request ratelimited: System blob rate limit for quorum 0|Retrying the transaction after 10 seconds...|Error in VerifyPod transaction Error|Error in ValidateVRF transaction Error|Failed to get transaction by hash: not found|json_rpc_error_string: error while requesting node|can not get junctionDetails.json data|JsonRPC should not be empty at config file|Error in getting address|Failed to load conf info|error unmarshalling config|Error in initiating sequencer nodes due to the above error|Failed to Transact Verify pod| VRF record is nil"
restart_delay=120
config_file="$HOME/.tracks/config/sequencer.toml"
rpc_file="$HOME/okrpc.txt"

# Initialize error count
error_count=0

# Ensure the system has the correct timezone data
sudo apt-get install -y tzdata

# Function to update the script
update_script() {
    echo -e "${BLUE}${WRENCH} Checking for script updates...${NC}"
    temp_file=$(mktemp)
    if curl -s "$script_url" -o "$temp_file"; then
        new_hash=$(md5sum "$temp_file" | awk '{print $1}')
        old_hash=""
        [[ -f "$hash_file" ]] && old_hash=$(cat "$hash_file")
        
        if [[ "$new_hash" != "$old_hash" ]]; then
            echo -e "${GREEN}${ROCKET} New version found. Updating script...${NC}"
            cp "$temp_file" "$script_path"
            chmod +x "$script_path"
            echo "$new_hash" > "$hash_file"
            echo -e "${GREEN}${CHECK_MARK} Script updated successfully. Restarting...${NC}"
            exec bash "$script_path"
        else
            echo -e "${GREEN}${CHECK_MARK} Script is up to date.${NC}"
        fi
    else
        echo -e "${RED}${CROSS_MARK} Failed to check for updates.${NC}"
    fi
    rm "$temp_file"
}

# Function to download the RPC file from GitHub
download_rpc_file() {
    echo -e "${BLUE}${WRENCH} Downloading latest RPC list...${NC}"
    curl -s https://raw.githubusercontent.com/vahidnfc33/airchain-node-ez-installer-script/main/okrpc.txt | tr -d '\r' > "$rpc_file"
    echo -e "${GREEN}${CHECK_MARK} RPC list updated.${NC}"
}

# Function to select a random URL from the file
select_random_url() {
    random_url=$(shuf -n 1 "$rpc_file" | tr -d '\r')
    echo "$random_url"
}

# Function to display error count and next check time
display_status() {
    # Set timezone to Iran time
    export TZ='Asia/Tehran'
    local next_error_check=$(date -d "+2 minutes" +"%H:%M:%S")
    local next_update_check=$(date -d "+5 minutes" +"%H:%M:%S")
    echo -e "${YELLOW}${WRENCH} Total errors found: $error_count${NC}"
    echo -e "${BLUE}${HOURGLASS} Next error check at: $next_error_check (Iran Time)${NC}"
    echo -e "${BLUE}${HOURGLASS} Next update check at: $next_update_check (Iran Time)${NC}"
    echo -e "${BLUE}${HOURGLASS} Error check interval: 2 minutes${NC}"
    echo -e "${BLUE}${HOURGLASS} Update check interval: 5 minutes${NC}"
}

echo -e "${YELLOW}${ROCKET} Script started to monitor errors in PC logs...${NC}"
echo -e "${YELLOW}${ROCKET} Airchain fix script RUN${NC}"

# Update script at startup
update_script

# Initialize the SECONDS variable for timing
SECONDS=0

while true; do
    # Check for updates every 5 minutes
    if (( SECONDS % update_interval == 0 )); then
        update_script
    fi

    # Get the last 10 lines of service logs
    logs=$(systemctl status "$service_name" --no-pager | tail -n 5)

    # Display error checking details
    echo -e "${BLUE}${WRENCH} Checking for errors in $service_name logs...${NC}"
    
    if echo "$logs" | grep -Eqi "$error_string"; then
        # Increment error count
        ((error_count++))

        # Display the specific error found
        error_found=$(echo "$logs" | grep -Ei "$error_string" | head -n 1)
        echo -e "${RED}${CROSS_MARK} Error found: $error_found${NC}"
        echo -e "${RED}${CROSS_MARK} Updating RPC list and $config_file, then restarting $service_name...${NC}"

        # Download the latest RPC list
        download_rpc_file

        # Select a random unique URL
        random_url=$(select_random_url)

        # Update the RPC URL in the config file
        sed -i -e "s|JunctionRPC = \"[^\"]*\"|JunctionRPC = \"$random_url\"|" "$config_file"

        # Stop the service
        systemctl stop "$service_name"
        
        echo -e "${YELLOW}${WRENCH} Performing rollback after changing RPC...${NC}"

        # Check if Go is installed
        if ! command -v go &> /dev/null; then
            echo -e "${YELLOW}${WRENCH} Go is not installed. Installing Go...${NC}"
            VERSION="1.21.6"
            ARCH="amd64"
            curl -O -L "https://golang.org/dl/go${VERSION}.linux-${ARCH}.tar.gz"
            tar -xf "go${VERSION}.linux-${ARCH}.tar.gz"
            sudo rm -rf /usr/local/go
            sudo mv -v go /usr/local
            export GOPATH=$HOME/go
            export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
            echo 'export GOPATH=$HOME/go' >> ~/.bash_profile
            echo 'export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' >> ~/.bash_profile
            source ~/.bash_profile
            go version
        fi

        # Perform rollback
        cd ~/tracks
        sudo systemctl stop stationd
        go run cmd/main.go rollback
        go run cmd/main.go rollback
        go run cmd/main.go rollback
        sudo systemctl restart stationd
        echo -e "${GREEN}${CHECK_MARK} Rollback completed, starting $service_name...${NC}"

        # Start the service
        systemctl start "$service_name"
        echo -e "${GREEN}${CHECK_MARK} Service $service_name started${NC}"

        # Display restart delay
        echo -e "${BLUE}${HOURGLASS} Waiting for $restart_delay seconds before next check...${NC}"
        sleep "$restart_delay"
    else
        # If no errors found, display the wait time
        echo -e "${GREEN}${CHECK_MARK} No errors found.${NC}"
    fi

    # Display error count and next check time
    display_status

    # Wait for 2 minutes before the next error check
    sleep $error_check_interval
    
    # Update the SECONDS variable
    SECONDS=$((SECONDS + error_check_interval))
done
