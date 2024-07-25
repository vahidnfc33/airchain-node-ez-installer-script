#!/bin/bash

script_url="https://raw.githubusercontent.com/vahidnfc33/airchain-node-ez-installer-script/main/fix.sh"
script_path=$(readlink -f "$0")
update_interval=3600  # 1 hour in seconds

# Define service name and log search strings
service_name="stationd"
error_string="ERROR|error|Failed"
gas_string="with gas used"
vrf_error_string="Failed to Init VRF"
client_error_string="Client connection error: error while requesting node"
balance_error_string="Error in getting sender balance : http post error: Post"
rate_limit_error_string="rpc error: code = ResourceExhausted desc = request ratelimited"
rate_limit_blob_error="rpc error: code = ResourceExhausted desc = request ratelimited: System blob rate limit for quorum 0"
err_string="ERR"
retry_transaction_string="Retrying the transaction after 10 seconds..."
verify_pod_error_string="Error in VerifyPod transaction Error"
conf_load_error_string="Failed to load conf info"
restart_delay=180
config_file="$HOME/.tracks/config/sequencer.toml"
rpc_file="$HOME/okrpc.txt"

# Function to update the script
update_script() {
    echo "Checking for script updates..."
    temp_file=$(mktemp)
    if curl -s "$script_url" -o "$temp_file"; then
        if ! cmp -s "$temp_file" "$script_path"; then
            echo "New version found. Updating script..."
            cp "$temp_file" "$script_path"
            chmod +x "$script_path"
            echo "Script updated successfully. Restarting..."
            exec bash "$script_path"
        else
            echo "Script is up to date."
        fi
    else
        echo "Failed to check for updates."
    fi
    rm "$temp_file"
}

# Function to download the RPC file from GitHub
download_rpc_file() {
    echo "Downloading latest RPC list..."
    curl -s https://raw.githubusercontent.com/vahidnfc33/airchain-node-ez-installer-script/main/okrpc.txt | tr -d '\r' > "$rpc_file"
    echo "RPC list updated."
}

# Function to select a random URL from the file
select_random_url() {
    random_url=$(shuf -n 1 "$rpc_file" | tr -d '\r')
    echo "$random_url"
}

echo "Script started to monitor errors in PC logs..."
echo "New update for test. script Fix airchain RUN"

# Update script at startup
update_script

last_update_time=$(date +%s)

while true; do
    current_time=$(date +%s)
    if [ $((current_time - last_update_time)) -ge $update_interval ]; then
        update_script
        last_update_time=$current_time
    fi

    # Get the last 10 lines of service logs
    logs=$(systemctl status "$service_name" --no-pager | tail -n 10)

    if echo "$logs" | grep -Eqi "$error_string|$retry_transaction_string|$verify_pod_error_string|$vrf_error_string|$client_error_string|$balance_error_string|$rate_limit_error_string|$rate_limit_blob_error|$err_string|$conf_load_error_string"; then
        echo "Found error in logs, updating RPC list and $config_file, then restarting $service_name..."

        # Download the latest RPC list
        download_rpc_file

        # Select a random unique URL
        random_url=$(select_random_url)

        # Update the RPC URL in the config file
        sed -i -e "s|JunctionRPC = \"[^\"]*\"|JunctionRPC = \"$random_url\"|" "$config_file"

        # Stop the service
        systemctl stop "$service_name"
        
        if echo "$logs" | grep -q "$gas_string"; then
            echo "Found error and gas used in logs, performing rollback..."
        else
            echo "Performing rollback after changing RPC..."
        fi

        # Perform rollback
        cd ~/tracks
        go run cmd/main.go rollback
        echo "Rollback completed, starting $service_name..."

        # Start the service
        systemctl start "$service_name"
        echo "Service $service_name started"

        # Sleep for the restart delay
        sleep "$restart_delay"
    else
        # If no errors found, just wait before checking again
        sleep "$restart_delay"
    fi
done
