#!/bin/bash
# Copyright (c) 2014, 2015, Chris Abela, Malta
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# * Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# This script generates random MAC address for network interface(s)
# Usage: random-mac-generator.sh <interface-name(s)>
# If no arguments are given the scipt will change the MAC address of all interface(s)
# If you installed wireshark, this script will attempt to change also the OUI
# by reading /usr/share/wireshark/manuf. You may pass an alternative MANUF variable
# to this script.
# This script must be called with root privileges

function get_interface_list () {
  INTERFACES=$( /sbin/ifconfig -a | grep 'flags' | grep -v '^lo:' | sed 's/:.*//g' )
}

function get_mac() {
  MAC=$( /sbin/ifconfig $1 | awk '/ether/{print$2}' )
  MAC=$( echo "$MAC" | tr '[:lower:]' '[:upper:]' ) # Upper case conversion for MAC
  if [ -z "$MAC" ]; then
    echo "MAC address for interface $1 was not found"
    return 1
  fi
}

function generate_random_OUI () {
  # Make a list of all OUI (first 3 octets of all MAC addresses)
  MANUF=${MANUF:-/usr/share/wireshark/manuf} # Consider alternative MANUF if passed to this script
  if [ -r $MANUF ]; then # if MANUF was found we use it
    # Clean MANUF
    NO_OF_OUI=$( grep '^[[:digit:]].:' $MANUF | grep -v "/36" | wc -l )
    let "NO_OF_OUI+=1" # Add one to NO_OUI to include also the last line as an option
    OUI=$(( $RANDOM%$NO_OF_OUI )) # MAX[$RANDOM] (32K) > $NO_OF_OUI (~16K) is confirmed
    # We compute this once:
    CHOSEN_LINE=$( grep '^[[:digit:]].:' $MANUF | grep -v "/36" | sed -n "${OUI}p" )
    RANDOM_OUI=$( echo $CHOSEN_LINE | awk '{print $1}' )
    MANUFACTURER=$( echo $CHOSEN_LINE | awk '{print $2}' )
  else # MANUF was not found therefore we keep the same OUI
    RANDOM_OUI=$( echo "$MAC" | cut -d: -f1-3 )
    return 2 # OUI is not random
  fi
}

function generate_random_NIC () {
  # Define first three MAC address octets and convert random numbers to hex values
  NICA=$RANDOM
  NICB=$RANDOM
  NICC=$RANDOM
  let "NICA %= 256"
  let "NICB %= 256"
  let "NICC %= 256"
  OCTETA=`echo "obase=16;$NICA" | bc`
  OCTETB=`echo "obase=16;$NICB" | bc`
  OCTETC=`echo "obase=16;$NICC" | bc`
  # Ensure that all OCTET have at least 2 digits
  [ $( echo $OCTETA | wc -c ) -eq 2 ] && OCTETA=0${OCTETA}
  [ $( echo $OCTETB | wc -c ) -eq 2 ] && OCTETB=0${OCTETB}
  [ $( echo $OCTETC | wc -c ) -eq 2 ] && OCTETC=0${OCTETC}
}

function main () {
  LOG_FILE=${LOG_FILE:-/var/log/random-mac-generator.log}
  get_mac $IFACE
  if [ "$?" -ne 1 ]; then # A MAC address for $IFACE was found
    generate_random_OUI
    generate_random_NIC
    NEW_MAC_ADDRESS="${RANDOM_OUI}:${OCTETA}:${OCTETB}:${OCTETC}"
    DATE=$( date | awk '{print $2,$3,$4}' )
    touch $LOG_FILE
    chmod 600 $LOG_FILE
    echo "$DATE The original $IFACE MAC address was $MAC" | tee -a $LOG_FILE
    echo "  Now is: $NEW_MAC_ADDRESS" | tee -a $LOG_FILE
    [ -n "$MANUFACTURER" ] && echo "  Manufacturer: $MANUFACTURER" | tee -a $LOG_FILE
    echo "  /sbin/ifconfig $IFACE hw ether $NEW_MAC_ADDRESS" | tee -a $LOG_FILE
    /sbin/ifconfig $IFACE down
    /sbin/ifconfig $IFACE hw ether "$NEW_MAC_ADDRESS"
    /sbin/ifconfig $IFACE up
  fi
}

get_interface_list
if [ $# == 0 ]; then
  # No arguments have been entered, so I assume that you want all interfaces
  for IFACE in $INTERFACES; do
    main 
  done
  else # User made network interface(s) selection
  for IFACE in "$@"; do
    # check if the entered interface exist
    if  eval echo "$IFACE" | grep "$INTERFACES" -wq; then
      main
    else echo "Interface $IFACE is not found"
    fi
  done
fi
