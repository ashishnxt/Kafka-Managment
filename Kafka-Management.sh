#!/bin/bash

# Function to show Kafka version
show_kafka_version() {
    echo "Checking Kafka version..."
    if [[ -x "/home/kafka/bin/kafka-topics.sh" ]]; then
        /home/kafka/bin/kafka-topics.sh --version
    else
        echo "Kafka not found (bin/kafka-topics.sh missing or not executable)"
    fi
    echo ""
    echo "Press any key to continue to menu..."
    read -n1 -s
}



# Menu options
options=(
  "[+] Install Kafka 4.0.0"
  "[+] Install Kafka 3.3.1"
  "[+] Restore Setup 3.3.1"
  "[+] Backup Kafka  3.3.1"
  "[+] Uninstall Kafka"
  "[+] Exit"
  
)
selected=0

# Hide cursor
tput civis

# Function to draw the menu
draw_menu() {
    clear
    echo "  [+] Kafka Manager -by Ashish"
    for i in "${!options[@]}"; do
        if [ "$i" -eq "$selected" ]; then
            echo -e "> \e[1;32m${options[$i]}\e[0m"
        else
            echo "  ${options[$i]}"
        fi
    done
}

# Show Kafka version first
show_kafka_version

# Menu loop
while true; do
    draw_menu

    # Read user key
    read -rsn1 key

    if [[ $key == $'\x1b' ]]; then
        read -rsn2 -t 0.1 key
        case $key in
            "[A") ((selected--));;  # Up
            "[B") ((selected++));;  # Down
        esac
    elif [[ $key == "" ]]; then
        break  # Enter pressed
    fi

    # Wrap selection
    ((selected < 0)) && selected=$((${#options[@]} - 1))
    ((selected >= ${#options[@]})) && selected=0
done

# Show cursor again
tput cnorm
clear

# Handle selection
case $selected in


0)
    echo "Installing Kafka 4.0..."
    # === Add your Kafka 4.0 install logic here ===


        #!/bin/bash

set -e

KAFKA_VERSION="4.0.0"
SCALA_VERSION="2.13"
INSTALL_DIR="/home/kafka"
TARBALL_NAME="kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"
EXTRACTED_DIR="kafka_${SCALA_VERSION}-${KAFKA_VERSION}"
KAFKA_REAL_VERSION=/home/kafka/bin/kafka-topics.sh

# Check if Kafka is already installed and running
if systemctl is-active --quiet kafka && [[ -x "$INSTALL_DIR/bin/kafka-server-start.sh" ]]; then
  echo "[✓] Kafka is already installed and running. Skipping installation."
  echo "Kafka Version: $(/home/kafka/bin/kafka-topics.sh --version)"
  exit 0
fi

echo "[*] Starting Kafka $KAFKA_VERSION installation into $INSTALL_DIR..."

# Check if kafka user exists
if id "kafka" &>/dev/null; then
  echo "[!] User 'kafka' already exists, skipping user creation."
else
  echo "[+] Creating user 'kafka'..."
  useradd -m -s /bin/bash kafka
fi

# Ensure /home/kafka exists
echo "[+] Creating installation directory..."
mkdir -p "$INSTALL_DIR"

# Check for Kafka tarball in current directory
if [ ! -f "$TARBALL_NAME" ]; then
  echo "[✗] ERROR: Kafka tarball '$TARBALL_NAME' not found in current directory."
  exit 1
fi

echo "[+] Extracting Kafka into $INSTALL_DIR..."
tar -xzf "$TARBALL_NAME" -C "$INSTALL_DIR" --strip-components=1

echo "[+] Writing configuration to server.properties..."
cat > "$INSTALL_DIR/config/server.properties" <<EOF
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# This configuration file is intended for use in KRaft mode, where
# Apache ZooKeeper is not present.  See config/kraft/README.md for details.
#

############################# Server Basics #############################

# The role of this server. Setting this puts us in KRaft mode
process.roles=broker,controller

# The node id associated with this instance's roles
node.id=1

# The connect string for the controller quorum
controller.quorum.voters=1@127.0.0.1:9094

############################# Socket Server Settings #############################

# The address the socket server listens on.
listeners=PLAINTEXT://localhost:9092,CONTROLLER://localhost:9094

# Name of listener used for communication between brokers.
inter.broker.listener.name=PLAINTEXT

# Listener name, hostname and port the broker will advertise to clients.
advertised.listeners=PLAINTEXT://127.0.0.1:9092

# A comma-separated list of the names of the listeners used by the controller.
controller.listener.names=CONTROLLER

# Maps listener names to security protocols
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL

# Thread configuration
num.network.threads=3
num.io.threads=8

# Socket buffer sizes
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600

############################# Log Basics #############################

log.dirs=/mnt/kafka/kafka-logs
num.partitions=1
num.recovery.threads.per.data.dir=1

############################# Internal Topic Settings #############################
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1

############################# Log Retention Policy #############################

log.retention.hours=168
log.retention.bytes=50000000
log.segment.bytes=50000000
log.retention.check.interval.ms=300000
EOF

echo "[!] Cleaning previous logs if they exist..."
rm -rf /mnt/kafka/kafka-logs

echo "[+] Formatting storage directory for KRaft..."
"$INSTALL_DIR/bin/kafka-storage.sh" format -t "$(uuidgen)" -c "$INSTALL_DIR/config/server.properties"

echo "[+] Setting permissions to kafka user..."
chown -R kafka:kafka "$INSTALL_DIR"
mkdir -p /mnt/kafka/kafka-logs
chown -R kafka:kafka /mnt/kafka/kafka-logs

echo "[+] Creating systemd service for Kafka..."
cat > /etc/systemd/system/kafka.service <<EOF
[Unit]
Description=Apache Kafka Server (KRaft mode)
After=network.target

[Service]
User=kafka
Group=kafka
ExecStart=$INSTALL_DIR/bin/kafka-server-start.sh $INSTALL_DIR/config/server.properties
Restart=on-failure
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Reloading systemd daemon..."
systemctl daemon-reexec
systemctl daemon-reload

echo "[+] Enabling and starting Kafka service..."
systemctl enable kafka
systemctl start kafka

echo "[✓] Kafka $KAFKA_VERSION is now installed and running as a service!"
echo "[→] Check status: systemctl status kafka"



        ;;
    1)
        echo "Installing Kafka 3.0..."
        # === Add your Kafka 3.0 install logic here ===
        
#!/bin/bash
####################### Setup-of-kafka-without-zookeeper ########################################## 
#
########### This script must be run as root ###################

BASEDIR=$(dirname $0)
#echo ${BASEDIR:0:1}
if [ $BASEDIR == "." ]; then
        BASEDIR="$PWD/"
        echo "we are in if condition" $BASEDIR
elif [ ${BASEDIR:0:1} == "/" ]; then
        BASEDIR="$BASEDIR/"
else
        BASEDIR="$PWD/$BASEDIR/"
        echo "we are outside if condition" $BASEDIR
fi

if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1

fi
#############################################

########### Firstly we have to check old kafka exist or not , if yes so we need to remove it first with zookeeper ########

if grep -iq kraft /etc/systemd/system/kafka.service; then
    echo "Found 'kraft' in /etc/systemd/system/kafka.service. Exiting script."
    exit 1
fi
#
# Step 1 : Stop the services 
systemctl stop kafka.service zookpeeper.service
systemctl disable zookpeeper.service


# Step 2 : Remove the old kafka folder 
cd /home/kafka/
rm -rf kafka 

sleep 1

# Step 3 : Remove the old log path 
cd /mnt/Restore/
rm -rf kafka-logs

sleep 1

# Step 4 : Empty the Kafka service file
truncate -s 0 /etc/systemd/system/kafka.service


# Step 5: Install Java Runtime Environment
apt-get install -y default-jre

# Step 6: Download Kafka
cd /tmp
wget https://archive.apache.org/dist/kafka/3.3.1/kafka_2.13-3.3.1.tgz
# If above link is not woking in that case you will take the tgz from the below path of nfs 
#/nfs/nasVehiScanSupport/Vehiscan/Chhavi/kafka_2.13-3.3.1.tgz

# Step 7: Unarchive Kafka, switch to root, create user and data directory
#mkdir -p /home/kafka
tar -xzvf kafka_2.13-3.3.1.tgz
#useradd -m -s /bin/bash kafka
sudo useradd -u 15008 -m -s /bin/bash kafka

# Stfep 8: Change the Kafka folder name and also change the ownership
mv kafka_2.13-3.3.1 kafka 
rsync -arvP kafka /home/
chown kafka. -R /home/kafka/ 

cd /home/kafka/
# Step 9: Generate cluster ID (One time generating)
CLUSTER_ID=$(./bin/kafka-storage.sh random-uuid)

# Step 10: Prompt the user to enter IP address and retrieve the hostname
#read -p "Enter hostname for Kafka server: " KAFKA_HOSTNAME
read -p "Enter IP address for Kafka server: " KAFKA_IP
KAFKA_HOSTNAME=localhost

#AUTO_IP=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
#echo " $AUTO_IP detected"
#        KAFKA_IP=$AUTO_IP
#        echo "Setting $KAFKA_IP"

# Step 11: Replace placeholders with user input in server.properties file
sed -i "s/^controller.quorum.voters=.*$/controller.quorum.voters=1@${KAFKA_IP}:9094/" /home/kafka/config/kraft/server.properties
sed -i "s/^listeners=.*$/listeners=PLAINTEXT:\/\/${KAFKA_HOSTNAME}:9092,CONTROLLER:\/\/${KAFKA_HOSTNAME}:9094/" /home/kafka/config/kraft/server.properties
sed -i "s/^advertised.listeners=.*$/advertised.listeners=PLAINTEXT:\/\/${KAFKA_IP}:9092/" /home/kafka/config/kraft/server.properties

# Read log directory path for Kafka
echo "Log path should be /mnt/Restore/kafka-logs"
read -p "Enter log directory path for Kafka :" log_dirs
mkdir /mnt/Restore/kafka-logs

# Set the new log directory path in the Kafka server properties file
sed -i "s|^log.dirs=.*|log.dirs=${log_dirs}|" /home/kafka/config/kraft/server.properties

# Set new values for the properties
log_retention_bytes="50000000"
log_segment_bytes="50000000"

# Set the new values in the Kafka server properties file
sed -i "s|^#log.retention.bytes=.*|log.retention.bytes=${log_retention_bytes}|" /home/kafka/config/kraft/server.properties
sed -i "s|^log.segment.bytes=.*|log.segment.bytes=${log_segment_bytes}|" /home/kafka/config/kraft/server.properties

sleep 1

# Step 12: Format Storage Directories
./bin/kafka-storage.sh format -t $CLUSTER_ID -c ./config/kraft/server.properties
#./bin/kafka-storage.sh format -t $CLUSTER_ID -c ./config/kraft/broker.properties
#./bin/kafka-storage.sh format -t $CLUSTER_ID -c ./config/kraft/controller.properties

systemctl daemon-reload

# Step 13: Start Kafka server
#cd /home/kafka/kafka
#./bin/kafka-server-start.sh config/kraft/server.properties --pid-file /var/run/kafka-server.pid &

#sleep 3

#kill $(cat /var/run/kafka-server.pid)

# Step 14: Create Topics (Optional)
# ./bin/kafka-topics.sh --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1 --topic your_topic_name

# Step 15: Create systemd service file for Kafka
cat <<EOF > /etc/systemd/system/kafka.service
[Unit]
Description=Apache Kafka - Raft Mode
After=network.target

[Service]
Type=simple
User=kafka
ExecStart=/home/kafka/bin/kafka-server-start.sh /home/kafka/config/kraft/server.properties

Restart=always
TimeoutStopSec=5
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Set permission of this file /etc/systemd/system/kafka.service
chown root. /etc/systemd/system/kafka.service

chown kafka. -R /mnt/Restore/kafka-logs
# Step 16: Start,status and enable Kafka service
sudo systemctl start kafka.service

sudo systemctl enable kafka.service
sudo systemctl status kafka.service



        ;;
2)
echo "Restoring Kafka setup..."
    # === Add your restore logic here ===
    #!/bin/bash

# Ask user for the backup path
read -p "Enter the full path to the Kafka backup directory (e.g. kafka-backup-2025-04-02_12-43-04): " BACKUP_PATH

# Stop Kafka service
echo "Stopping Kafka service..."
sudo systemctl stop kafka.service

# Kafka installation restore
echo "Restoring Kafka installation..."
tar -xzvf "$BACKUP_PATH/kafka-install.tar.gz" -C /home

# Kafka configuration restore
echo "Restoring Kafka configuration..."
tar -xzvf "$BACKUP_PATH/kafka-config.tar.gz" -C /home/kafka

# Kafka logs restore
echo "Restoring Kafka logs..."
tar -xzvf "$BACKUP_PATH/kafka-logs.tar.gz" -C /root/kafka/kafka-logs
tar -xzvf "$BACKUP_PATH/kafka-logs.tar.gz" -C /mnt/Restore/kafka-logs

# Kafka systemd service file restore
echo "Restoring Kafka systemd service file..."
sudo cp "$BACKUP_PATH/kafka.service.bak" /etc/systemd/system/kafka.service

# Reload systemd and start Kafka
echo "Reloading systemd and starting Kafka service..."
sudo systemctl daemon-reload
sudo systemctl start kafka.service

echo "Kafka restore complete."

        ;;




3)
    echo "Backing up Kafka..."
    # === Add your backup logic here ===
 #!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Define backup directory relative to script location
BACKUP_DIR="${SCRIPT_DIR}/kafka-backup-$(date +%F_%H-%M-%S)"
KAFKA_DIR="/home/kafka"
KAFKA_CONFIG="${KAFKA_DIR}/config"
KAFKA_LOGS="/mnt/Restore/kafka-logs"
SYSTEMD_SERVICE="/etc/systemd/system/kafka.service"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Stopping Kafka service..."
if ! systemctl stop kafka.service; then
  echo "Failed to stop Kafka service. Aborting backup."
  exit 1
fi

# Backup Kafka installation
echo "Backing up Kafka installation..."
tar -czvf "$BACKUP_DIR/kafka-install.tar.gz" -C "/home" kafka

# Backup Kafka configuration
echo "Backing up Kafka configuration..."
tar -czvf "$BACKUP_DIR/kafka-config.tar.gz" -C "$KAFKA_DIR" config

# Backup Kafka logs (topics data)
echo "Backing up Kafka logs..."
tar -czvf "$BACKUP_DIR/kafka-logs.tar.gz" -C "$KAFKA_LOGS" .

# Backup systemd service file
echo "Backing up Kafka service file..."
cp "$SYSTEMD_SERVICE" "$BACKUP_DIR/kafka.service.bak"

echo "Kafka backup completed successfully."
echo "Backup stored in: $BACKUP_DIR"

# Restart Kafka service
echo "Starting Kafka service..."
if ! systemctl start kafka.service; then
  echo "Warning: Failed to start Kafka service after backup."
  exit 1
fi

        ;;





4)
    echo "Uninstalling Kafka..."
    # === Add your uninstall logic here ===
#!/bin/bash

KAFKA_DIR="/home/kafka"
KAFKA_LOG_DIR="/home/kafka/kafka-logs"
KAFKA_SERVICE="/etc/systemd/system/kafka.service"
KAFKA_VERSION_CMD="/home/kafka/bin/kafka-topics.sh"
KAFKA_TMP_LOG="/mnt/Restore/kraft-combined-logs"



# Check if kafka-topics.sh exists
if [ -f "$KAFKA_VERSION_CMD" ]; then
    VERSION_OUTPUT=$($KAFKA_VERSION_CMD --version 2>/dev/null)
    echo "Detected Kafka version: $VERSION_OUTPUT"

    # Ask for user confirmation
    read -p "Do you want to uninstall Kafka version shown above? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo "Uninstallation aborted by user."
        exit 0
    fi
else
    echo "Kafka not found or kafka-topics.sh does not exist."
    exit 1
fi

# Stop Kafka if running
KAFKA_PROCESS=$(ps aux | grep 'kafka.Kafka' | grep "$KAFKA_DIR")
if [ -n "$KAFKA_PROCESS" ]; then
    echo "Kafka is running. Attempting to stop it..."
    KAFKA_PID=$(echo "$KAFKA_PROCESS" | awk '{print $2}')
    kill "$KAFKA_PID"
    echo "Waiting for Kafka process to stop..."
    sleep 5
    if ps -p "$KAFKA_PID" > /dev/null; then
        echo "Kafka did not stop gracefully. Killing it forcefully."
        kill -9 "$KAFKA_PID"
    else
        echo "Kafka stopped successfully."
    fi
else
    echo "Kafka is not running via process."
fi

# Stop and remove systemd service
if systemctl list-units --full -all | grep -q "kafka.service"; then
    echo "Stopping and disabling kafka.service..."
    sudo systemctl stop kafka.service
    sudo systemctl disable kafka.service
    if [ -f "$KAFKA_SERVICE" ]; then
        sudo rm "$KAFKA_SERVICE"
        echo "Removed kafka.service file."
    fi
    sudo systemctl daemon-reload
    echo "Systemd daemon reloaded."
fi

# Remove Kafka directory
if [ -d "$KAFKA_DIR" ]; then
    echo "Removing Kafka installation at $KAFKA_DIR..."
    rm -rf "$KAFKA_DIR"
fi

# Remove Kafka logs
if [ -d "$KAFKA_LOG_DIR" ]; then
    echo "Removing Kafka log directory at $KAFKA_LOG_DIR..."
    rm -rf "$KAFKA_LOG_DIR"
fi

echo "Kafka and its logs have been completely uninstalled."



# Remove Kafka logs
if [ -d "$KAFKA_TMP_LOG" ]; then
    echo "Removing Kafka log directory at $KAFKA_TMP_LOG..."
    rm -rf "$KAFKA_TMP_LOG"
fi

echo "Kafka and its logs have been completely uninstalled."
            
;;

   5)
        echo "Exiting... Goodbye!"
        exit 0
        ;;
   
esac



