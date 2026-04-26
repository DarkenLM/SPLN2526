#!/bin/bash

shopt -s lastpipe

#region ============== Global Variables ==============
DEBUG=
__ARGS=
QUERY=
EXPORT=
STOP_WORDS=$(cat stopwords.en | tr '\n' '|' | sed -E 's/\|/\\b|\\b/g')
#endregion ============== Global Variables ==============

. ./tfidf.sh

#region ============== Functions ==============
cleanup() {
    unset DEBUG
    unset __ARGS
    unset QUERY
    unset EXPORT
    unset STOP_WORDS
}

query_ranking() {
    local queryPrefix; queryPrefix="${1:?"query_ranking requires the TF-IDFS vector prefix for the query"}"
    local srcPrefix; srcPrefix="${2:?"query_ranking requires the TF-IDFS vector prefix for the src"}"

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
    declare -A srcMags=()
    for col in "${src[@]}"; do
        local srcMag=0
        local -n srcArray="${srcPrefix}_TFIDFS_COL_$col"

        debug "QR MAG SRC: $col ${srcArray[*]}"
        for word in "${!srcArray[@]}"; do
            local srcWeight="${srcArray[$word]}"
            srcMag="$(echo "scale=10; $srcMag + ($srcWeight ^ 2)" | bc)"
        done

        srcMag="$(echo "scale=10; sqrt($srcMag)" | bc)"
        srcMags[$col]=$srcMag
    done
    debug "QR SRCMAGS: ${#srcMags[@]} |${srcMags[*]}|"

    local queryMag=0
    for word in "${!query[@]}"; do
        local queryWeight="${query[$word]}"
        queryMag="$(echo "scale=10; $queryMag + ($queryWeight ^ 2)" | bc)"
    done
    queryMag="$(echo "scale=10; sqrt($queryMag)" | bc)"
    debug "QR QUERYMAG: $queryMag"

    # Calculate similarities
    local -A similarities=()
    for col in "${!srcMags[@]}"; do
        local srcDot="${srcDots[$col]}"
        local srcMag="${srcMags[$col]}"
        debug "QR SIM: $col|$srcDot|$queryMag|$srcMag|"
        local similarity; similarity=$(echo "scale=10; $srcDot / ($queryMag * $srcMag)" | bc)
        debug "QR SIM RES: $similarity"
        similarities[$col]=$(bc <<< "x=$similarity; if (x < -1) -1 else if (x > 1) 1 else x")
    done

    # local simInd; simInd=$(rg -o '^[^ ]+' <<< "${!similarities[*]}")
    # debug "QR SIMILARITIES: |${similarities[*]}|${!similarities[*]}|$simInd|"
    # for sim in "${!similarities[@]}"; do
    #     debug "QR SIMILARITY: $sim ${similarities[$sim]} |${similarities[$sim]} > ${similarities[$simInd]}|"
    #     if [[ "$(bc <<< "${similarities[$sim]} > ${similarities[$simInd]}")" -eq 1 ]]; then simInd=$sim; fi
    # done
    # debug "QR MOST SIMILAR: $simInd ${similarities[$simInd]}"
    # echo $simInd
    debug "QR SIMILARITIES: |${similarities[*]}|${!similarities[*]}"
    local json="["
    for sim in "${!similarities[@]}"; do
        json="$json [\"$sim\", ${similarities[$sim]}],"
    done
    json="${json::-1} ]"
    # local sort; sort="$(
    #     jq -c 'sort_by(.[1]) | reduce .[] as $i (""; (. + "\n\"" + ($i | .[0]) + "\"__TFIDF__" + "\($i | .[1])"))' \
    #         <<< "$json"
    # )"
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

    debug "QR SORTED"
    for k in "${sorted[@]}"; do
        debug "  - $k: ${sorted_col[$k]}"
    done

    echo "${sorted[0]}"
}

export_model() {
    local prefix; prefix="${1:?"export_model requires the TF-IDFS vector prefix to export"}"
    local outpath; outpath="${2:?"export_model requires the output file location to export to"}"
    
    mkdir -p "$(dirname "$outpath")"
    touch "$outpath"
    truncate -s 0 "$outpath"

    local index; index=$(mktemp --suffix ".txt")
    local mags; mags=$(mktemp --suffix ".txt")

    debug "EXPORT: $prefix |$outpath|"
    debug -e "EXPORT DECLARED VECTOR: |||\n$(declare -p | rg "${prefix}_TFIDFS")\n|||"
    local -A seen=()
    local -n indices="${prefix}_TFIDFS"
    local -n idfs="${prefix}_IDFS"
    for ind in "${indices[@]}"; do
        local srcMag=0
        local -n col="${prefix}_TFIDFS_COL_$ind"

        # breaknext=0
        for word in "${!col[@]}"; do
            debug "EXPORT WORD: $word"
            [[ -n "${seen[$word]}" ]] && continue;
            local wordId; wordId="$(wc -w <<< "${!seen[*]}")"
            # printf "%s " "$word" >> "$index" # TODO REMOVE
            printf "%s %s" "$wordId" "$(sed -E 's/01\./1\./g' <<< "${idfs[$word]}")" >> "$index"
            # printf "%s" "${col[$word]}" >> "$index"

            # In order to avoid creating another metric fuckton of variables, process each word at a time, across all
            # documents, and output that, before moving to the next.
            for ind2 in "${indices[@]}"; do
                # [[ $ind -eq $ind2 ]] && continue;
                local -n col2="${prefix}_TFIDFS_COL_$ind2"
                # printf "%s " "$ind2:${col2[$word]:-0}" >> "$index" # TODO REMOVE
                printf " %s" "${col2[$word]:-0}" >> "$index"
                # [[ "$ind2" == "1" ]] && debug "EXPORT FODASE: |$ind2|$word|${col2[$word]}|"
                # [[ "$word" == "football" ]] && debug "EXPORT FODASE: |$ind2|$word|${col2[$word]}|"
            done
            # [[ "$breaknext" == "1" ]] && {
            #     cat "$index" >> "$outpath"
            #     exit 123
            # }
            # [[ "$word" == "football" ]] && {
            #     breaknext="1"
            # }

            printf "\n" >> "$index"
            seen[$word]="$wordId"
        done

    done

    # Calculate magnitudes
    for ind in "${indices[@]}"; do
        local mag=0
        local -n col="${prefix}_TFIDFS_COL_$ind"

        for word in "${!col[@]}"; do
            mag="$(echo "scale=10; $mag + (${col[$word]} ^ 2)" | bc)"
        done

        mag=$(sed -E 's/^\./0./g' <<< "$(echo "scale=10; sqrt($mag)" | bc)")
        echo "$ind $mag" >> "$mags"
    done

    # Concatenate final file
    { 
        echo "${#indices[@]}"
        echo "${#seen[@]}"
        for word in "${!seen[@]}"; do
            echo "$word ${seen[$word]}"
        done | sort -k 2 -n
    } >> "$outpath"

    cat "$mags" >> "$outpath"
    rm "$mags"

    cat "$index" >> "$outpath"
    rm "$index"
}
#endregion ============== Functions ==============

#region ============== CLI ==============
usage() {
    local prog=${0##*/}
    cat <<-EOF
	Usage: $prog [options] <cmd>

	Calculate TF-IDFs for a given corpus and query.

	Options
	  --debug, -d enable debug output
	  --help, -h  display this help message
	  --query, -q specify the query to be used
	  --export, -e exports the TF-IDF model in SVM format
EOF
}

_parse_opts() {
    for arg in "$@"; do
        shift
        case "$arg" in
            '--debug')  set -- "$@" '-d'   ;;
            '--help')   set -- "$@" '-h'   ;;
            '--query')  set -- "$@" '-q'   ;;
            '--export') set -- "$@" '-e'   ;;
            *)          set -- "$@" "$arg" ;;
        esac
    done

    local opt OPTIND OPTARG
    while getopts "dhq:e:" opt; do
        case "$opt" in
            d) DEBUG=true;;
            h) usage; return 1;;
            q) QUERY="$OPTARG";;
            e) EXPORT="$OPTARG";;
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

    # Create base corpus
    local rawInput; rawInput="$(cat -)"
    debug -e "RAW INPUT: |||\n$rawInput\n|||"
    preprocess "BASE" "$rawInput"
    debug -e "INPUT: \n$(declare -p | rg 'CORPUS')"

    # Calculate TF-IDFs for base corpus
    tfs "BASE" "BASE"
    idfs "BASE" "BASE" "$rawInput"
    tf_idfs "BASE" "BASE" "BASE"

    debug "------------------------------------------"

    # Process query
    if [[ -n "$QUERY" ]]; then
        local rawQueryInput; rawQueryInput="$(echo "$QUERY" | sed -E 's/\n/ /g')"
        debug -e "RAW QUERY INPUT: |||\n$rawQueryInput\n|||"
        preprocess "QUERY" "$rawQueryInput"
        debug -e "INPUT: \n$(declare -p | rg 'CORPUS')"

        tfs "QUERY" "QUERY"
        idfs "QUERY" "BASE" "$rawQueryInput"
        tf_idfs "QUERY" "QUERY" "BASE"
        local top; top="$(query_ranking "QUERY" "BASE")"

        local -n topMatch="BASE_CORPUS_$top"
        echo "TOP MATCH: $top | ${topMatch[*]}"
    fi

    [[ -n "$EXPORT" ]] && export_model "BASE" "$EXPORT";
}

main "$@"
#endregion ============== CLI ==============
