#!/bin/bash

shopt -s lastpipe

#region ============== Global Variables ==============
DEBUG=
__ARGS=
MODEL="model.tfidfs"
TESTFILE="queries.txt"
#endregion ============== Global Variables ==============

#region ============== Functions ==============
cleanup() {
    unset DEBUG
    unset __ARGS
    unset MODEL
    unset TESTFILE
}

debug() {
    if [[ -n $DEBUG ]]; then
        if [[ "$1" == "-e" ]]; then
            echo -e "[$BASHPID] ${*:2}" >&2
        else
            echo "[$BASHPID] $*" >&2
        fi
    fi
}

test() {
    local model="${1:?"test requires a model file to test."}"
    local queries="${2:?"test requires a test file to test with."}"

    local i=0 fails=0 warns=0
    local -a queryResults=(0)
    while IFS='|' read -r query _matches; do
        i=$((i + 1))

        debug "QUERY #$i: |$query|"
        debug "QUERY #$i FUCKING MATCHES: |$(sed -E 's/\n//g;s/^\s*//g;s/\s*$//g' < <(printf "$_matches"))|"
        local matchArr; readarray -t -d ',' matchArr < <(sed -E 's/\n//g;s/^\s*//g;s/\s*$//g' < <(printf "$_matches"))
        local -A matches=()
        for match in "${matchArr[@]}"; do
            matches[$match]=1
        done

        debug "QUERY #$i MATCHES: |$_matches|${!matches[*]}|$(declare -p matches)|$(declare -p matchArr)|"

        queryResults+=(0)

        local doc matchval
        local res; res="$(./useModel.sh -m "$model" "$query")"
        debug -e "QUERY #$i RES: |||\n$res\n|||"

        echo "$res" | tail -n +2 | sed -E 's/\s+-\s*//g' \
            | while IFS=':' read -r doc matchval; do
                debug "TEST Q$i: |$doc|$matchval|$val|"
                local val; val="$(sed -E 's/\s+//g' <<< "$matchval")"
                debug "TEST Q$i NEWVAL: |$val|"
                [[ "$val" == "0" ]] && break;
                if [[ -z "${matches[$doc]}" ]]; then
                    echo "Test warn for query #$i: Model matched unexpected document: $doc"
                    warns=$((warns + 1))
                    queryResults[i]=$((queryResults[i] | 2#01))
                    continue
                fi
                matches[$doc]=2
            done

        for doc in "${!matches[@]}"; do
            if [[ "${matches[$doc]}" -eq 1 ]]; then
                echo "Test fail for query #$i: Model did not match expected document: $doc"
                fails=$((fails + 1))
                queryResults[i]=$((queryResults[i] | 2#10))
            fi
        done
    done < "$queries"

    debug "TEST RESULTS: ${queryResults[*]}"

    echo "Test results:"
    for ((j=1; j<=i; j++)); do
        local type=""
        if [[ $((queryResults[j] & 2#10)) -eq 2 ]]; then type=$(printf "\033[31mERROR\033[0m");
        elif [[ $((queryResults[j] & 2#01)) -eq 1 ]]; then type=$(printf "\033[33mWARN\033[0m");
        else type=$(printf "\033[32mPASS\033[0m");
        fi

        printf "%s %s: %s\n" '-' "$j" "$type"
    done
}
#endregion ============== Functions ==============

#region ============== CLI ==============
usage() {
    local prog=${0##*/}
    cat <<-EOF
	Usage: $prog [options]

	Tests a generated model according to a query file.

	Options
	  --debug, -d enable debug output
	  --help, -h display this help message
      --model, -m the model to test
      --testfile, -t the file containing the queries to test.
EOF
}

_parse_opts() {
    for arg in "$@"; do
        shift
        case "$arg" in
            '--debug')    set -- "$@" '-d'   ;;
            '--help')     set -- "$@" '-h'   ;;
            '--model')    set -- "$@" '-m'   ;;
            '--testfile') set -- "$@" '-t'   ;;
            *)            set -- "$@" "$arg" ;;
        esac
    done

    local opt OPTIND OPTARG
    while getopts "dhm:t:" opt; do
        case "$opt" in
            d) DEBUG=true;;
            h) usage; return 1;;
            m) MODEL="$OPTARG";;
            t) TESTFILE="$OPTARG";;
            *) usage >&2; return 2;;
        esac
    done
    shift "$((OPTIND - 1))"
    __ARGS="$*"
}
main() {
    _parse_opts "$@"
    if [[ $? != 0 ]]; then return 1; fi
    set -- "$__ARGS"

    debug "Args: $# |$*|"
    debug "Flags: D: $DEBUG"

    trap cleanup EXIT

    test "$MODEL" "$TESTFILE"
}

main "$@"
#endregion ============== CLI ==============
