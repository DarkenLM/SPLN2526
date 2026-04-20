#!/bin/bash

#region ============== Global Variables ==============
DEBUG=
OUTPUT="./datasets"
MODEL="./arquivo_ner_train.iob"
CONFIG="./config.cfg"
__ARGS=
#endregion ============== Global Variables ==============

#region ============== Functions ==============
cleanup() {
    DEBUG=
    OUTPUT=
    MODEL=
    CONFIG=
    __ARGS=
}

debug() {
    if [[ -n $DEBUG ]]; then
        echo "[$BASHPID] $*" >&2
    fi
}
#endregion ============== Functions ==============

#region ============== CLI ==============
usage() {
    local prog=${0##*/}
    cat <<-EOF
	Usage: $prog [options] <prepare|init|train>

	Train a language model using spaCy.

	Options
	  --debug,  -d enable debug output
	  --help,   -h display this help message
	  --output, -o the directory to output the generated files {./datasets}
	  --model,  -m the model file to use as input {./arquivo_ner_train.iob}
	  --config, -c the config file to use (train command only) {./config.cfg}
EOF
}

_parse_opts() {
    for arg in "$@"; do
        shift
        case "$arg" in
            '--debug')  set -- "$@" '-d'   ;;
            '--help')   set -- "$@" '-h'   ;;
            '--output') set -- "$@" '-o'   ;;
            '--model')  set -- "$@" '-m'   ;;
            '--config') set -- "$@" '-c'   ;;
            *)          set -- "$@" "$arg" ;;
        esac
    done

    local opt OPTIND OPTARG
    while getopts "dho:m:c:" opt; do
        case "$opt" in
            d) DEBUG=true;;
            h) usage; return 1;;
            o) OUTPUT="$OPTARG";;
            m) MODEL="$OPTARG";;
            c) CONFIG="$OPTARG";;
            *) usage >&2; return 2;;
        esac
    done

    shift "$((OPTIND - 1))"
    __ARGS=("$@")
}
main() {
    _parse_opts "$@"
    if [[ $? != 0 ]]; then return 1; fi
    set -- "${__ARGS[@]}"

    debug "Args: $# |$*|"
    debug "Flags: D: $DEBUG"

    trap cleanup EXIT

    case "$1" in
        prepare)
            shift
            mkdir -p "$OUTPUT"
            spacy convert -c iob "$MODEL" "$OUTPUT" "$@"
            ;;
        init)
            shift
            spacy init config "$OUTPUT/config.cfg" --pipeline ner --lang pt "$@"
            ;;
        train)
            shift
            echo "$*"
            spacy train "$CONFIG" --output "$OUTPUT" "$@"
            ;;
        test)
            shift
            /usr/bin/env python3 ./useModel.py "$([[ -n $DEBUG ]] && echo "-d")"
            ;;
        *)
            usage >&2; return 1;;
    esac
}

main "$@"
#endregion ============== CLI ==============
