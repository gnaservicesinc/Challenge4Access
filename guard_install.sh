#!/bin/bash

sudo cp "/Users/andrewsmith/Desktop/projects/sensuser/Challenge4Access/Challenge4Access/Guard/Guard/Guard" "/opt/c4a/bin/Guard"

make install DESTDIR="/opt/c4a"
sudo chown "ryan" "/opt/c4a/bin/Guard"
sudo chmod u+s "/opt/c4a/bin/Guard"
