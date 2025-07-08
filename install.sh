#!/bin/sh
# Values filled out by the LabTech server when the installer is downloaded.

LT_SERVER_ADDRESS=
LT_SYSTEM_PASSWORD=
LT_LOCATION_ID=

install_dir="/usr/local/ltechagent"
lt_log="/tmp/ltech_install_log.txt"

echo "Installing to $install_dir." >> $lt_log
# Our cwd must be the same as "install.sh".

if [ ! -f ./data/ltechagent ]
then
   echo "Installer must be ran in same directory as script."
    exit 1
fi
#
# Stop the current running agent.
#
systemctl stop ltechagent
#
# Check for legacy agent files and use some of the old config
# values for the new agent.
#
old_agent_registry="/usr/lib/labtech/AgentRegistry"
old_agent_internals="/usr/lib/labtech/AgentInternals"
echo "Checking for legacy agent files." >> $lt_log
if [ ! -f "$old_agent_registry" ] || [ ! -f "$old_agent_internals" ]
then
    old_agent_registry="/tmp/saved_AgentRegistry"
    old_agent_internals="/tmp/saved_AgentInternals"
fi

if [ -f "$old_agent_registry" ] && [ -f "$old_agent_internals" ]
then
    echo "Found legacy agent files - $old_agent_registry, $old_agent_internals" >> $lt_log
    computer_password=""
    computer_id=""
    is_master=""
    echo "Checking for computer id." >> $lt_log
    line=$(grep "computer_id" "$old_agent_registry") || true
    if [ "$line" != "" ]; then
        computer_id=$(echo "$line" | awk -F '=' '{ print $2 }')
    fi
    echo "Checking for computer password." >> $lt_log
    line=$(grep "computer_passkey" "$old_agent_internals") || true
    if [ "$line" != "" ]; then
        computer_password=$(echo "$line" | awk -F '=' '{ print $2 }')
    fi
    echo "Old computer_password: $computer_password" >> $lt_log
    echo "Old computer_id: $computer_id" >> $lt_log
    if [ "$computer_password" != "" ] && [ "$computer_id" != "" ]; then
        echo "Writing new agent state file using legacy agent values." >> $lt_log
        # Write the json state file.
        printf "{" > $install_dir/state
        printf "\"computer_password\":\"$computer_password\"" >> $install_dir/state
        printf "," >> $install_dir/state
        printf "\"computer_id\":$computer_id" >> $install_dir/state
        printf "}" >> $install_dir/state
    fi
fi

#
# Copy the new agent files to the install directory. Set permissions for
# the files we copy.
#
echo "Copying files to install directory." >> $lt_log
mkdir -p "$install_dir"
cp ./data/uninstaller.sh "$install_dir"
rm -f "$install_dir/ltechagent"
cp ./data/ltechagent "$install_dir"
cp ./data/libltech.so "$install_dir"
cp ./data/ltupdate "$install_dir"
echo "Setting permissions." >> $lt_log
chown -R root:root $install_dir
chmod 500 $install_dir/uninstaller.sh
chmod 500 "$install_dir/ltechagent"
chmod 500 "$install_dir/libltech.so"
chmod 500 "$install_dir/ltupdate"

#
# Use the values the LabTech server filled out to setup the config file.
#
agent_config=$install_dir/agent_config
if [ ! -f "$agent_config" ] || [ ! -s "$agent_config" ]; then
    echo "Creating agent_config." >> $lt_log
    echo "server_url $LT_SERVER_ADDRESS" > "$install_dir/agent_config"
    echo "system_password $LT_SYSTEM_PASSWORD" >> "$install_dir/agent_config"
    echo "location_id $LT_LOCATION_ID" >> "$install_dir/agent_config"
    chmod 600 $install_dir/agent_config
fi
#
# Link in our init script.
#
echo "Setting up init scripts." >> $lt_log
cp ./data/ltechagent.service /usr/lib/systemd/system/
systemctl enable ltechagent
systemctl daemon-reload
 
#
# Run the agent.
#
echo "Starting agent." >> $lt_log
systemctl start ltechagent >> $lt_log
echo "Install done." >> $lt_log
exit 0