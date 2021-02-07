#!/usr/bin/env expect
set timeout -1
set username [lindex $argv 0];
spawn bash /home/$username/SteamCMD/steamcmd.sh
expect "Steam>"
send "login anonymous\r"
expect "Steam>"
send "force_install_dir /home/$username/hlds\r"
expect "Steam>"
send "app_update 90 validate\r"
expect "Steam>"
send "app_update 90 validate\r"
expect "Steam>"
send "app_update 90 validate\r"
expect "Steam>"
send "quit\r"
expect eof
