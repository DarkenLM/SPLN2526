#!/bin/bash

shopt -s lastpipe

#region ============== Global Variables ==============
DEBUG=
__ARGS=
QUERY=
MODEL="model.tfidfs"
#endregion ============== Global Variables ==============

. ./tfidf.sh

#region ============== Functions ==============
cleanup() {
    unset DEBUG
    unset __ARGS
    unset QUERY
    unset MODEL
}

debug() {
    if [[ -n "$DEBUG" ]]; then
        echo "[$BASHPID] $*" >&2
    fi
}

parse_model() {
    local model="${1:?"parse_model requires the path to the modle file to use"}"

    if [[ ! -f "$model" ]]; then
        echo "ENOENT $model: Model file does not exist."
        exit 1
    fi

    declare -gA BASE_VOCAB=()
    declare -gA BASE_VOCAB_REVERSE=()
    declare -gA BASE_MAGS=()
    declare -gA BASE_IDFS=()
    declare -ga BASE_TFIDFS=()
    local docnum wordcount
    local stage=0 dstage=0 wcstage=0
    while IFS= read -r line; do
        debug "PM LINE STAGE: $stage|$dstage|$wcstage| |$line|"
        case $stage in
            0) 
                docnum="$line" 
                for ((i=1; i<=docnum; i++)); do
                    BASE_TFIDFS+=("$i")
                    eval "declare -gA BASE_TFIDFS_COL_$i=()"
                done
                ;;
            1) 
                wordcount="$line"; 
                wcstage=$((wordcount + 2)) 
                dstage=$((docnum + wordcount + 2)) 
                debug "PM DOCNUM: $docnum | WORDCOUNT: $wordcount"
                ;;
            *)
                if [[ $stage -lt $wcstage ]]; then
                    local word wid
                    read -r word wid <<< "$line"
                    BASE_VOCAB[$word]=$wid
                    BASE_VOCAB_REVERSE[$wid]=$word
                elif [[ $stage -lt $dstage ]]; then
                    local doc idf
                    read -r doc mag <<< "$line"
                    BASE_MAGS[$doc]=$mag
                else
                    local wid idf postings
                    read -r wid idf postings <<< "$line"
                    debug "PM POSTING: |$wid||$idf|$postings|"
                    
                    local key="${BASE_VOCAB_REVERSE[$wid]}"
                    BASE_IDFS[$key]=$idf
                    
                    local idfs
                    local i=0
                    echo "$postings" | read -r -a idfs; 
                    for idf in "${idfs[@]}"; do
                        i=$((i + 1))
                        local -n doc="BASE_TFIDFS_COL_$i"
                        # debug "PM POSTING ELEM: |$i|$key|$idf|"
                        [[ "$idf" == "0" ]] && continue;
                        doc[$key]=$idf
                        # debug "PM POSTING POS: $(declare -p | grep "BASE_TFIDFS_COL_$i")"
                    done
                fi
                ;;
        esac
        stage=$((stage + 1))
    done < "$model"

    debug "$(declare -p | grep " BASE_")"
}

query_ranking() {
    local queryPrefix; queryPrefix="${1:?"query_ranking requires the TF-IDFS vector prefix for the query"}"
    local srcPrefix="BASE"

    local -n query="${queryPrefix}_TFIDFS_COL_1"
    local -n src="${srcPrefix}_TFIDFS"

    debug "QR SRCS ${#src[@]}"
    
    # Calculate Q x D_i, for all corpora
    declare -A srcDots=()
    for col in "${src[@]}"; do
        debug "QR SRC $col"

        local dot=0
        local -n srcArray="${srcPrefix}_TFIDFS_COL_$col"

        debug "QR SRC KEYS: ${#srcArray[@]} |${srcArray[*]}|"
        for word in "${!srcArray[@]}"; do
            local srcWeight queryWeight
            srcWeight="${srcArray[$word]}"
            
            # Multiline queries are squashed into a single document during preprocessing.
            queryWeight="${query[$word]:-0}"

            debug "QR DOTS |$col|$word|$dot|$srcWeight|$queryWeight|"
            dot="$(echo "scale=10; $dot + ($srcWeight * $queryWeight)" | bc)"
        done

        srcDots[$col]=$dot
    done
    debug "QR SRCDOTS: ${#srcDots[@]} |${srcDots[*]}|"

    # Calculate magnitudes
    local queryMag=0
    for word in "${!query[@]}"; do
        local queryWeight="${query[$word]}"
        queryMag="$(echo "scale=10; $queryMag + ($queryWeight ^ 2)" | bc)"
    done
    queryMag="$(echo "scale=10; sqrt($queryMag)" | bc)"
    debug "QR QUERYMAG: $queryMag"

    # Calculate similarities
    local -A similarities=()
    for col in "${!BASE_MAGS[@]}"; do
        local srcDot="${srcDots[$col]}"
        local srcMag="${BASE_MAGS[$col]}"
        debug "QR SIM: $col|$srcDot|$queryMag|$srcMag|"
        local similarity; similarity=$(echo "scale=10; $srcDot / ($queryMag * $srcMag)" | bc)
        debug "QR SIM RES: $similarity"
        similarities[$col]=$(bc <<< "x=$similarity; if (x < -1) -1 else if (x > 1) 1 else x")
    done

    debug "QR SIMILARITIES: |${similarities[*]}|${!similarities[*]}|"
    local json="["
    for sim in "${!similarities[@]}"; do
        json="$json [\"$sim\", ${similarities[$sim]}],"
    done
    json="${json::-1} ]"
    debug "QR SIM JSON: |$json|"

    local -A sorted_col=()
    local -a sorted=()
    local _sortElems
    echo "$json" \
        | jq -c 'sort_by(.[1]) | reverse | reduce .[] as $i (""; (. + "\n\"" + ($i | .[0]) + "\"@" + "\($i | .[1])"))' \
        | perl -0777 -pe 's/^.(?:\\n)?(.+).$/\1/g;s/\\"/\"/g;s/\\n/\n/g' \
        | while IFS='@' read -r k v; do
            debug "QR SORT: |$k|$v|"
            k="$(sed -E 's/"//g' <<< "$k")"
            sorted_col[$k]=$v
            sorted+=("$k")
        done

    echo "Top matches:"
    for k in "${sorted[@]}"; do
        echo "  - $k: ${sorted_col[$k]}"
    done

    echo "${sorted_col[0]}"
}
#endregion ============== Functions ==============

#region ============== CLI ==============
usage() {
    local prog=${0##*/}
    cat <<-EOF
	Usage: $prog [options] <cmd>

	Lorem ipsum dolor sit amet.

	Options
	  --debug, -d enable debug output
	  --help, -h display this help message
	  --model, -m the model file to use
EOF
}

_parse_opts() {
    for arg in "$@"; do
        shift
        case "$arg" in
            '--debug') set -- "$@" '-d'   ;;
            '--help')  set -- "$@" '-h'   ;;
            '--model')  set -- "$@" '-m'   ;;
            *)         set -- "$@" "$arg" ;;
        esac
    done

    local opt OPTIND OPTARG
    while getopts "dhm:" opt; do
        case "$opt" in
            d) DEBUG=true;;
            h) usage; return 1;;
            m) MODEL="${OPTARG}";;
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

    debug "Args: $# |$*| ${#__ARGS[@]}"
    debug "Flags: D: $DEBUG"

    trap cleanup EXIT

    parse_model "$MODEL"

    if [[ -z "$1" ]]; then usage; exit 1; fi
    local rawQueryInput; rawQueryInput="$(echo "$*" | sed -E 's/\n/ /g')"
    debug -e "RAW QUERY INPUT: |||\n$rawQueryInput\n|||"
    preprocess "QUERY" "$rawQueryInput"
    debug -e "INPUT: \n$(declare -p | rg 'CORPUS')"

    tfs "QUERY" "QUERY"
    idfs "QUERY" "BASE" "$rawQueryInput"
    tf_idfs "QUERY" "QUERY" "BASE"
    query_ranking "QUERY" "BASE"
}

main "$@"
#endregion ============== CLI ==============
