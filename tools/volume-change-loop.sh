#!/bin/bash

function error_check(){
    local sof_error=$(dmesg | grep sof-audio | grep -E "error|failed|timed out|panic|oops")
    if [ ! -z "$sof_error" ]; then
        dmesg > dmesg-change-volume-fail.txt
        return 1
    fi
    return 0
}

function change_volume(){
    local numid=${1:-21}
    local card=${2:-0}
    local times=${3:-10000}
    local volume=0
    local i=0
    eval $(amixer -c$card cget numid=$numid | grep max= | awk -F, '{printf("%s;%s\n",$4,$5)}')
    echo $numid $card $times $min $max
    [ -z $min ] || [ -z $max ] && exit 1

    echo "dmesg > dmesg-change-volume-first.txt"
    dmesg > dmesg-change-volume-first.txt
    echo "dmesg -C"
    dmesg -C

    volume=$min
    while [ $i -lt $times ]; do
        i=$((i + 1))
        volume=$((volume + 1))
        [ $volume -gt $max ] && volume=$min
        printf "[%05d] amixer -c%d cset numid=%d %d \r" $i $card $numid $volume
        amixer -c$card cset numid=$numid $volume > /dev/null
        sleep 0.1
        error_check
        [ $? -ne 0 ] && break
    done
    printf "======== Volume changed: %d times ========\n" $i
}

change_volume $@
