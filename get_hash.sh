#!/bin/bash

function get_hash_512_bin {
      echo -n "$@" | /usr/bin/shasum -b -a 512
}

function get_hash_512 {
      echo -n "$@" | /usr/bin/shasum -a 512
}
function get_md5 {
    echo -n "$@" | md5
}
get_hash_512 "$@"
