#!/bin/bash

shopt -s lastpipe

# Note to self: For some fucking reason, adding a '-' to anywhere BUT the end of a character class makes sed interpret 
# it as a range operator, no matter how many times it is escaped.
#region ============== Global Variables ==============
DEBUG=
STOP_WORDS=$(cat stopwords.en | tr '\n' '|' | sed -E 's/\|/\\b|\\b/g')
#endregion ============== Global Variables ==============

#region ============== Functions ==============
cleanup() {
    unset DEBUG
    unset STOP_WORDS
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

dprintf() {
    if [[ -n $DEBUG ]]; then
        printf "$@"
    fi
}

preprocess() {
    local prefix; prefix="${1:?"preprocessing requires a variable prefix"}"
    local input="${2:?"preprocessing requires an input corpus"}"

    eval "declare -ga ${prefix}_CORPUS=()"
    local i=0
    echo "$input" | while IFS=$'\n' read -r line; do
        i=$((i + 1))
        eval "${prefix}_CORPUS+=(\"$i\")"
        eval "declare -ga ${prefix}_CORPUS_$i=()"
        local cline; cline=$(
            echo "$line" \
            | sed -E 's/[,\.\!"#\$%\&\/\(\)=\?'\''\-]/ /g;s/ +/ /g' \
            | tr '[:upper:]' '[:lower:]' \
            | sed -E "s/$STOP_WORDS//g;s/ {2,}/ /g;s/^ //g;s/ $//g" 
        )
        eval "${prefix}_CORPUS_$i+=(\"$cline\")"
    done
}

tf() {
    local d; d=$1
    local dl; dl=$2
    local t; t=$(echo "$1" | grep -oi "$3" | wc -l)

    debug "TF: $d $dl |$t|"
    local f; f="0$(echo "scale=10; $t / $dl" | bc)"
    debug "TF 2: $([ "$dl" -eq "0" ]; echo "$?") $f"
    echo "$f"
}
tfs() {
    local prefix; prefix="${1:?"tfs requires a prefix for the output TFS collection"}"
    local src; src="${2:?"tfs requires a prefix for the source corpus"}"

    local corpusKey="${src}_CORPUS"
    local -n corpus="$corpusKey"
    local n; n="${#corpus[@]}"

    debug "TFS for $prefix from $src: $n"

    eval "declare -ga ${prefix}_TF_KEYS=()"
    for i in "${corpus[@]}"; do
        local -n cline="${corpusKey}_$i"
        # TF_KEYS+=("$i")
        eval "${prefix}_TF_KEYS+=(\"$i\")"
        eval "declare -gA ${prefix}_TF_COL_$i=()"
        debug "TF LINE: |$cline|"
        
        local d; d=$(echo "$cline" | sed -E 's/ /\n/g' | wc -l)
        for word in $cline; do
            local clean; clean="$word"
            debug "TFS $i WORD: |$word|$clean|$d|"
            if [[ "$clean" == "" ]]; then 
                debug "TFS $i CONTINUE"
                continue;
            else
                eval "${prefix}_TF_COL_${i}[$clean]=\"$(tf "$cline" "$d" "$clean")\""
            fi

            local key="${prefix}_TF_COL_$i"
            debug "$i: ${!key}"
        done
    done

    local -n keys="${prefix}_TF_KEYS"
    debug "TFS KEYS: ${#keys[@]}"
    debug "$(declare -p | rg " (?:$prefix|$src)")"

    for col in "${keys[@]}"; do
        local -n array="${prefix}_TF_COL_$col"
        # debug
        # debug "TF INDEXES ${prefix}_TF_COL_$col: ${#array[@]}"
        dprintf "TF[%s]: " "$col"
        for cell in "${!array[@]}"; do
            dprintf "%s: %s " "$cell" "${array[$cell]}"
        done
        dprintf "\n"
    done
}

idfs() {
    local prefix; prefix="${1:?"idfs requires a prefix for the output TFS collection"}"
    local src; src="${2:?"idfs requires a prefix for the source corpus"}"
    local input; input="${3:?"idfs requires the original input for the source corpus"}"

    local corpusKey="${src}_CORPUS"
    local -n corpus="$corpusKey"
    local n; n="${#corpus[@]}"

    debug "IFDS for $prefix from $src: $n"

    local completeCorpus="";
    for i in "${corpus[@]}"; do
        local -n cline="${corpusKey}_$i"
        debug "IDFS SRC LINE: |$i|$n|$cline|"
        completeCorpus="$completeCorpus$cline"
        [[ $i -lt $((n + 1)) ]] && completeCorpus="$completeCorpus"$'\n'
    done
    local ws; ws=$(echo "$completeCorpus" | sed -E 's/ /\n/g')
    debug "IDFS: $n $ws"

    local corpora; corpora=$(echo "$ws" | sort | uniq | paste -d' ' -s - | sed -E 's/ {2,}/ /g')
    debug "IDFS CORPORA: $corpora"

    eval "declare -gA ${prefix}_IDFS=()"
    local -n _idfs="${prefix}_IDFS"
    for word in $corpora; do
        local i; i=0
        echo "$input" \
            | sed -E 's/[,\.\!"#\$%\&\/\(\)=\?'\''\-]/ /g;s/ +/ /g' \
            | tr '[:upper:]' '[:lower:]' \
            | while IFS=$'\n' read -r ncorpus; do
            if echo "$ncorpus" | grep "$word" > /dev/null; then i=$((i + 1)); fi
            debug "IDFS WORD: |$word|$ncorpus|"
        done
            # | sed -E 's/[,\.\-\!"#\$%\&\/\(\)=\?'\'']//g' \

        debug "IDFS CORPUS CONTAINING |$word|: $i"
        if [[ "$i" -eq 0 ]]; then
            continue;
        else 
            _idfs[$word]="0$(echo "scale=10; (l($n / $i)/l(10))" | bc -l)"
        fi
    done

    debug "IDF KEYS: ${#_idfs[@]}"
    for word in "${!_idfs[@]}"; do
        dprintf "IDFS %s: %s\n" "$word" "${_idfs[$word]}"
    done
}

tf_idfs() {
    local prefix; prefix="${1:?"tf_idfs requires a prefix for the output TFS collection"}"
    local tfsrc; tfsrc="${2:?"tf_idfs requires a prefix for the source TF collection"}"
    local idfssrc; idfssrc="${3:?"tf_idfs requires a prefix for the source IDF collection"}"
    debug -e "TFS DECLARED: |||\n$(declare -p | rg "${tfsrc}_TF")\n|||"
    debug -e "IDFS DECLARED: |||\n$(declare -p | rg "${idfssrc}_IDFS")\n|||"

    debug "TF-IDFS for $prefix from $tfsrc/$idfssrc"

    eval "declare -ga ${prefix}_TFIDFS=()"
    local -n _tfidfs="${prefix}_TFIDFS"

    debug -e "TF-IDFS PREDECLARED: \n$(declare -p | rg "TFIDFS")"
    debug -e "TF-IDFS PREDECLARED KEYS: ${#_tfidfs[@]}"

    # Iterate over all TFs
    local -n tfkeys="${tfsrc}_TF_KEYS"
    local -n _idfs="${idfssrc}_IDFS"
    debug "TF-IDFS TF KEYS: |${tfsrc}_TF_KEYS|${#tfkeys[@]}|"
    debug "TF-IDFS IDFS: |${idfssrc}_IDFS|${#_idfs[@]}|"
    for col in "${tfkeys[@]}"; do
        debug "TF-IDFS KEY: $col"

        declare -n array="${tfsrc}_TF_COL_$col"
        [[ "${#array[@]}" -eq 0 ]] && continue;
        _tfidfs+=("$col")

        eval "declare -gA ${prefix}_TFIDFS_COL_$col=()"

        debug
        debug "TF-IDFS TF INDEXES TF_COL_$col: ${#array[@]}"
        dprintf "TF-IDFS TF[%s]: \n" "$col"

        for cell in "${!array[@]}"; do
            dprintf ":: %s: %s \n" "$cell" "${array[$cell]}"
            debug "TF-IDFS COMPONENTS: |$cell|${array[$cell]}|${_idfs[$cell]}|scale=10; ${array[$cell]} * ${_idfs[$cell]}|"
            eval "${prefix}_TFIDFS_COL_${col}[$cell]=\"0$(echo "scale=10; ${array[$cell]} * ${_idfs[$cell]:-0}" | bc)\""
        done
    done

    debug -e "TF-IDFS DECLARED: \n$(declare -p | rg "TFIDFS")"
    debug "TF-IDFS KEYS: ${#_tfidfs[@]}"

    for col in "${_tfidfs[@]}"; do
        declare -n array="${prefix}_TFIDFS_COL_$col"
        dprintf "TF-IDFS %s:\n" "$col"
        for cell in "${!array[@]}"; do
            dprintf ":: %s: %s \n" "$cell" "${array[$cell]}"
        done
    done
}
#endregion ============== Functions ==============
