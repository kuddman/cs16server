#!/bin/bash
#change current path to path of script file
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path"

#prerequisites
#set name of user (that has already been created in the system)
user_name="cs16server"
#ip of machine
ip="192.168.0.1"
#desired port for server (27015 is standard)
port="27015"
#maxplayers of server
max_players="13"

#optional varsapt
#hltv port, needs to be different from $port
hltvport=""
#set server password; "" for no password
server_password=""

#if no port set, use standard port
if [ "$port" = "" ]; then
    port="27015"
fi

#install required binaries and libs
#screen is not mandatory but if you leave it out, remove "screen -d -S '$user_name' -m " in the runhlds and runhltv files; rest is mandatory
sudo dpkg --add-architecture i386
sudo apt update -y
sudo apt install -y lib32gcc1 lib32z1 lib32stdc++6 libsdl2-2.0-0 expect screen
sudo apt update -y

#download steam
sudo mkdir /home/$user_name/SteamCMD
sudo wget http://media.steampowered.com/client/steamcmd_linux.tar.gz -P /home/$user_name/SteamCMD/
sudo tar xfz /home/$user_name/SteamCMD/steamcmd_linux.tar.gz -C /home/$user_name/SteamCMD/
sudo rm /home/$user_name/SteamCMD/steamcmd_linux.tar.gz
sudo chmod 755 /home/$user_name/SteamCMD/steamcmd.sh

#setup steam and install cs16 server
sudo \cp ./steam_setup.sh /home/$user_name/steam_setup.exp
sudo chmod a+x /home/$user_name/steam_setup.exp
sudo chown -R $user_name:$user_name /home/$user_name/

#steam_setup.exp is an expect script that fills in the required details during the steam installation process.
#it is renamed from *.sh to *.exp because my git somehow can't deal with *.exp files
sudo -i -u $user_name chmod +x /home/$user_name/steam_setup.exp
sudo -i -u $user_name chmod +x /home/$user_name/SteamCMD/steamcmd.sh
sudo -i -u $user_name /home/$user_name/steam_setup.exp $user_name

sudo mkdir /home/$user_name/.steam
sudo ln -s /home/$user_name/SteamCMD/linux32 /home/$user_name/.steam/sdk32
sudo cp /home/$user_name/hlds/libsteam.so /home/$user_name/.steam/sdk32/
sudo touch /home/$user_name/hlds/cstrike/listip.cfg
sudo touch /home/$user_name/hlds/cstrike/banned.cfg

if [ "$ip" != "" ]; then
  #setup scripts that is run by systemctl service
  #comment out if not wanted
  sudo echo '#!/bin/bash' > /home/$user_name/runhlds.sh
  sudo echo 'cd /home/'$user_name'/hlds/' >> /home/$user_name/runhlds.sh
  sudo echo 'screen -d -S '$user_name' -m ./hlds_run -game cstrike -console +ip '$ip' +maxplayers '$max_players' +map de_dust2 -secure -sv_lan 0 -autoupdate -port '$port >> /home/$user_name/runhlds.sh
fi

if [ "$hltvport" != "" ]; then
  sudo echo '#!/bin/bash' > /home/$user_name/runhltv.sh
  sudo echo 'cd /home/'$user_name'/hlds/' >> /home/$user_name/runhltv.sh
  sudo echo 'screen -d -S '$user_name'hltv -m ./hltv -port '$hltvport' +exec hltv.cfg' >> /home/$user_name/runhltv.sh
fi

#setup hltv configs; steamclient.so and libsteam_api.so need to go to /usr/lib, otherwise no start
sudo \cp -r ./hltv.cfg /home/$user_name/hlds/
sudo cp /home/$user_name/hlds/steamclient.so /usr/lib
sudo cp /home/$user_name/hlds/libsteam_api.so /usr/lib
echo 'serverpassword  "'$server_password'"' >> /home/$user_name/hlds/hltv.cfg
echo 'connect '$ip':'$port >> /home/$user_name/hlds/hltv.cfg


#setup cs16 server config and copy maps and extras
\cp -r ./server.cfg /home/$user_name/hlds/cstrike/

echo 'sv_password "'$server_password'"' >> /home/$user_name/hlds/cstrike/server.cfg


#give rights to access everything to local user
chown -R $user_name:$user_name /home/$user_name/
sudo -i -u $user_name chmod +rw /home/$user_name/hlds/cstrike/*
sudo -i -u $user_name chmod +rw /home/$user_name/hlds/cstrike/maps/*
sudo -i -u $user_name chmod +x /home/$user_name/runhlds.sh

if [ "$hltvport" != "" ]; then
  sudo -i -u $user_name chmod +x /home/$user_name/runhltv.sh
fi

#setup cs 1.6 server service files for systemctl
echo '[Unit]' > /etc/systemd/system/$user_name.service
echo 'Description=cs 16 server startup script' >> /etc/systemd/system/$user_name.service
echo 'After=network.target' >> /etc/systemd/system/$user_name.service
echo ' ' >> /etc/systemd/system/$user_name.service
echo '[Service]' >> /etc/systemd/system/$user_name.service
echo 'User='$user_name >> /etc/systemd/system/$user_name.service
echo 'Type=forking' >> /etc/systemd/system/$user_name.service
echo 'ExecStart=/home/'$user_name'/runhlds.sh start' >> /etc/systemd/system/$user_name.service
echo ' ' >> /etc/systemd/system/$user_name.service
echo '[Install]' >> /etc/systemd/system/$user_name.service
echo 'WantedBy=default.target' >> /etc/systemd/system/$user_name.service

#setup hltv server service files for systemctl
echo '[Unit]' > /etc/systemd/system/hltv$user_name.service
echo 'Description=cs 16 hltv startup script' >> /etc/systemd/system/hltv$user_name.service
echo 'After=network.target' >> /etc/systemd/system/hltv$user_name.service
echo ' ' >> /etc/systemd/system/hltv$user_name.service
echo '[Service]' >> /etc/systemd/system/hltv$user_name.service
echo 'User='$user_name >> /etc/systemd/system/hltv$user_name.service
echo 'Type=forking' >> /etc/systemd/system/hltv$user_name.service
echo 'ExecStart=/home/'$user_name'/runhltv.sh start' >> /etc/systemd/system/hltv$user_name.service
echo ' ' >> /etc/systemd/system/hltv$user_name.service
echo '[Install]' >> /etc/systemd/system/hltv$user_name.service
echo 'WantedBy=default.target' >> /etc/systemd/system/hltv$user_name.service

#sets hltv server to start 40 seconds after boot
echo '[Unit]' > /etc/systemd/system/hltv$user_name.timer
echo 'Description=Run hltv server 40 secs after boot' >> /etc/systemd/system/hltv$user_name.timer
echo '[Timer]' >> /etc/systemd/system/hltv$user_name.timer
echo 'OnBootSec=40sec' >> /etc/systemd/system/hltv$user_name.timer
echo '#OnUnitActiveSec=1w' >> /etc/systemd/system/hltv$user_name.timer
echo '[Install]' >> /etc/systemd/system/hltv$user_name.timer
echo 'WantedBy=timers.target' >> /etc/systemd/system/hltv$user_name.timer

#sets cs 1.6 server to start 30 seconds after boot
echo '[Unit]' > /etc/systemd/system/$user_name.timer
echo 'Description=Run cs 1.6 server 40 secs after boot' >> /etc/systemd/system/$user_name.timer
echo '[Timer]' >> /etc/systemd/system/$user_name.timer
echo 'OnBootSec=30sec' >> /etc/systemd/system/$user_name.timer
echo '#OnUnitActiveSec=1w' >> /etc/systemd/system/$user_name.timer
echo '[Install]' >> /etc/systemd/system/$user_name.timer
echo 'WantedBy=timers.target' >> /etc/systemd/system/$user_name.timer

sudo -i -u $user_name chmod a-w /home/$user_name/
#start cs 1.6 services
systemctl enable $user_name.timer
systemctl start $user_name.service

#start hltv services
#set hltvport = "" if not desired
if [ "$hltvport" != "" ]; then
  systemctl enable hltv$user_name.timer
  systemctl start hltv$user_name.service
fi
