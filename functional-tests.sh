#!/bin/bash
export PATH=${PATH}:.

test -e ssshtest || wget -q https://raw.githubusercontent.com/ryanlayer/ssshtest/master/ssshtest

. ssshtest

set -o nounset

assert_equal 18 12

# Slice
run slice_inf csv slice 5: test/data/*.tsv
assert_exit_code 0
assert_no_stderr
assert_equal "18" $(cat $STDOUT_FILE | wc -l)
assert_in_stdout "Dodge Challenger"

run slice_low csv slice :3 test/data/*.tsv
assert_exit_code 0
assert_no_stderr
assert_equal "12" $(cat $STDOUT_FILE | wc -l)
assert_in_stdout "Fiat 128"

run slice csv slice 1:3 test/data/*.tsv
assert_exit_code 0
assert_no_stderr
assert_equal "9" $(cat $STDOUT_FILE | wc -l)

run slice csv slice huh:3 test/data/*.tsv
assert_exit_code 1
assert_stderr
assert_in_stderr "Malformed range"