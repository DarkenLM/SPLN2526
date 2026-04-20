#!/bin/bash

set +m
shopt -s lastpipe

# model -> header options cmds
#
# header -> "!DLM" "COMMAND" VERSION
#
# options -> option options
#          | $
# option -> optionnames arg COLON optiondesc
#
# optionnames -> NAME optionnames1
# optionnames1 -> "," optionnames
#              | $
# optiondesc -> VALUE
#
# cmds -> cmd cmds
#       | $
#
# cmd -> "CMD" NAME args "(" options ")"
#
# args -> arg args
#       | $
# arg -> argmark "<" NAME argdefault ">"
# argmark -> "?"
#          | $
# argdefault -> LBRACE DEFAULTVALUE "}"
# nullablearg -> arg
#              | $
#
# VERSION: /\d+\.\d+\.\d+/
# NAME: /[a-zA-Z0-9_\-]+/
# COLON: @text ":"
# VALUE.text: @initial /[^\n]+/
# NUM: /\d+(?:\.\d+)/
# LBRACE: @defaultvalue "{"
# DEFAULTVALUE.defaultvalue: @initial /[^}]+/
#
# -------------------------------------------
# Unbound Strings
# _0  DLM!
# _1  COMMAND
# _2  ,
# _3  CMD
# _4  (
# _5  )
# _6  <
# _7  >
# _8  ?
# _9  }

#region ============== State Variables ==============
DEBUG=1
TOKENS=()
TOKENS_LEN=0
__POS=0
RESULT=
AW_RESULTS=()
AW_INDICES=()
#endregion ============== State Variables ==============

#region ============== Constants ==============
__US_DLM="_0"
__US_COMMAND="_1"
__US_COMMA="_2"
__US_CMD="_3"
__US_LPAREN="_4"
__US_RPAREN="_5"
__US_LT="_6"
__US_GT="_7"
__US_QUOTATION="_8"
__US_RBRACE="_9"
#endregion ============== Constants ==============

# trace() {
#     echo "$@" >&2
# }
trace() {
    if [[ -n $DEBUG ]]; then
        echo "[$BASHPID] $*" >&2
    fi
}

#region ============== Lexer ==============
lex() {
    /usr/bin/env python3 -c '
import re
import sys
__LEX = {
    "initial": re.compile(r"(?P<_0>!DLM)|(?P<_1>COMMAND)|(?P<_2>,)|(?P<_3>CMD)|(?P<_4>\()|(?P<_5>\))|(?P<_6><)|(?P<_7>>)|(?P<_8>\?)|(?P<_9>\})|(?P<VERSION>\d+\.\d+\.\d+)|(?P<LBRACE>{)|(?P<COLON>:)|(?P<NUM>\d+(?:\.\d+))|(?P<NAME>[a-zA-Z0-9_\-]+)"),
    "defaultvalue": re.compile(r"(?P<_0>!DLM)|(?P<_1>COMMAND)|(?P<_2>,)|(?P<_3>CMD)|(?P<_4>\()|(?P<_5>\))|(?P<_6><)|(?P<_7>>)|(?P<_8>\?)|(?P<_9>\})|(?P<DEFAULTVALUE>[^}]+)"),
    "text": re.compile(r"(?P<_0>!DLM)|(?P<_1>COMMAND)|(?P<_2>,)|(?P<_3>CMD)|(?P<_4>\()|(?P<_5>\))|(?P<_6><)|(?P<_7>>)|(?P<_8>\?)|(?P<_9>\})|(?P<VALUE>[^\n]+)"),
}
__re_IGNORE = re.compile(r"[ \t\n]+")
__lex_curState = "initial"

#s = input(); l = len(s)
s = sys.stdin.read(); l = len(s)
pos = 0; row = 1; col = 1
while (pos < l):
    mi = __re_IGNORE.match(s, pos)
    if (mi):
        for ch in mi.group(0):
            if (ch == "\n"): row += 1; col = 1
            else: col += 1
        pos = mi.end()
        if (pos >= l): break

    tg = __LEX[__lex_curState].match(s, pos)
    if (not tg):
        print(f"Unexpected character: {s[pos]} (at {pos})")
        sys.exit(1)

    sfpos = (row, col, pos)
    t = next((k, v) for k, v in tg.groupdict().items() if v is not None)
    for ch in tg.group(0):
        if (ch == "\n"): row += 1; col = 1
        else: col += 1

    pos = tg.end()
    print(f"{t[0]}\t{t[1]}\t{sfpos}\t{(row, col, pos)}")

    match (__lex_curState):
            case "initial":
                match (t[0]):
                    case "LBRACE": __lex_curState = "defaultvalue"
                    case "COLON": __lex_curState = "text"
            case "defaultvalue":
                match (t[0]):
                    case "DEFAULTVALUE": __lex_curState = "initial"
            case "text":
                match (t[0]):
                    case "VALUE": __lex_curState = "initial"
    '
}
#endregion ============== Lexer ==============

#region ============== Stream Operators ==============
tok_type()  { echo "${TOKENS[$((__POS * 4 + 0))]}"; }
tok_val()   { echo "${TOKENS[$((__POS * 4 + 1))]}"; }
tok_start() { echo "${TOKENS[$((__POS * 4 + 2))]}"; }
tok_end()   { echo "${TOKENS[$((__POS * 4 + 3))]}"; }
tok() {
    local _oldPos; _oldPos=$__POS;
    if [[ $# -gt 0 ]]; then __POS=$1; fi
    echo "$(tok_type) $(tok_val) $(tok_start) $(tok_end)";
    __POS=$_oldPos
}

eof()  { [[ $__POS -ge $TOKENS_LEN ]]; }
next() { ((__POS++)); }
peek() {
    local offset="${1:-0}"
    echo "${TOKENS[$(( (__POS + offset) * 4 ))]}"
}

expect() {
    local e="$1"
    local a; a=$(tok_type)
    [[ "$a" == "$e" ]] || parse_error "Expected '$e', got '$a' ('$(tok_val)')"
    local v; v=$(tok_val)
    next
    RESULT="$v"
}

testToken() {
    [[ "$(tok_type)" == "$1" ]];
}

parse_error() {
    echo "ParseError at $(tok_start): $1" >&2
    exit 1
}

load_tokens() {
    __POS=0
    while IFS=$'\t' read -r type value start end; do
        TOKENS+=("$type" "$value" "$start" "$end")
        ((__POS++))
    done
    TOKENS_LEN=$__POS
}

# $1: testing predicate
# $2: parsing function
# Accessible through the array AW_RESULTS
acceptwhile() {
    trace "AW: $1 | $2"
    local fodase; fodase=0;
    while $1; do
        local oldfodase; oldfodase=$fodase
        trace "AW START $2 $fodase"
        $2
        AW_RESULTS+=("$RESULT")
        fodase=$((fodase + 1))
        trace "AW ACCEPT $2 $oldfodase: $RESULT $fodase $(tok_type)"
    done
    AW_INDICES+=("$fodase")
    trace "AW POS $2: $__POS $fodase"
}

list_wssep() {
    local res;
    if ! testToken "$2"; then 
        RESULT="null"
        return; 
    fi

    $1
    res="[$RESULT"
    trace "LWS ACCEPT $1: $RESULT"

    # AW_RESULTS=()
    acceptwhile "testToken $2" "$1" > /dev/stdin
    count="${AW_INDICES[-1]}"
    unset "AW_INDICES[-1]"
    trace "LWS AWRES $1: $count ${#AW_RESULTS[@]}"
    local awlen; awlen=${#AW_RESULTS[@]}
    # for n in "${AW_RESULTS[@]}"; do
    # for ((i=1;i<=count;i++)); do
    for ((i=count;i>0;i--)); do
        trace "LWS ITER $i $(($awlen - $i))"
        n="${AW_RESULTS[$awlen - $i]}"
        res="$res, $n"
        unset "AW_RESULTS[$awlen - $i]"
    done

    RESULT="$res]"
    trace "LWS RES $1: $RESULT"
    trace "LWS POS $1: $__POS"
}

# $1: parsing function
# $2{__US_COMMA}: the separator token between elements
list() {
    local sep; sep=${2:-$__US_COMMA}
    local opt; $1; opt="$RESULT"
    local res;

    res="[$opt"
    if testToken "$sep"; then
        while testToken "$sep"; do
            next
            res="$res, "
            $1; opt="$RESULT"
            res="$res$opt"
        done
    fi

    RESULT="$res]"
}
#endregion ============== Stream Operators ==============

#region ============== Parser ==============
parse_header() {
    expect $__US_DLM > /dev/null
    expect $__US_COMMAND > /dev/null
    local n1; expect "VERSION"; n1="$RESULT"
    RESULT="{ \"version\": \"$n1\" }"
}

parse_options() {
    trace "OPTIONS: $(tok_type)"
    list_wssep parse_option "NAME"
}

parse_option() {
    local names; parse_optionnames; names="$RESULT"
    local arg; parse_nullablearg; arg="$RESULT"
    expect "COLON" > /dev/null
    local desc; parse_optiondesc; desc="$RESULT"

    RESULT="{ \"names\": $names, \"arg\": $arg, \"desc\": $desc }"
}

parse_optionnames() {
    list parse_optionname
}
parse_optionname() {
    local n; expect "NAME"; n="$RESULT"
    RESULT="\"$n\""
}
parse_optiondesc() {
    expect "VALUE"
    RESULT="\"$RESULT\""
}

parse_cmds() {
    list_wssep parse_cmd "$__US_CMD"
    trace "CMDS: $RESULT"
}
parse_cmd() {
    expect "$__US_CMD" > /dev/null
    local n1; expect "NAME"; n1="\"$RESULT\""
    trace "CMD NAME PARSED: '$n1'"
    local n2; parse_args; n2="$RESULT"
    trace "CMD ARGS PARSED"
    expect $__US_LPAREN > /dev/null
    local n3; parse_options; n3="$RESULT"
    expect $__US_RPAREN > /dev/null

    RESULT="{ \"name\": $n1, \"args\": $n2, \"options\": $n3 }"
    trace "NEW COMMAND: $RESULT"
}

parse_args() {
    list_wssep parse_arg "$__US_LT"
}
parse_arg() {
    expect $__US_LT > /dev/null
    local n1; parse_argmark; n1="$RESULT"
    local n2; expect "NAME"; n2="$RESULT"
    local res; res="{ \"optional\": $n1, \"name\": \"$n2\""
    if testToken "LBRACE"; then
        next
        local n3; expect "DEFAULTVALUE"; n3="$RESULT"
        printf -v res "%s%s" "$res" ", \"default\": \"$n3\""
        expect $__US_RBRACE> /dev/null
    fi
    expect $__US_GT > /dev/null

    printf -v res "%s%s" "$res" " }"
    RESULT="$res"
}
parse_argmark() {
    if testToken $__US_QUOTATION; then
        next
        RESULT="true"
    else
        RESULT="false"
    fi
}
parse_nullablearg() {
    if testToken $__US_LT; then
        parse_arg
    else
        RESULT="null"
    fi
}

parse_model() {
    local header; parse_header; header="$RESULT"
    trace "HEADER PARSED: $header $__POS"
    local options; parse_options; options="$RESULT"
    trace "OPTIONS PARSED: $options $__POS"
    local cmds; parse_cmds; cmds="$RESULT"

    RESULT="{ \"header\": $header, \"options\": $options, \"cmds\": $cmds }"
}

parse() {
    parse_model
}
#endregion ============== Parser ==============

#region ============== Generator ==============
#region ------- Template -------
#shellcheck disable=SC2016
__SCRIPT_TEMPLATE__='
#!/bin/bash

#region ============== Global Variables ==============
DEBUG=
__ARGS=
#endregion ============== Global Variables ==============

#region ============== Functions ==============
cleanup() {
    DEBUG=
    __ARGS=
}

debug() {
    if $DEBUG; then
        echo "[$BASHPID] $*" >&2
    fi
}
#endregion ============== Functions ==============

#region ============== CLI ==============
#{{!DLM_START}}
# Autogenerated by DLM Autocmd from {{MODEL}} at {{TIMESTAMP}}
# DO NOT EDIT MANUALLY.
usage() {
    local prog=${0##*/}
    cat <<-EOF
    Usage: $prog [cmd] [options]

    {{DESC}}

    {{OPTIONS}}
		--debug,-d, enable debug output
		--help,-h, display this help message

    {{CMD}}
EOF
}

_print_help() {
    local prog=${0##*/}
    echo -e "Usage: $prog $1 [options]\n\n$2"
    if [[ -n "$3" ]]; then echo -e "$3"
}

help() {
    case "$1" in
        {{HELP_ACTIONS}}
        *) usage >&2; return 1 ;;
    esac
}

_parse_opts() {
    for arg in "$@"; do
        shift
        case "$arg" in
            '--debug') set -- "$@" '-d'   ;;
            '--help')  set -- "$@" '-h'   ;;
            {{OPT_ALIASES}}
            *)         set -- "$@" "$arg" ;;
        esac
    done

    local opt OPTIND OPTARG
    while getopts "dh{{OPT_STRING}}" opt; do
        case "$opt" in
            d) DEBUG=true;;
            h) usage; return 1;;
            {{OPT_ACTIONS}}
            *) usage >&2; return 2;;
        esac
    done
    shift "$((OPTIND - 1))"
    __ARGS="$*"
}
#{{!DLM_END}}

main() {
    _parse_opts "$@"
    if [[ $? != 0 ]]; then return 1; fi
    set -- "$__ARGS"

    debug "Args: $# |$*|"
    debug "Flags: D: $DEBUG"

    trap cleanup EXIT

    # ...
}

main "$@"
#endregion ============== CLI ==============
'
#endregion ------- Template -------

apply_template() {
    local template="$1"
    shift

    local env_args=()
    while [[ $# -gt 1 ]]; do
        env_args+=("MACRO_${1}=${2}")
        shift 2
    done

    RESULT=$(env "${env_args[@]}" perl -0777 -pe '
        BEGIN {
            %macros = map {
                my $k = $_; $k =~ s/^MACRO_//;
                "{{$k}}" => $ENV{$_}
            } grep /^MACRO_/, keys %ENV;
        }
        while (my ($k, $v) = each %macros) {
            s/\Q$k\E/$v/g;
        }
    ' <<< "$template")
}

make_arg() {
    local arg;
    if [[ "$1" != "null" ]]; then
        local isOptional; isOptional=$([[ "$(echo "$1" | jq -r '.optional')" == "false" ]])
        $isOptional && arg=" [" || arg=" <"
        arg="$arg$(echo "$1" | jq -r '.name')"
        $isOptional && arg="$arg]" || arg="$arg>"

        local default; default="$(echo "$1" | jq -r '.default')"
        [[ "$default" != "null" ]] && arg="$arg {$default}"
    fi

    echo "$arg"
}

make_options() {
    local options; options="Options\n"
    jq -c '.[]' | while IFS=$'\n' read -r c; do
        trace "MO OPT: $c"
        options="$options\t\t$(make_option "$c")\n"
    done

    trace "MO OPTIONS: |$(echo "$options" | sed -E "s/\\\\n$//")|"
    echo "$options" | sed -E "s/\\\\n$//"
}
make_option() {
    local names; names=$(echo "$1" | 
        jq -r '.names | sort | reduce .[] as $i (""; (if length > 1 then "--" else "-" end) + $i + "," + .)' |
        sed -E "s/^\"//;s/,\"$//"
    )
    local desc; desc=$(echo "$1" | jq -r '.desc' | sed -E 's/[ \t]*$//')
    local _arg; _arg=$(echo "$1" | jq -r '.arg')
    local arg; arg=$(make_arg "$_arg")
    echo "$names$arg $desc"
}

make_help() {
    local helpActions
    echo "$1" | jq -c '.cmds | .[]' | while IFS=$'\n' read -r c; do
        trace "MH CMD: $c"
        local name; name=$(echo "$c" | jq -r '.name')
        local desc; desc=$(echo "$c" | jq -r '.desc'); [[ "$desc" == "null" ]] && desc=''
        local options; options=$(echo "$c" | jq -r '.options' | make_options | sed -E 's/\\n/\\\\n/g')
        local helpActions; helpActions="$helpActions\n\t\t$name) _print_help \"$name\" \"$desc\" \"$options\" ;;"

        trace "------- $name -------"
        trace "$desc"
        trace "$options"
        trace "---------------------"
    done

    echo "$helpActions" | sed -E 's/^\\n\\t*//' | echo -e "$(cat)"
}

make_cmds() {
    local cmds; cmds="Commands\n"
    echo "$1" | jq -c '.cmds | .[]' | while IFS=$'\n' read -r c; do
        local name; name=$(echo "$c" | jq -r '.name')
        local desc; desc=$(echo "$c" | jq -r '.desc'); [[ "$desc" == "null" ]] && desc=''
        cmds="$cmds\t\t$name $desc\n"
    done

    echo -e "$cmds" | sed -E 's/\n$//'
}

# make_actions() {
#     local actions; actions=""
#     echo "$1" | jq -c '.cmds | .[]' | while IFS=$'\n' read -r c; do
#         local name; name=$(echo "$c" | jq -r '.name')
#         actions="$actions$name() {\n    :\n}\n"
#     done

#     echo -e "$actions"
# }

make_actions() {
    local actions; actions=""
    echo "$1" | jq -c '.cmds | .[]' | while IFS=$'\n' read -r c; do
        local name; name=$(echo "$c" | jq -r '.name')
        actions="$actions$name() {\n    :\n}\n"
    done

    echo -e "$actions"
}

make_script() {
    local desc; desc=$(echo "$1" | jq -r '.desc' | sed -E 's/[ \t]*$//')
    local options; options=$(echo "$1" | jq -r '.options' | make_options | sed -E 's/\\n/\n/g;s/\\t/\t/g')
    local help; help=$(make_help "$1")
    local cmds; cmds=$(make_cmds "$1")
    # local actions; actions=$(make_actions "$1")
    local g_opts; g_opts=$(
        echo "$1" | 
        jq -r '
            .options 
            | .[] 
            | "\(.names 
            | map(select(length == 1)) 
            | join(""))\(if .arg != null then ":" else "" end)"
        ' | 
        paste -s - | 
        sed -E 's/\t//g'
    )
    local g_opt_actions; g_opt_actions=$(
        echo "$1" | 
        jq -r '
            .options 
            | .[] 
            | "\(.names | map(select(length == 1)) | join(""))
            "
        ' | 
        paste -s - | 
        sed -E 's/\t//g'
    )

    #jq -r '.cmds | .[].options | .[].names | map(select(length == 1)) | join("")' | paste -s - | sed -E 's/\t//g' 

    trace "MS OPTS: |$g_opts|"
    
    apply_template "$__SCRIPT_TEMPLATE__" \
        "DESC" "$desc" \
        "OPTIONS" "$options" \
        "CMD" "$cmds" \
        "HELP_ACTIONS" "$help" \
        "ACTIONS" "$actions" \
        "OPT_STRING" "$g_opts" 

    echo "$RESULT"
}
#endregion ============== Generator ==============

main() {
    cat - | paste -d'\n' -s - | lex | load_tokens

    # echo "Recognized tokens: $TOKENS_LEN"
    # for ((i=1;i<=TOKENS_LEN-1;i++)); do
    #     echo "OUTTOKEN #$i: $(tok $i)"
    # done

    __POS=0
    parse
    echo "$RESULT"
    # make_help "$RESULT"
    make_script "$RESULT"
}

main
