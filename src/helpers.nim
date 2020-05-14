import os
import strutils
import streams
import memfiles
import zip/gzipfiles


proc stream_file*(path: string): Stream =
    # Opens plain text or gzipped files
    let stream: Stream =
        if path.endsWith(".gz") or path.endsWith(".gzip"):
            newGZFileStream(path)
        else:
            #newFileStream(path, fmRead)
            newMemMapFileStream(path, fmRead)
    return stream


proc add_annotation_cols*(line: var seq[string], n: int, add_col: bool, fname: string, add_basename: bool, add_filename: bool) =
    # Adds annotation information to the line
    # add_col - the mode to operate under; Is the column being added or updated?
    if add_col:
        if add_basename or add_filename:
            if add_filename:
                if n > 0:
                    line.add fname
                else:
                    line.add("filename")
            if add_basename:
                if n > 0:
                    line.add(os.lastPathPart(fname))
                else:
                    line.add("basename")
    else:
        if add_basename or add_filename:
            if n == 0:
                if add_basename:
                    line.add("basename")
                if add_filename:
                    line.add("filename")
            else:
                if add_basename and add_filename:
                    line[^1] = os.lastPathPart(fname)
                    line[^2] = fname
                elif add_basename:
                    line[^1] = os.lastPathPart(fname)
                elif add_filename:
                    line[^1] = fname


proc infer_delim*(header_line: string): string =
    # Attempt to identify the delimiter
    for delim in ["\t", ",", "|"]:
        if header_line.split(delim).len > 1:
            return delim
    return ","

proc parse_header*(path: string, delim = "<auto>"): (seq[string], string) =
    # Parses a header and infers the delimiter
    # TODO: Extend to examine top N lines
    var parsed_header: seq[string]
    var sep: string
    var f = helpers.stream_file(path)
    if not isNil(f):
        var line = f.readLine()
        if delim == "<auto>":
            sep = infer_delim(line)
        else:
            sep = delim
        for x in line.split(sep):
            parsed_header.add(x.strip(chars = {'\"', '\''}))
    defer: f.close()
    return (parsed_header, sep)

var PRINT_RN* = false
var ROW_NUMBER* = 0

proc print_row*(line: seq[string], delim: string) =
    if PRINT_RN:
        if ROW_NUMBER == 0:
            stdout.write "rn"  & delim & line.join(delim) & "\n"
        else:
            stdout.write $ROW_NUMBER & delim & line.join(delim) & "\n"
        ROW_NUMBER += 1
    else:
        stdout.write line.join(delim) & "\n"

proc print_row*(line: string, delim: string) =
    if PRINT_RN:
        if ROW_NUMBER == 0:
            echo "rn"  & delim & line
        else:
            echo $ROW_NUMBER & delim & line
        ROW_NUMBER += 1
    else:
        echo line
