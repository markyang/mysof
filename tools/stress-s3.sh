#!/bin/bash

set -x
readonly LOG_DIR=logs
readonly RANDOM_INIT_VALUE=1
readonly RANDOM_RANGE=5
readonly S3_SLEEP=2
set +x

function process_exists() {
    local process_name=$1
    local result=`ps aux | grep $process_name | grep -v grep`
    if [ -z "$result" ]; then
        echo "$process_name doesn't exist!"
        return 0
    else
        return 1
    fi
}

function aplay_works() {
    aplay -l | grep subdevice > /dev/null
    if [ $? != 0 ]; then
        echo "Failed to get aplay pcm list!"
        return 0
    else
        aplay -Dhw:0,0 -fS16_LE -c2 -r48000 -d1 /dev/zero > /dev/null
        if [ $? != 0 ]; then
            echo "Failed to aplay source!"
            return 0
        fi
        return 1
    fi
}

function run_s3_loop() {
    local iterations=${1:-1000}
    local ignore_error=${2:-1}
    local check_aplay=${3:-1}
    local counter=0
    local suspend_time
    local wake_time
    local error
    
    if [ -d $LOG_DIR ]; then
        [ -d ${LOG_DIR}-last ] && rm -rvf ${LOG_DIR}-last
        mv $LOG_DIR ${LOG_DIR}-last
    fi
    mkdir $LOG_DIR

    echo == start time: `date +"%Y-%m-%d %T"` ==
    while [ $counter -lt $iterations ]; do
        if [ 1 -eq $check_aplay ]; then
            process_exists "aplay"
            [ 0 -eq $? ] && break
        fi
        dmesg -C
        let counter+=1
        echo "---- test $counter of $iterations ----"
        suspend_time=$(($RANDOM % $RANDOM_RANGE + $RANDOM_INIT_VALUE))
        echo "System will suspend after $suspend_time seconds ..."
        sleep $suspend_time
        wake_time=$(($RANDOM % $RANDOM_RANGE + $RANDOM_INIT_VALUE))
        echo "system will resume after $wake_time seconds ..."
        rtcwake -m mem -s $wake_time
        sleep $S3_SLEEP
        if [ 1 -eq $ignore_error ]; then
            dmesg > $LOG_DIR/test_${counter}.log
        else
            error=$(dmesg | grep sof-audio | grep -v "failed" | grep "error")
            if [ ! -z "$error" ]; then
                dmesg > $LOG_DIR/test_${counter}_fail.log
                echo "Suspend/resume failed, see test_${counter}_fail.log for details"
                break
            fi
            dmesg > $LOG_DIR/test_${counter}_pass.log
        fi
    done
    
    if [ 0 -eq $check_aplay ]; then
        aplay_works
        [ 1 -eq $? ] && echo "aplay is OK after $iterations times suspend/resume."
    fi
    echo == end time: `date +"%Y-%m-%d %T"` ==
}

run_s3_loop $@