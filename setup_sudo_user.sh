#!/bin/bash
set -x #echo on

sudo adduser $1
sudo usermod -aG sudo $1s