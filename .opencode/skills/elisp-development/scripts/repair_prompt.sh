#!/usr/bin/env bash

FAILURE_TYPE="$1"

case "$FAILURE_TYPE" in
    PAREN_MISMATCH)
        echo "Repair only the smallest unmatched form."
        ;;

    READER_SYNTAX)
        echo "Inspect quoting, reader macros, and malformed lists."
        ;;

    FREE_VARIABLE)
        echo "Add missing lexical bindings or parameters."
        ;;

    MALFORMED_FUNCTION)
        echo "Repair malformed function declaration only."
        ;;

    *)
        echo "Perform localized structural repair."
        ;;
esac
