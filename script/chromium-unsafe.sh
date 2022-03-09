#!/bin/bash
chromium --remote-debugging-port=9222 --disable-web-security --user-data-dir=/home/timon/unsecure-google-user-data-dir $1
