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

FILE_DIR="$(cd "$(dirname "$FILE")" && pwd)"

if emacs -Q --batch \
    --eval "(package-initialize)" \
    --eval "(push \"$FILE_DIR\" load-path)" \
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

# Find the main package file by walking up from the file's parent directory
FILE_DIR="$(dirname "$FILE")"
PROJECT_ROOT="$(dirname "$FILE_DIR")"
while [[ "$PROJECT_ROOT" != "/" ]]; do
    if [[ -f "$PROJECT_ROOT/Eask" ]]; then
        break
    fi
    # Check for .el files but not if we're in a lisp/ or test/ subdir
    BASENAME="$(basename "$PROJECT_ROOT")"
    if [[ "$BASENAME" != "lisp" && "$BASENAME" != "test" ]] && \
       ls "$PROJECT_ROOT"/*.el >/dev/null 2>&1; then
        break
    fi
    PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
done

# Look for main .el file in project root
FILE_MAIN=""
for candidate in "$PROJECT_ROOT"/*.el; do
    if [[ -f "$candidate" ]]; then
        FILE_MAIN="$candidate"
        break
    fi
done

# Fallback: if no main file found, use the file itself
if [[ -z "$FILE_MAIN" ]]; then
    FILE_MAIN="$FILE"
fi

PACKAGE_LINT_OUTPUT=$(emacs -Q --batch \
    --eval "(package-initialize)" \
    --eval "(require 'package-lint)" \
    --eval "(setq package-lint-main-file \"$FILE_MAIN\")" \
    --eval "(package-lint-batch-and-exit)" \
    "$FILE" 2>&1) || true

if [[ -z "$PACKAGE_LINT_OUTPUT" ]]
then
    echo "PASS :: package-lint"
else
    echo "WARN :: package-lint findings"
    echo "$PACKAGE_LINT_OUTPUT"
fi

########################################
# 7. checkdoc
########################################

echo
echo "[7/7] checkdoc"

CHECKDOC_OUTPUT=$(emacs -Q --batch \
    --eval "(progn
        (setq checkdoc-interactive nil)
        (defun y-or-n-p (_prompt) nil))" \
    --eval "(with-current-buffer (find-file-noselect \"$FILE\")
        (condition-case e
            (checkdoc-current-buffer)
          (error (princ (error-message-string e)))))" 2>&1) || true

if [[ -z "$CHECKDOC_OUTPUT" ]]
then
    echo "PASS :: checkdoc"
else
    echo "WARN :: checkdoc findings"
    echo "$CHECKDOC_OUTPUT"
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
