#!/usr/bin/env bash

LOG_FILE="$1"

if grep -q "End of file during parsing" "$LOG_FILE"; then
    echo "PAREN_MISMATCH"
    exit 0
fi

if grep -q "Invalid read syntax" "$LOG_FILE"; then
    echo "READER_SYNTAX"
    exit 0
fi

if grep -q "reference to free variable" "$LOG_FILE"; then
    echo "FREE_VARIABLE"
    exit 0
fi

if grep -q "Malformed function" "$LOG_FILE"; then
    echo "MALFORMED_FUNCTION"
    exit 0
fi

echo "UNKNOWN"
