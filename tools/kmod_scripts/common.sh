#!/bin/bash

:<<'!'
Make sure the current user is a super user.
!
function assert_super_user(){
    if [ 0 -ne $UID ]; then
        echo "A super user is needed to run this script!"
        exit 1
    fi
}

:<<'!'
Check the boolean value is valid or not.
  @value($1): the input value.
  If it is valid, returns 1, otherwise returns 0.
!
function check_bool(){
    for val in "true" "false" "yes" "no" "y" "n" "1" "0"
    do
        [ $val == $1 ] && return 1
    done
    return 0
}

:<<'!'
Get the boolean value.
  @value($1): the input boolean value.
  If it is in ("true" "yes" "y" "1"), returns 1, otherwise returns 0.
!
function get_bool(){
    for val in "true" "yes" "y" "1"
    do
        [ $val == $1 ] && return 1
    done
    return 0
}

:<<'!'
Get the platform type according to the CPU infomation.
!
function get_platform(){
    local platform
    case `lscpu | grep "Model:" | awk -F " " '{print $2}'` in
    55)
        platform="byt"
        ;;
    92)
        platform="apl"
        ;;
    102)
        platform="cnl"
        ;;
    126)
        platform="icl"
        ;;
    142)
        platform="whl"
        ;;
    *)
        platform="unknown"
        ;;
    esac
    echo $platform
}

:<<'!'
Read the codec module name, which is used for probing the codec module.
  @conf($1): the configuration file.
!
function read_codec_module(){
    assert_super_user
    local readonly comps=/sys/kernel/debug/asoc/components
    local conf=${1:-codec_map.conf}
    if [ ! -r $comps ]; then
        echo "cannot read \"$comps\"!"
        return 2
    fi
    if [ ! -e $conf ]; then
        echo "\"$conf\" not exit!"
        return 2
    fi
    for key in `cat $comps`
    do
        if [ ! -z $key ]; then
            codec=$(awk "{if(index(\$1, \"$key\")==1){print \$2; exit}}" $conf)
            #if 'key' is found, then break.
            if [ ! -z $codec ]; then
                echo $(echo -e $codec | sed 's/[ \r\n]*$//g')
                return 0
            fi
        fi
    done
    # module is not found.
    return 132
}

:<<'!'
Get codec module name, which is used for probing the codec module.
  If error occurs or no codec matches, returns "snd_sof_nocodec".
!
function get_codec_module(){
    codec_module=`read_codec_module`
    if [ 0 -eq $? ]; then
        echo $codec_module
    else
        echo "snd_sof_nocodec"
    fi
}