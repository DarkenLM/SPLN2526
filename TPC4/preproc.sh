#!/bin/bash

#region ============== Global Variables ==============
DEBUG=
__ARGS=
SOURCE=
OUTPUT=
#endregion ============== Global Variables ==============

#region ============== Functions ==============
debug() {
    if $DEBUG; then
        echo "[$BASHPID] $*" >&2
    fi
}

usage() {
	local prog=${0##*/}
	cat <<-EOF
	Usage: $prog [options] <book>

	Preprocess the Harry Potter text files.

	Options
	  --debug, -d enable debug output
	  --help, -h display this help message
	  --source, -s the source directory for the file
	  --output, -o the output directory for the file

	Book
	  filosofal: Harry Potter e A Pedra Filosofal.txt
	  camara: Harry_Potter_Camara_Secreta-br.txt
	EOF
}

parse_filosofal() {
    cat "${SOURCE}Harry Potter e A Pedra Filosofal.txt" | 
        sed -E '
            s/\s+[—-] (CAPÍTULO [^—-]+? ).+/\1:/g;
            s/\s{3,}(\S.+?)/\1@!/g
        ' | 
        perl -0777 -pe '
            s/\n([^–])/ $1/g;
            s/@! ?/\n/g;
            s/^\s*$//g;
            s/^\s{3,}//g;
            s/ {2}/ /g;
            s/(^^L[\s\S]+?)CAPÍTULO UM :/CAPÍTULO UM :/g;
            s/\x0C//g;
            s/.+?(CAPÍTULO UM :)/$1/gs;
            s/(CAPÍTULO .+)/$1./g
        ' > "${OUTPUT}Harry Potter e A Pedra Filosofal.preproc.txt"
}

parse_camara() {
    cat "${SOURCE}Harry_Potter_Camara_Secreta-br.txt" | 
        sed -E '
            s/\s+[—-] (CAPÍTULO [^—-]+? ).+/\1:/g;
            s/\s{3,}(\S.+?)/\1@!/g
        ' | 
        perl -0777 -pe '
            s/\n([^–])/ $1/g;
            s/@! ?/\n/g;
            s/^\s*$//g;
            s/^\s{3,}//g;
            s/ {2}/ /g;
            s/(CAPÍTULO .+)/$1./g
        ' > "${OUTPUT}Harry_Potter_Camara_Secreta-br.preproc.txt"
}

cleanup() {
    DEBUG=
    __ARGS=
    SOURCE=
    OUTPUT=
}
#region ============== Functions ==============

#region ============== CLI ==============
_parse_opts() {
    for arg in "$@"; do
        shift
        case "$arg" in
            '--debug')  set -- "$@" '-d'   ;;
            '--help')   set -- "$@" '-h'   ;;
            '--source') set -- "$@" '-s'   ;;
            '--output') set -- "$@" '-o'   ;;
            *)          set -- "$@" "$arg" ;;
        esac
    done

    local opt OPTIND OPTARG
    while getopts "dhso" opt; do
        case "$opt" in
            d) DEBUG=true;;
            h) usage; return 1;;
            s) SOURCE=$OPTARG;;
            o) OUTPUT=$OPTARG;;
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
    debug "Flags: D: $DEBUG | S: $SOURCE | O: $OUTPUT"

    trap cleanup EXIT

    if [[ "$SOURCE" != "" ]]; then SOURCE="$SOURCE/"; else SOURCE="source/"; fi
    if [[ "$OUTPUT" != "" ]]; then OUTPUT="$OUTPUT/"; else OUTPUT="dest/"; fi
    
    mkdir -p "$OUTPUT"

    book=$1
	case "$book" in
		filosofal) parse_filosofal; ;;
        camara) parse_camara; ;;
	esac
}

main "$@"
#endregion ============== CLI ==============
