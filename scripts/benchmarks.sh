#!/bin/bash
# Move to the top level
set -e


function cleanup {
    rm -f "${PARENT_DIR}/out.select.txt"
}

trap cleanup EXIT

PARENT_DIR="$(git rev-parse --show-toplevel)" 
cd "${PARENT_DIR}" || exit 1
nimble build

# Download test data
mkdir -p "${PARENT_DIR}/.data" && cd "${PARENT_DIR}/.data"
if ! test -s "${PARENT_DIR}/.data/worldcitiespop_mil.csv"; then
    wget http://burntsushi.net/stuff/worldcitiespop_mil.csv
fi;

mkdir -p "${PARENT_DIR}/benchmarks" && cd "${PARENT_DIR}/benchmarks"

export PATH="${PARENT_DIR}:${PATH}"

# Select a column
hyperfine --export-csv "benchmarks/select.benchmarks.csv" \
          --export-markdown "benchmarks/select.md" \
          --runs 10 \
         "xsv select 2 worldcitiespop_mil.csv > out.select.txt" \
         "tut select 2 worldcitiespop_mil.csv > out.select.txt" \
         "csvtk cut -f 2 worldcitiespop_mil.csv > out.select.txt"