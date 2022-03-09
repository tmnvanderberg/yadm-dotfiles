#!/bin/bash
pushd ~/script/
./chromium-unsafe.sh http://localhost:8100/ &
popd
