#!/bin/bash



sudo chown -R "guard" "/opt/c4a"
sudo chmod u+s "/opt/c4a/bin/Guard"
sudo xattr -rds com.apple.quarantine "/opt/c4a"
