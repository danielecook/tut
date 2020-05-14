#!/bin/bash
# Move to the top level
set -e


function cleanup {
    rm -f "${PARENT_DIR}/out.select.txt"
}

trap cleanup EXIT

PARENT_DIR="$(git rev-parse --show-toplevel)" 

cd "${PARENT_DIR}" || exit 1
nimble install

# Download test data
mkdir -p "${PARENT_DIR}/.benchmarks" && cd "${PARENT_DIR}/.benchmarks"
if ! test -s "${PARENT_DIR}/.benchmarks/worldcitiespop_mil.csv"; then
    wget http://burntsushi.net/stuff/worldcitiespop_mil.csv
fi;

export PATH="${PARENT_DIR}:${PATH}"

cd "${PARENT_DIR}/.benchmarks" || exit 1

# Select a column
hyperfine --export-csv "select.benchmarks.csv" \
          --export-markdown "select.md" \
          --runs 10 \
         "xsv select 2 ${PARENT_DIR}/.benchmarks/worldcitiespop_mil.csv > out.select.txt" \
         "tut select 2 ${PARENT_DIR}/.benchmarks/worldcitiespop_mil.csv > out.select.txt"