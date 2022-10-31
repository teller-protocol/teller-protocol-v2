#!/bin/bash

path=$(dirname "$0")
$path/build.sh "$@" && $path/deploy.sh "$@"
