#!/bin/bash

SH_ROOT_DIR=`dirname $0`
. $SH_ROOT_DIR/common.sh

LOG_DIR=logs

function show_help() {
    echo -e "Usage: $0 [platform] [codec_module] [ignore_error]\n"\
      "  Supported 'platforms': byt, apl, cnl, icl or whl.\n"\
      "  Valid 'ignore_error': true, false, yes, no, y, n, 1, 0."
    exit 1
}

function log_error() {
    local func_name=${1:-"sof_insert"}
    [ ! -d $LOG_DIR ] && mkdir $LOG_DIR
    dmesg > $LOG_DIR/boot_fail.log
    echo "$func_name failed, see $LOG_DIR/boot_fail.log for details"
    exit 1
}

function run_boot(){
    local logdir
    local platform
    local codec_module
    local fw_boot
    local timeout
    local error

    assert_super_user

    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        show_help $0
    fi

    if [ $# -ge 2 ]; then
        platform=$1
        codec_module=$2
        ignore_error=${3:-"no"}
    else
        platform=`get_platform`
        codec_module=`get_codec_module`
        ignore_error=${1:-"no"}
    fi
    echo "platform=[$platform],codec_module=[$codec_module],ignore_error=[$ignore_error]"

    check_bool $ignore_error
    [ 0 -eq $? ] && show_help $0
    get_bool $ignore_error
    ignore_error=$?

    dmesg -C

    $SH_ROOT_DIR/sof_remove.sh

    if [ 0 -eq $ignore_error ]; then
        error=$(dmesg | grep sof-audio | grep -v "DSP trace buffer overflow" | grep "error")
        [ ! -z "$error" ] && log_error "sof_remove"
    fi

    $SH_ROOT_DIR/sof_insert.sh $platform $codec_module
    sleep 1

    fw_boot=$(dmesg | grep sof-audio | grep "boot complete")
    timeout=$(dmesg | grep sof-audio | grep "ipc timed out")

    if [ 0 -eq $ignore_error ]; then
        error=$(dmesg | grep sof-audio | grep -v "DSP trace buffer overflow" | grep "error")
    fi

    if [ ! -z "$error" ] || [ -z "$fw_boot" ] || [ ! -z "$timeout" ]; then
        log_error "sof_insert"
    else
        echo "boot success"
    fi
}

run_boot $@
