#!/bin/bash
# Fill in an invoice entry in GnuCash

printUsage() {
    cat <<EOF
usage:
  $PROGNAME [-n QUANTITY] [options] [SEARCH_TERM]
  $PROGNAME -h

options:
  -n QUANTITY
      define the quantity for the invoice entry
  -a  rely on GnuCash auto-complete when item with same description exists
  -d
      dry-run, do not type and fill in the entry table in GnuCash
  -k
      switch X keyboard layout from 'de neo' to 'de' for typing
  -h
      show this help message
EOF
}

# Use environment variable:
# The CSV file must contain a header line!
readonly ENV_VAR_NAME=FIE_CSV_FILE
readonly ARTICLE_DATABASE=$FIE_CSV_FILE
readonly CSV_SEPARATOR=';'

readonly INCOME_ACCOUNT="01. Betriebliche Erträge:a) Umsatzerlöse:Umsatzerlöse 19% USt"

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
    while getopts "hdn:ka" OPTION; do
         case $OPTION in
         n)
             quantity=$OPTARG
             [[ $quantity =~ ^[0-9]+$ ]] \
                 || exitWithError "error: QUANTITY must be a positive integer"
             ;;
         d)  declare -rg DRY_RUN=1
             ;;
         k)  declare -rg SWITCH_KEYBOARD_LAYOUT=1
             ;;
         a)  declare -rg RELY_ON_AUTOCOMPLETE=1
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
    [[ -n $SWITCH_KEYBOARD_LAYOUT ]] \
        && setxkbmap de

    declare line=$1
    declare id description price rest
    IFS=$CSV_SEPARATOR read -r id description price rest <<< "$line"

    if [[ -z $DRY_RUN ]]; then

        sleep 0.05
        xdotool type "$id - $description"
        xdotool key Tab
        if [[ -n $RELY_ON_AUTOCOMPLETE ]]; then
            xdotool type "$QUANTITY"
        else
            xdotool type "Auftrag"
            sleep 0.05
            xdotool key Tab
            xdotool type "$INCOME_ACCOUNT"
            sleep 0.05
            xdotool key Tab
            xdotool type "$QUANTITY"
            xdotool key Tab
            xdotool type "$price"
            xdotool key Tab
            # xdotool type "kein rabatt"
        fi

        # "Steuerbar" kann man blöderweise nicht per Tastatur ansteuern!
        # Folglich kann man "Steuertabelle" auch nicht per Tastatur ansteuern,
        # weil deaktiviert, solange nicht "Steuerbar".
    else
        xmessage "would fill in: $id, $description, $QUANTITY, $price"
    fi

    [[ -n $SWITCH_KEYBOARD_LAYOUT ]] \
        && setxkbmap de neo
}

main() {
    set -e

    parseCommandLine "$@"
    [[ -e $ARTICLE_DATABASE ]] \
        || exitWithError "error: article database '$ARTICLE_DATABASE' (a CSV file) does not exist. Please check the environment variable '$ENV_VAR_NAME'."

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
            echo -n '# '
            head -1 "$searchResultFile"
            # actually, the first character of the selected line must just be different from '_'
            tail -n+2 "$searchResultFile" | sed 's/^/_ /'
        } > "$userSelectFile"

        # fzf for Mac OS?
        gvim --nofork "$userSelectFile"
        [[ -s "$userSelectFile" ]] \
            || xerrorAndExit "canceled by user"
        # how to start fzf in a terminal?
        # xterm -e fzf ...
        # and how to get the result of fzf back?

        declare selectedLineNumber
        selectedLineNumber=$(awk 'NR>2&&!/^_/{print NR-1;exit}; ENDFILE{exit 1}' "$userSelectFile") \
            || xerrorAndExit "nothing selected"

        declare line
        line=$(sed -n "$selectedLineNumber"p "$searchResultFile")
        typeInvoiceEntry "$line"
    fi
}

main "$@"
