#!/bin/bash
# Fill in an invoice entry in GnuCash

printUsage() {
    cat <<EOF
usage:
  $PROGNAME [-n QUANTITY] [SEARCH_TERM]
  $PROGNAME -h

options:
  -h
      show this help message
  -n QUANTITY
      define the quantity for the invoice entry
EOF
}

# Use environment variable:
# (Currently, the CSV file must not contain a header line)
readonly ARTICLE_DATABASE=$FIE_CSV_FILE
readonly CSV_SEPARATOR=,
readonly PROGNAME=$(basename "$0")

# $1: error message
exitWithError() {
    echo "$1" >&2
    exit 1
}

# $1: error message
xerrorAndExit() {
    # for Mac OS: osascript -e "display notification '$1' with title 'Fill Invoice Entry'"
    # xmessage "$1"
    notify-send -a fie "$1"
    exit 1
}

# $*: command line arguments = "$@"
parseCommandLine() {
    declare quantity
    while getopts "hn:" OPTION; do
         case $OPTION in
         n)
             quantity=$OPTARG
             [[ $quantity =~ ^[0-9]+$ ]] \
                 || exitWithError "error: QUANTITY must be a positive integer"
             ;;
         h)
             printUsage
             exit 0
             ;;
        esac
    done
    shift $((OPTIND-1))

    declare -gr SEARCH_TERM=$*
    declare -gr QUANTITY=${quantity:-1}

    return 0
}

# $1: a line from the article database
typeInvoiceEntry() {
    declare line=$1
    declare id description price rest
    IFS=$CSV_SEPARATOR read -r id description price rest <<< "$line"
    # xdotool
    xmessage "typing $id, $description, $QUANTITY, $price"
}

main() {
    set -e

    parseCommandLine "$@"
    [[ -e $ARTICLE_DATABASE ]] \
        || exitWithError "error: article database '$ARTICLE_DATABASE' (a CSV file) does not exist. Please check the environment variable 'FIE_CSV_FILE'."

    declare searchResultFile
    searchResultFile=$(mktemp)

    if [[ -z $SEARCH_TERM ]]; then
        cp "$ARTICLE_DATABASE" "$searchResultFile"
    else
        declare searchRegex
        searchRegex=$(sed -r 's/ +/.*/g' <<< "$SEARCH_TERM")
        grep -i "$searchRegex" "$ARTICLE_DATABASE" > "$searchResultFile" || true
        # TODO here it would be nice to directly use the exit status
        # however, the count == 0 case is still necessary when no search term is given
    fi

    declare matchingLineCount
    matchingLineCount=$(wc -l < "$searchResultFile")

    if (( matchingLineCount == 0 )); then
        xerrorAndExit "no matching entries"
    elif (( matchingLineCount == 1 )); then
        typeInvoiceEntry "$(head -1 "$searchResultFile")"
    else
        declare userSelectFile
        userSelectFile=$(mktemp)
        {
            echo "# Tick the line you want to select by changing the '_' to 'x'"
            # actually, the first character of the selected line must just be different from '_'
            sed 's/^/_ /' "$searchResultFile"
        } > "$userSelectFile"

        gvim --nofork "$userSelectFile"
        [[ -s "$userSelectFile" ]] \
            || xerrorAndExit "canceled by user"

        declare selectedLineNumber
        selectedLineNumber=$(awk 'NR>1&&!/^_/{print NR-1;exit}; ENDFILE{exit 1}' "$userSelectFile") \
            || xerrorAndExit "nothing selected"
        echo $?
        echo $selectedLineNumber

        declare line
        line=$(sed -n "$selectedLineNumber"p "$searchResultFile")
        typeInvoiceEntry "$line"
    fi
}

main "$@"
