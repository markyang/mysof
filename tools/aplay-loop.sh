#!/bin/bash

function error_check(){
    local sof_error=$(dmesg | grep sof-audio | grep -E "error|failed|timed out|panic|oops")
    if [ ! -z "$sof_error" ]; then
        dmesg > dmesg-aplay-loop-fail.txt
        return 1
    fi
    return 0
}

function aplay_loop(){
    local sleep_sec=${1:-1}
    local times=${2:-10000}
    local i=0
    while [ $i -lt $times ]; do
        i=$((i + 1))
        printf "aplay: %d \r" $i
        aplay -Dhw:0,0 -c 2 -r 48000 -f s16_le -d 1 /dev/zero 2> /dev/null
        [ $sleep_sec -gt 0 ] && sleep $sleep_sec
        error_check
        [ $? -ne 0 ] && break
    done
    printf "======== aplay: %d times ========\n" $i
}

function main(){
    echo "dmesg > dmesg-aplay-loop-first.txt"
    dmesg > dmesg-aplay-loop-first.txt
    echo "dmesg -C"
    dmesg -C
    aplay_loop $@
}

main $@