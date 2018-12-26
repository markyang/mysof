#!/bin/bash
. common.sh

# The timeout value(seconds) waiting for aplay is ready.
TIMEOUT_WAIT_APLAY=20

:<<'!'
Waiting for aplay is ready based on the timeout value(seconds).
  @timeout($1): The timeout value(seconds) waiting for aplay is ready.
!
function wait_aplay_ready(){
    local timeout=$1
    local elapsed_sec=0
    while [ $elapsed_sec -lt $timeout ]; do
        local ready=$(aplay -l | grep Subdevices | awk -F " " '{print $2}' \
          | awk -F "/" 'BEGIN{ready=1}{if($1!=$2){ready=0;exit}}END{print ready}')
        [ -z $ready ] && ready=0
        [ 1 -eq $ready ] && return $ready
        sleep 1
        let elapsed_sec+=1
        #echo "try $elapsed_sec"
    done
    return 0
}

function run_loop(){
    local max_loop=$1
    local ignore_error=$2
    local counter=0
    local platform=`get_platform`
    local codec_module=`get_codec_module`

    while [ $counter -lt $max_loop ]; do
        wait_aplay_ready $TIMEOUT_WAIT_APLAY
        if [ 0 -eq $? ]; then
            echo "aplay is not ready!"
            break
        fi
        echo "test $counter"
        ./sof_bootone.sh $platform $codec_module $ignore_error
        if [ 0 -ne $? ]; then
            echo "fail to boot firmware!"
            break
        fi
        dmesg > boot_$counter.bootlog
        let counter+=1
    done
    echo "==== boot firmware: $counter times ===="
}

function main(){
    local max_loop
    local ignore_error
    local valid=0

    assert_super_user

    until [ 1 -eq $valid ]; do
        read -p "Enter the loop times(default 5):" max_loop
        max_loop=${max_loop:-5}
        if [ -z `grep '^[[:digit:]]*$' <<< $max_loop` ]; then
            echo "Invalid number: $max_loop"
            valid=0
        else
            valid=1
        fi
    done
    echo "The loop times: $max_loop"

    valid=0
    until [ 1 -eq $valid ]; do
        read -p "Ignore errors in dmesg(yes/no)(default yes):" ignore_error
        ignore_error=${ignore_error:-"yes"}
        check_bool $ignore_error
        valid=$?
        [ 0 -eq $valid ] && echo "Invalid boolean value: $ignore_error,"\
          "must be one of the following values: true, false, yes, no, y, n, 1, 0."
    done
    echo "Ignore errors: $ignore_error"

    get_bool "$ignore_error"
    ignore_error=$?

    run_loop $max_loop $ignore_error
}

main