#!/bin/bash
test -e ssshtest || wget -q https://raw.githubusercontent.com/ryanlayer/ssshtest/master/ssshtest

. ssshtest

PARENT_DIR="`git rev-parse --show-toplevel`"
export PATH="${PATH}:${PARENT_DIR}"

set -o nounset

#=======#
# slice #
#=======#
run slice_inf tut slice 5: tests/data/*.tsv
assert_exit_code 0
assert_no_stderr
assert_equal "18" $(cat $STDOUT_FILE | wc -l)
assert_in_stdout "Dodge Challenger"

run slice_low tut slice :3 tests/data/*.tsv
assert_exit_code 0
assert_no_stderr
assert_equal "12" $(cat $STDOUT_FILE | wc -l)
assert_in_stdout "Fiat 128"

run slice tut slice 1:3 tests/data/*.tsv
assert_exit_code 0
assert_no_stderr
assert_equal "9" $(cat $STDOUT_FILE | wc -l)

run slice tut slice huh:3 tests/data/*.tsv
assert_exit_code 1
assert_stderr
assert_in_stderr "Malformed range"

run slice_add_col tut slice -a 0:3 tests/data/*.tsv
assert_exit_code 0
assert_in_stdout "basename"
assert_equal $(cat $STDOUT_FILE | cut -f 1 | uniq | wc -l) "12"
assert_equal $(cat $STDOUT_FILE | cut -f 7 | head -n 1) "basename"
assert_equal $(cat $STDOUT_FILE | cut -f 7 | head -n 2 | tail -n 1) "df1.tsv"

#========#
# select #
#========#
run select_1 tut select 1,2,3 tests/data/*.tsv
assert_exit_code 0
assert_no_stderr
assert_in_stdout "mpg"
assert_in_stdout "cyl"
assert_in_stdout "disp"


# select missing column
run select_2 tut select mpg tests/data/df3.tsv
assert_in_stdout "mpg" # header should be included
assert_equal $(cat $STDOUT_FILE | uniq | wc -l) "2"

# basename
run select_3 tut select -b mpg tests/data/df1.tsv
assert_equal $(cat $STDOUT_FILE | cut -f 2 | tail -n 1) "df1.tsv"