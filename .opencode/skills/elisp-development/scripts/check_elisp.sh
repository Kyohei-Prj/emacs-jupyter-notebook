#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

FILE="${1:-}"

if [[ -z "$FILE" ]]; then
    echo "Usage: $0 <file.el>"
    exit 1
fi

if [[ ! -f "$FILE" ]]; then
    echo "File not found: $FILE"
    exit 1
fi

FAIL=0

echo "========================================"
echo "ELISP VALIDATION :: $FILE"
echo "========================================"

########################################
# 1. check-parens
########################################

echo
echo "[1/7] check-parens"

PARENS_OUTPUT=$(emacs -Q --batch \
    --eval "(setq ejn-check-parens-file \"$FILE\")" \
    -l "$SCRIPT_DIR/check_parens.el" 2>&1) || true

if [[ -n "$PARENS_OUTPUT" ]]; then
    echo "FAIL :: $PARENS_OUTPUT"
    FAIL=1
else
    echo "PASS :: parentheses balanced"
fi

########################################
# 2. structural traversal
########################################

echo
echo "[2/7] structural traversal"

if emacs -Q --batch \
    "$FILE" \
    -l "$SCRIPT_DIR/structural_scan.el"
then
    echo "PASS :: structural traversal"
else
    echo "FAIL :: structural traversal"
    FAIL=1
fi

########################################
# 3. byte compilation
########################################

echo
echo "[3/7] byte compilation"

if emacs -Q --batch \
    -f batch-byte-compile "$FILE"
then
    echo "PASS :: byte compilation"

    rm -f "${FILE}c"
else
    echo "FAIL :: byte compilation"
    FAIL=1
fi

########################################
# 4. indentation normalization
########################################

echo
echo "[4/7] indentation normalization"

cp "$FILE" "$FILE.bak"

emacs -Q --batch "$FILE" \
    --eval "(progn
        (indent-region (point-min) (point-max))
        (save-buffer))"

if diff -q "$FILE" "$FILE.bak" >/dev/null
then
    echo "PASS :: indentation stable"
else
    echo "WARN :: indentation drift detected"
fi

rm -f "$FILE.bak"

########################################
# 5. normalization
########################################

echo
echo "[5/7] normalization"

if emacs -Q --batch \
    "$FILE" \
    -l "$SCRIPT_DIR/normalize_elisp.el"
then
    echo "PASS :: normalization"
else
    echo "FAIL :: normalization"
    FAIL=1
fi

########################################
# 6. package-lint
########################################

echo
echo "[6/7] package-lint"

if command -v package-lint-batch-and-exit >/dev/null 2>&1
then
    if package-lint-batch-and-exit "$FILE"
    then
        echo "PASS :: package-lint"
    else
        echo "WARN :: package-lint findings"
    fi
else
    echo "SKIP :: package-lint unavailable"
fi

########################################
# 7. checkdoc
########################################

echo
echo "[7/7] checkdoc"

if emacs -Q --batch "$FILE" \
    --eval "(with-current-buffer (find-file-noselect \"$FILE\") (checkdoc-current-buffer))"
then
    echo "PASS :: checkdoc"
else
    echo "WARN :: checkdoc findings"
fi

########################################

echo
echo "========================================"

if [[ "$FAIL" -eq 0 ]]; then
    echo "VALIDATION SUCCESS"
    exit 0
else
    echo "VALIDATION FAILED"
    exit 1
fi
