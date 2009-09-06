#!/bin/bash

# How often the daemon loops
readonly POOLINGINTERVAL=1
# How far back we look (in seconds) in the system log
readonly SYSLOGLOOKBACKSECONDS=5
# Sending proces that we're concerned with
readonly SYSLOGSENDER="com.apple.backupd"
# How often we requery the system log when looking for setup data.
readonly SYSLOGREQUERYFORSETUP=60
# Path to user profile
readonly PROFILEPATH="$HOME/.profile"

# Query the system log to find the hostname of target.
function getTargetHostFromSystemLog {
  target_hostname=`syslog -k Sender com.apple.backupd |
    grep 'Attempting to mount network destination using URL' |
    tail -n 1 |
    perl -wlne 'print $1 if /@([a-zA-Z\-]*)/'`
    if [ -n "$target_hostname" ]
    then
      target_hostname="$target_hostname.local"
      return 1
    else
      echo "No backup host was found in your system log. Don't worry - this just means that it was"
      echo "cleared recently. Please run Time Machine (let it fail) and then run this tool again."
      return 0
    fi
}

# Ping the target host to get its IP.
function getTargetIPFromHost {
  target_ip=`ping -c 1 $target_hostname |
    grep 'PING' |
    perl -wlne 'print $1 if /\(([\d\.]*)\)/'`
  if [ -n "$target_ip" ]
  then
    return 1
  else
    echo "We weren't able to ping your target machine, $target_hostname. If it's sleeping, please"
    echo "wake it up and try running setup again."
    return 0
  fi
}

# Query the address resolution protocoal cache from our recent ping to find the MAC address of our target.
function getTargetMACFromARPCache {
  target_mac=`arp -a |
    grep $target_ip |
    perl -wlne 'print $1 if /at\ (.*)\ on\ /'`
  if [ -n "$target_mac" ]
  then
    return 1
  else
    echo "We weren't able to get your target's MAC address from the ARP cache. You may need to"
    echo "specify it manually in your hostdata file."
    return 0
  fi
}

# Write our variables to the user profile.
function SaveTargetDataToUserProfile {
  echo Writing to "$PROFILEPATH"
  echo >> "$PROFILEPATH"
  echo \# Wake Machine configuration, added on `date` >> "$PROFILEPATH"
  echo export WAKEMACHINE_TARGET_HOSTNAME="$target_hostname" >> "$PROFILEPATH"
  echo export WAKEMACHINE_TARGET_IP="$target_ip" >> "$PROFILEPATH"
  echo export WAKEMACHINE_TARGET_MAC="$target_mac" >> "$PROFILEPATH"
  echo \# End of Wake Machine configuration >> "$PROFILEPATH"
  echo Reloading profile
  source "$PROFILEPATH"
}

# Look at the system log to see if we have an intercept on a given message.
# $1: The message we're trying to intercept, we're querying for.
function ReadSystemLogForIntercept {
  results=`syslog -k Sender "$SYSLOGSENDER" -k Time gt -"$SYSLOGLOOKBACKSECONDS"s -k Message Seq "$1"`
  # If we got results, we have an intercept.
  if [ -n "$results" ]
  then
    return 1
  else
    # Otherwise no intercept.
    return 0
  fi
}

# If user invoked setup mode, run setup.
if [ "$1" == "setup" ]
then
  getTargetHostFromSystemLog
  if [ $? -eq 0 ]
  then
    exit
  fi
  echo Target hostname: $target_hostname
  getTargetIPFromHost
  if [ $? -eq 0 ]
  then
    exit
  fi
  echo Target IP: $target_ip
  getTargetMACFromARPCache
  if [ $? -eq 0 ]
  then
    exit
  fi
  echo Target MAC: $target_mac
  echo Saving data...
  SaveTargetDataToUserProfile
  echo Done.
else
# Otherwise, run daemon
  # Begin daemon
  while true
  do
    ReadSystemLogForIntercept "Starting standard backup"
    if [ $? -eq 1 ]
    then
      echo We have an intercept!
    else
      echo No intercept.
    fi
    sleep $POOLINGINTERVAL
  done
fi