#!/bin/bash
# Move to the top level
nim c -d:release tut.nim
cd `git rev-parse --show-toplevel`
wget http://burntsushi.net/stuff/worldcitiespop_mil.csv

export PATH=${PATH}:`pwd`

time xsv select 2 worldcitiespop_mil.csv > out.xsv.txt
# real	0m0.240s
# user	0m0.169s
# sys	0m0.035s
time tut select 2 worldcitiespop_mil.csv > out.tut.txt

# Initial version
# real	0m15.913s
# user	0m11.606s
# sys	0m4.017s

# real	0m10.843s
# user	0m10.592s
# sys	0m0.145s