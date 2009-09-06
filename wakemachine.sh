#!/bin/bash

# How often the daemon loops
readonly POOLINGINTERVAL=1
# How far back we look (in seconds) in the system log
readonly SYSLOGLOOKBACKSECONDS=5
# Sending proces that we're concerned with
readonly SYSLOGSENDER="com.apple.backupd"

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