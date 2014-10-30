#!/bin/bash
# This script generates random MAC address for network interface(s)

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
  # You will need wireshark package for this file
  # Make a list of all OUI (first 3 octets of all MAC addresses)
  if [ -r /usr/share/wireshark/manuf ]; then # if manuf was found we use it
    NO_OF_OUI=$( awk '/^[[:digit:]].:/{print$1}' /usr/share/wireshark/manuf | grep -v '\/36$' | wc -l )
    let "NO_OF_OUI+=1" # Add one to NO_OUI to include also the last line as an option
    OUI=$(( $RANDOM%$NO_OF_OUI )) # MAX[$RANDOM] (32K) > $NO_OF_OUI (~16K) is confirmed
    RANDOM_OUI=$( awk '/^[[:digit:]].:/{print$1}' /usr/share/wireshark/manuf | grep -v '\/36$' | sed -n "${OUI}p" )
    MANUF=$( sed -n "${OUI}p" /usr/share/wireshark/manuf | awk '{print $2}')
  else # manuf was not found therefore we keep the same OUI
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
}

function main () {
  get_mac $IFACE
  if [ "$?" -ne 1 ]; then # A MAC address was for $IFACE was found
    generate_random_OUI
    generate_random_NIC
    NEW_MAC_ADDRESS="${RANDOM_OUI}:${OCTETA}:${OCTETB}:${OCTETC}"
    /sbin/ifconfig $IFACE down
    /sbin/ifconfig $IFACE hw ether "$NEW_MAC_ADDRESS" && echo -n "The original $IFACE MAC address was $MAC and now is: $NEW_MAC_ADDRESS"
    [ -n "$MANUF" ] && echo ", Manufacturer: $MANUF" || echo
    /sbin/ifconfig $IFACE up
  fi
}

get_interface_list
if [ $# == 0 ]; then
  # No arguments have been entered, so I asume that you want all interfaces
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
