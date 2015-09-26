random-mac-generator
====================

A BASH script to generate random MAC address for network interface(s)

Usage: random-mac-generator.sh <interface-name(s)>

If you installed wireshark, this script will attempt to change also the OUI
by reading /usr/share/wireshark/manuf. You may pass an alternative MANUF variable
to this script.

This script must be called with root privileges
