#!/bin/bash

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
conf_load_error_string="Failed to load conf info"  # New error string
restart_delay=180
config_file="$HOME/.tracks/config/sequencer.toml"
rpc_file="$HOME/okrpc.txt"  # Path to the file containing RPC URLs

# Function to download the RPC file from GitHub
download_rpc_file() {
    echo "Downloading latest RPC list..."
    curl -s https://raw.githubusercontent.com/vahidnfc33/airchain-node-ez-installer-script/main/okrpc.txt | tr -d '\r' > "$rpc_file"
    echo "RPC list updated."
}

# Function to select a random URL from the file
select_random_url() {
    # Select a random line from the file and remove any carriage return characters
    random_url=$(shuf -n 1 "$rpc_file" | tr -d '\r')
    echo "$random_url"
}

echo "Script started to monitor errors in PC logs..."
echo "by onixia"

while true; do
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