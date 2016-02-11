#!/usr/bin/env bash

declare -r BP_OS="$(uname -s)"
declare -r BP_UTC_DATE_FORMAT="%Y-%m-%dT%H:%M:%S%z"

##
# Get current timestamp
# @example 1450485413
# @return int
# @returnStatus 1 If date method fails
function timestamp ()
{
    local CURRENT_TIMESTAMP

    CURRENT_TIMESTAMP=$(date +"%s" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    echo -n "$CURRENT_TIMESTAMP"
}

##
# Get as arrayToString the time duration in seconds to run command given as parameter
# @example (["real"]="0m0.011s" ["user"]="0m0.001s" ["sys"]="0m0.005s" )
# @param string $1 Command
# @return arrayToString
# @returnStatus 1 If the first parameter named command is empty
# @returnStatus 1 If the time method does not return expected time values
function timeTodo ()
{
    local COMMAND="$1"
    if [[ -z "$COMMAND" ]]; then
        return 1
    fi
    declare -a TIMER="($({ time "$COMMAND"; } 2>&1 >/dev/null))"

    if [[ "${TIMER[0]}" == "real" && "${TIMER[2]}" == "user" && "${TIMER[4]}" == "sys" ]]; then
        echo -n "([\"real\"]=\"${TIMER[1]}\" [\"user\"]=\"${TIMER[3]}\" [\"sys\"]=\"${TIMER[5]}\")"
        return 0
    fi

    return 1
}

##
# Get in seconds the user time duration to run command given as parameter
# @param string $1 Command
# @return float
# @returnStatus 1 If the first parameter named command is empty
# @returnStatus 1 If the time method does not return the user timer
function userTimeTodo ()
{
    local COMMAND="$1"
    if [[ -z "$COMMAND" ]]; then
        return 1
    fi

    local USER_TIME
    USER_TIME="$(timeTodo "$COMMAND")"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    declare -a TIMER="$USER_TIME"
    if [[ -n "${TIMER[user]}" ]]; then
        echo -n "${TIMER[user]}" |  awk -F '[^0-9.]*' '$0=$2'
        return 0
    fi

    return 1
}

##
# Launch command in first parameter and check time duration.
# If time exceeds the maximum float value given in second parameter return 1, 0 otherwise
# @param string $1 Command
# @param float $1 Maximum time in second
# @returnStatus 1 If the first parameter named command is empty
# @returnStatus 1 If the timer of the command's duration does not return float value as expected
# @returnStatus 1 If the second parameter named maxTime is empty or an invalid number
function isUserTimeTodoExceeded ()
{
    local VAR_2
    if [[ -z "$1" || -z "$2" ]]; then
        return 1
    elif [[ "$2" =~ ^[-+]?[0-9]+\.[0-9]+$ ]]; then
        VAR_2="$2"
    elif [[ "$2" =~ ^[-+]?[0-9]+$ ]]; then
        # Int to float
        VAR_2="${2}.0"
    else
        return 1
    fi

    local VAR_1
    VAR_1="$(userTimeTodo "$1")"
    if [[ $? -ne 0 ]]; then
        return 1
    elif [[ "$VAR_1" != *"."* ]]; then
        # Int to float
        VAR_1="${VAR_1}.0"
    fi

    declare -i RES=0
    local DEC_VAR_1=$(( 10#${VAR_1##*.} ))
    local DEC_VAR_2=$(( 10#${VAR_2##*.} ))
    if (( ${VAR_1%%.*} > ${VAR_2%%.*} || ( ${VAR_1%%.*} == ${VAR_2%%.*} && $DEC_VAR_1 > $DEC_VAR_2 ) )) ; then
        return 0
    fi

    return 1
}

##
# Convert a Timestamp to UTC datetime
# @example 2015-12-19T01:28:58+01:00
# @param int $1 TIMESTAMP
# @return string
# @returnStatus 1 If parameter named timestamp is invalid
# @returnStatus 1 If UTC datetime is invalid
function utcDateTimeFromTimestamp ()
{
    local TIMESTAMP="$1"

    # Data check
    if [[ -z "$TIMESTAMP" || ! "$TIMESTAMP" =~ ^[-+]?[0-9]+$ ]]; then
        return 1
    fi

    # MacOs portability
    local OPTIONS="-d @"
    if [[ "${BP_OS}" == 'Darwin' ]]; then
       OPTIONS="-r"
    fi

    local UTC_DATETIME
    UTC_DATETIME=$(date ${OPTIONS}${TIMESTAMP} "+${BP_UTC_DATE_FORMAT}" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    echo -n "$UTC_DATETIME"
}

##
# Convert a UTC datetime to Timestamp
# @example 1450485413 => 2015-12-19T01:28:58+01:00
# @param string $1 UTC_DATETIME
# @return int
# @returnStatus 1 If parameter named utcDatetime is invalid
# @returnStatus 1 If timestamp is invalid
function timestampFromUtcDateTime ()
{
    local UTC_DATETIME="$1"
    local TIMESTAMP=O

    # Data check
    if [[ -z "$UTC_DATETIME" || ! "$UTC_DATETIME" == *"T"* ]]; then
        return 1
    fi

    # MacOs portability
    if [[ "${BP_OS}" == 'Darwin' ]]; then
        TIMESTAMP=$(date -j -f "${BP_UTC_DATE_FORMAT}" "${UTC_DATETIME}" "+%s" 2>/dev/null)
        if [[ $? -ne 0 ]]; then
            return 1
        fi
    else
        TIMESTAMP=$(date -d "${UTC_DATETIME}" "+%s" 2>/dev/null)
        if [[ $? -ne 0 ]]; then
            return 1
        fi
    fi

    echo -n ${TIMESTAMP}
}