# tut (Table-Utilities)

[![Build Status](https://travis-ci.org/danielecook/tut.svg?branch=development)](https://travis-ci.org/danielecook/tut)

## Stack

Stacks datasets together by column.

```
tut stack [files ...]
```

## Slice

Extracts a range (1-based) from every file

```
 slice range [files ...]
```

 Where `range` is the range of lines to keep.

 * `:5` - From the beginning to the 5th line
 * `5:` - From the 5th line to the end
 * `3:5` - From the 3rd to the 5th line

## Select

Select columns from a file by column position (1-based) or name.

```
# These are equivelent:
tut select 1,2 tests/data/df1.tsv
tut select mpg,cyl tests/data/df1.tsv
```

|   mpg |   cyl |
|------:|------:|
|  21   |     6 |
|  21   |     6 |
|  22.8 |     4 |
| ... | ... |

## Global Options

### Row Numbers

Add row numbers with --row-numbers

## Compilation

```
nim c --cpu:i386 --os:linux --compileOnly tut.nim
```
