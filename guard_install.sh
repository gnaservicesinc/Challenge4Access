#!/bin/bash



sudo chown "guard" "/opt/c4a/bin/Guard"
sudo chmod u+s "/opt/c4a/bin/Guard"
sudo xattr -rds com.apple.quarantine "/opt/c4a"
