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
mkdir -p "${PARENT_DIR}/.data" && cd "${PARENT_DIR}/.data"
mkdir -p "${PARENT_DIR}/benchmarks" 
if ! test -s "${PARENT_DIR}/.data/worldcitiespop_mil.csv"; then
    wget http://burntsushi.net/stuff/worldcitiespop_mil.csv
fi;

export PATH="${PARENT_DIR}:${PATH}"

cd "${PARENT_DIR}/.data" || exit 1

# Select a column
hyperfine --export-csv "${PARENT_DIR}/benchmarks/select.csv" \
          --export-markdown "${PARENT_DIR}/benchmarks/select.md" \
          --runs 10 \
         "xsv select 2 ${PARENT_DIR}/.data/worldcitiespop_mil.csv > out.select.txt" \
         "tut select 2 ${PARENT_DIR}/.data/worldcitiespop_mil.csv > out.select.txt"