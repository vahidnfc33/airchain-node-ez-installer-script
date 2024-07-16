# airchain-node-ez-installer-script

دوستان این اسکریپت برای نصب نود ایرچین هست که کارتونو موقع نصب روی سرور راحت میکنه ، قسمت هایی که نیاز هست چیزی وارد کنید یا کپی کنید براش مشخص شده 
روش کارش هم اینجوری هست که اول part1 رو انتخاب میکنین وقتی به مرحله درست کردن کیف پول ایگن شد و کیف پول رو درست کردین و مشخصاتش رو برداشتین ، part2 رو انتخاب کنید که ادامش انجام بشه ، و پارت 3 هم برای تراکنش اتومات هست که میتونین بعد از اینکه پارت یک و دو رو اوکی کردین برین اونم انجام بدین 



    با دستور زیر یه فایل متنی ایجاد کنید 

```bash
    nano airchain-install.sh
```

بعد متن زیرو داخلش کپی کنید  :

```bash
clear

# Define ANSI escape sequences for different colors
txtblk=$(tput setaf 0)  # Black
txtred=$(tput setaf 1)  # Red
txtgrn=$(tput setaf 2)  # Green
txtylw=$(tput setaf 3)  # Yellow
txtblu=$(tput setaf 4)  # Blue
txtpur=$(tput setaf 5)  # Purple
txtcyn=$(tput setaf 6)  # Cyan
txtwht=$(tput setaf 7)  # White

# Create an array of color variables
colors=("$txtblk" "$txtred" "$txtgrn" "$txtylw" "$txtblu" "$txtpur" "$txtcyn" "$txtwht")

# Generate a random index to select a color
random_index=$((RANDOM % ${#colors[@]}))
selected_color="${colors[$random_index]}"

# Your original script content
echo "${selected_color}##################################################################"
echo "#Script Name    : Airchain installer                               "
echo "#Description    : EZPZ installer airchain node                     "
echo "#Author         : vahidnfc                                          "
echo "                                                                  "
echo "##################################################################"
# Reset text color
tput sgr0
echo ""
echo ""
echo "${txtcyn}Script Setup Airchain Node:"
tput sgr0
echo ""
echo "1. Setup airchain Part 1"
echo "2. Setup airchain Part 2"
echo "3. Setup Auto Tx"
echo ""
read -p "please select what part u want run: " choice






if [ "$choice" == "1" ]; then
    echo "Part 1 Runing..."
cd
	sudo apt update && sudo apt upgrade -y
sudo apt install curl git wget htop tmux build-essential jq make lz4 gcc unzip -y

# Install Go
VERSION="1.21.6"
ARCH="amd64"
curl -O -L "https://golang.org/dl/go${VERSION}.linux-${ARCH}.tar.gz"
tar -xf "go${VERSION}.linux-${ARCH}.tar.gz"
sudo rm -rf /usr/local/go
sudo mv -v go /usr/local
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
source ~/.bash_profile
go version

# Clone GitHub Repositories
git clone https://github.com/airchains-network/evm-station.git
git clone https://github.com/airchains-network/tracks.git

# Setup EVM station
rm -r ~/.evmosd
cd ~/evm-station
git checkout --detac v1.0.2
go mod tidy
/bin/bash ./scripts/local-setup.sh

# Create env file
cd ~

echo 'MONIKER="localtestnet"
KEYRING="test"
KEYALGO="eth_secp256k1"
LOGLEVEL="info"
HOMEDIR="$HOME/.evmosd"
TRACE=""
BASEFEE=1000000000
CONFIG=$HOMEDIR/config/config.toml
APP_TOML=$HOMEDIR/config/app.toml
GENESIS=$HOMEDIR/config/genesis.json
TMP_GENESIS=$HOMEDIR/config/tmp_genesis.json
VAL_KEY="mykey"' > .rollup-env																																												

# Create evmosd service file
sudo tee /etc/systemd/system/evmosd.service > /dev/null << EOF
[Unit]
Description=ZK
After=network.target

[Service]
User=root
EnvironmentFile=/root/.rollup-env
ExecStart=/root/evm-station/build/station-evm start --metrics "" --log_level info --json-rpc.api eth,txpool,personal,net,debug,web3 --chain-id "stationevm_1234-1"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Start evmosd service
sudo systemctl enable evmosd
sudo systemctl start evmosd

# Get Your Private Key of EVM Station
clear
cd evm-station
/bin/bash ./scripts/local-keys.sh
read -p 	"${txtwht}Copy ur Evmos PrivateKey and press Enter"
tput sgr0



# Change evmosd ports
#stop evmosd
systemctl stop evmosd

#change ports
echo "export G_PORT="17"" >> $HOME/.bash_profile
source $HOME/.bash_profile

sed -i.bak -e "s%:1317%:${G_PORT}317%g;
s%:8080%:${G_PORT}080%g;
s%:9090%:${G_PORT}090%g;
s%:9091%:${G_PORT}091%g;
s%:8545%:${G_PORT}545%g;
s%:8546%:${G_PORT}546%g;
s%:6065%:${G_PORT}065%g" $HOME/.evmosd/config/app.toml

sed -i.bak -e "s%:26658%:${G_PORT}658%g;
s%:26657%:${G_PORT}657%g;
s%:6060%:${G_PORT}060%g;
s%:26656%:${G_PORT}656%g;
s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${G_PORT}656\"%;
s%:26660%:${G_PORT}660%g" $HOME/.evmosd/config/config.toml

sed -i -e 's/address = "127.0.0.1:17545"/address = "0.0.0.0:17545"/' -e 's/ws-address = "127.0.0.1:17546"/ws-address = "0.0.0.0:17546"/' $HOME/.evmosd/config/app.toml

sudo ufw allow 17545
sudo ufw allow 17546


# Restart evmosd service
sudo systemctl restart evmosd

# Setup EigenDA Keys
cd ~
wget https://github.com/airchains-network/tracks/releases/download/v0.0.2/eigenlayer
chmod +x ./eigenlayer
./eigenlayer operator keys create --key-type ecdsa myEigenDAKey

#------------------------------------------------------
elif [ "$choice" == "2" ]; then
    echo "Part 2 Runing..."

sudo rm -rf ~/.tracks
cd
cd tracks
go mod tidy


	# Prompt the user for their Eigen wallet address
read -p "${txtwht}Enter your Eigen wallet address (EVM): " EIGEN_WALLET


# Run the initialization command
go run cmd/main.go init \
    --daRpc "disperser-holesky.eigenda.xyz" \
    --daKey "$EIGEN_WALLET" \
    --daType "eigen" \
    --moniker "mySequencer" \
    --stationRpc "http://127.0.0.1:17545" \
    --stationAPI "http://127.0.0.1:17545" \
    --stationType "evm"

# Make the airchain account keys
go run cmd/main.go keys junction \
    --accountName mySequencerAccount \
    --accountPath $HOME/.tracks/junction-accounts/keys

# Add a temporary pause (until the user presses Enter)
read -p "${txtwht}Copy detail airchain wallet and get faucet and Press Enter to continue..."
tput sgr0
# Run the prover command
go run cmd/main.go prover v1EVM

# Display the node ID from sequencer.toml
cat ~/.tracks/config/sequencer.toml | grep node_id
read -p "${txtwht}Copy Node_id and Press Enter to continue..."
tput sgr0
# Create a station for EVM Track
read -p "${txtwht}Enter your airchain wallet address: " TRACKER_WALLET
tput sgr0
read -p "${txtwht}Enter the Node ID : " NODE_ID
tput sgr0
go run cmd/main.go create-station \
    --accountName mySequencerAccount \
    --accountPath $HOME/.tracks/junction-accounts/keys \
    --jsonRPC "https://junction-testnet-rpc.synergynodes.com/" \
    --info "EVM Track" \
    --tracks $TRACKER_WALLET \
    --bootstrapNode "/ip4/127.0.0.1/tcp/2300/p2p/$NODE_ID"

# Create and enable the systemd service for stationd
sudo tee /etc/systemd/system/stationd.service > /dev/null << EOF
[Unit]
Description=station track service
After=network-online.target
[Service]
User=root
WorkingDirectory=/root/tracks/
ExecStart=/usr/local/go/bin/go run cmd/main.go start
Restart=always
RestartSec=3
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

# Enable and restart the service
sudo systemctl enable stationd
sudo systemctl restart stationd

# Display logs for the stationd service
sudo journalctl -u stationd -f --no-hostname -o cat

elif [ "$choice" == "3" ]; then
    echo "Setup Auto Tx Runing...."


sudo apt-get install git

VERSION="1.21.6"
ARCH="amd64"
curl -O -L "https://golang.org/dl/go${VERSION}.linux-${ARCH}.tar.gz"
tar -xf "go${VERSION}.linux-${ARCH}.tar.gz"
sudo chown -R root:root ./go
sudo mv -v go /usr/local
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
source ~/.bash_profile
go version

git clone https://github.com/sarox0987/evmos-farmer.git
cd evmos-farmer

screen -S tx

go mod tidy
go run main.go

else
    echo "Wrong number ! please select 1 or 2 or 3."
fi

#TheEND !

```
و در اخر هم دکمه ترکیبی ctrl+x بعد y بعد هم اینتر رو بزنید که ذخیره بشه بعد با دستور زیر اجراش کنید


    nano airchain-install.sh
    
![image](https://github.com/user-attachments/assets/5f1f4efd-799b-4c5a-83ad-203e5dfa20eb)





