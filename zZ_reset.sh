#!/usr/bin/env bash

printf "***************************************************************************\n"
printf "*** WARNING *** WARNING *** WARNING *** WARNING *** WARNING *** WARNING ***\n"
printf "***************************************************************************\n\n"
echo -n "Do you want to reset the 'mynetwork' directory? (y/n)? "
read response
echo    # (optional) move to a new line
if [[ $response =~ ^[Yy]$ ]]
then
    echo "Blowing away the 'mynetwork' directory..."
    rm -rf mynetwork
    echo "... GONE!"
else
    echo "NOOP"
fi