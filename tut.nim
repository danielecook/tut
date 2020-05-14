import os
import sugar
import sequtils
import argparse
import colorize
import strformat
import strutils
import tables
import streams
import terminal
import parseutils
import memfiles

import src/stack
import src/select
from math import sum

import src/helpers

from posix import signal, SIG_PIPE, SIG_IGN
signal(SIG_PIPE, SIG_IGN)



proc quit_error*(msg: string, error_code = 1) =
    stderr.write_line "Error".bgWhite.fgRed & fmt": {msg}".fgRed
    quit(error_code)

proc quit_error*(E: ref Exception, error_code = 1) =
    stderr.write_line ($E.name).bgWhite.fgRed & fmt": {E.msg}".fgRed
    quit(error_code)


proc slice(line_range: string, files: seq[string], add_basename: bool, add_filename: bool) =
    var
        r_start: int
        r_end: int
    
    let malformed_msg = "Malformed range; Must be <start:int>:<end:int>"

    # Allow extraction of a single line
    if (":" in line_range) == false:
        quit_error(malformed_msg)
    var range_split = line_range.split(":")
    var str_start = range_split[0]
    var str_end = range_split[1]
    if len(range_split) != 2:
        quit_error(malformed_msg)
    try:
        if str_start == "":
            r_start = 0
        else:
            # Subtract 1 to make 1-based
            r_start = parseInt(range_split[0]) - 1
        if str_end == "":
            r_end = high(int)
        else:
            # Subtract 1 to make 1-based
            r_end = parseInt(range_split[1]) - 1
    except ValueError:
        quit_error(malformed_msg)
    for f in files:
        var n = 0
        for line in lines(f):
            var delim = infer_delim(line)
            if n >= r_start and n <= r_end:
                var line_out = @[line]
                if add_basename or add_filename:
                    add_annotation_cols(line_out, n, true, f, add_basename, add_filename)
                    print_row(line_out, delim)
                else:
                    print_row(line, delim)
            n += 1


proc wc(fn: string): tuple[linec, wordc, bytec: int] =
    # https://github.com/nim-lang/Nim/issues/9026#issuecomment-423632254
    # Fast wordcount
    var mf = memfiles.open(fn)
    var cs: cstring
    var linec, wordc, bytec: int
    var inWord: bool
    var s: string
    for slice in memSlices(mf):
      inc(linec)
      cs = cast[cstring](slice.data)
      let length = slice.size
      inc(bytec, length)
      var j = -1
      for i in 0..length-1:
        j = i
        if cs[i] in WhiteSpace:
          if inWord == true:
            inc(wordc)
            inWord = false
        else:
          inWord = true
      if j >= 0:
        inc(wordc)
    result.linec = linec
    result.wordc = wordc
    result.bytec = bytec + linec

proc count_n(files: seq[string], add_basename: bool, add_filename: bool) =
    for fname in files:
        var result = wc(fname)
        var output = &"{result.linec}\t{result.wordc}\t{result.bytec}" 
        if add_basename:
            output = output & &"\t{os.lastPathPart(fname)}"
        if add_filename:
            output = output & &"\t{fname}"
        echo output


proc check_file(fname: string): bool =
    if fname.existsFile() and not fileExists(fname):
        quit_error(fmt"{fname} does not exist or is not readable")
        return false
    return true


proc parse_file_list(fnames: seq[string], skip_empty = false): seq[string] =
    var fnames_set: seq[string]
    for path in fnames:
        if path.endsWith(".list"):
            stderr.write_line "Load".bgWhite.fgGreen & fmt" files listed in '{path}'"
            for line in lines(path):
                if check_file(line):
                    fnames_set.add line
        else:
            if check_file(path) and path.existsFile():
                fnames_set.add path
    # filter empty files if ignore-empty
    if skip_empty:
        fnames_set = fnames_set.filterIt(it.getFileSize() > 0)
    else:
        let empty_files = fnames_set.filterIt(it.getFileSize() == 0)
        if empty_files.len > 0:
            quit_error(fmt"""There are empty file(s): {empty_files.join(", ")}""", 1)
    return fnames_set



var p = newParser("tut"):
    flag("--row-numbers", help="Add Row Numbers")
    flag("--debug", help="Debug")
    help("Table Utilities")

    command("select"):
        flag("-a", "--add-filename", help="Create a right-most column for the filename")
        flag("-b", "--add-basename", help="Create a right-most column for the basename")
        option("-d", "--delimiter", help="The field separater", default="<auto>")
        arg("cols", nargs= 1, help="A comma-delimted list  of column numbers (1-based) or names. Use '0' for everything.")
        arg("files", nargs= -1, help="Path")
        help("Select columns by name or index")
        run:
            if commandLineParams().len == 1:
                stderr.write p.help()
            elif opts.files.len == 0:
                quit_error("No files specified")
                quit()
            else:
                select.select(opts.cols, parse_file_list(opts.files), opts.add_basename, opts.delimiter, opts.add_basename, opts.add_filename)
            quit()

    command("slice"):
        flag("-a", "--add-filename", help="Create a right-most column for the filename")
        flag("-b", "--add-basename", help="Create a right-most column for the basename")
        arg("range", nargs= 1, help="A range of lines to slice (e.g. 1:20, :31, 30:); 1-based")
        arg("files", nargs= -1, help="Path")
        help("Get a range of rows from files")
        run:
            if commandLineParams().len == 1:
                stderr.write p.help()
            elif opts.files.len == 0:
                quit_error("No files specified")
                quit()
            else:
                slice(opts.range, parse_file_list(opts.files), opts.add_basename, opts.add_filename)
            quit()

    command("count"):
        flag("-a", "--add-filename", help="Create a right-most column for the filename")
        flag("-b", "--add-basename", help="Create a right-most column for the basename")
        arg("files", nargs= -1, help="Path")
        help("Count the number of records in a file")
        run:
            if commandLineParams().len == 1:
                stderr.write p.help()
            elif opts.files.len == 0:
                quit_error("No files specified")
                quit()
            else:
                count_n(parse_file_list(opts.files), opts.add_basename, opts.add_filename)
            quit()

    command("stack"):
        arg("files", nargs= -1, help="List files to stack")
        option("-d", "--delimiter", help="The field separater", default="<auto>")
        option("-p", "--output-delimiter", help="Separater to output; Defaults to that found in first file", default="\t")
        option("-n", "--header", help="Output the header", default="true")
        option("-k", "--skip-empty-lines", help="Skip empty lines", default="true")
        flag("-i", "--skip-empty", help="Skip over empty files")
        flag("-a", "--add-filename", help="Create a right-most column for the filename")
        flag("-b", "--add-basename", help="Create a right-most column for the basename")
        flag("--debug", help="Debug")
        help("Combine delimited files by column")
        run:
            if (opts.header in ["true", "false"]) == false:
                quit_error("--header must be set to true or false")

            if commandLineParams().len == 1:
                stderr.write p.help()
            elif opts.files.len == 0:
                quit_error("No files specified")
                quit()
            var file_set: seq[string]
            for fname in opts.files:
                if '*' in fname:
                    for ls_file in os.walkFiles(fname):
                        file_set.add(ls_file)
                else:
                    file_set.add(fname)
            var file_set_checked = parse_file_list(file_set, opts.skipEmpty)
            stack.stack(file_set_checked,
                        opts.delimiter,
                        opts.outputDelimiter,
                        opts.skip_empty_lines=="true",
                        opts.header=="true",
                        opts.add_basename,
                        opts.add_filename)
            quit()
    command("cascade"):
        arg("files", nargs= -1, help="List files to cascade")
        option("-d", "--delimiter", help="The field separater", default="<auto>")
        option("-p", "--output-delimiter", help="Separater to output; Defaults to that found in first file", default="\t")
        option("-k", "--keys", help="Select keys", default="true")
        flag("-a", "--add-filename", help="Create a right-most column for the filename")
        flag("-b", "--add-basename", help="Create a right-most column for the basename")
        flag("--debug", help="Debug")
        help("Combine delimited files by column")
        run:
            #if (opts.header in ["true", "false"]) == false:
            #    quit_error("--header must be set to true or false")

            if commandLineParams().len == 1:
                stderr.write p.help()
            elif opts.files.len == 0:
                quit_error("No files specified")
                quit()
            var file_set: seq[string]
            for fname in opts.files:
                if '*' in fname:
                    for ls_file in os.walkFiles(fname):
                        file_set.add(ls_file)
                else:
                    file_set.add(fname)
            var file_set_checked = parse_file_list(file_set)
            #stack(file_set_checked, opts.delimiter, opts.outputDelimiter, opts.header=="true",  opts.add_basename, opts.add_filename)
            quit()

# Check if input is from pipe
var input_params = commandLineParams()
if getFileInfo(stdin).id.file==37:
    if input_params.find("-") > -1:
       input_params[input_params.find("-")] = "STDIN"
    else:
        input_params.add("STDIN")

if commandLineParams().len == 0:
    stderr.write p.help()
    quit()
else:
    
    # Allow for global options to be specified anywhere in CLI
    if input_params.find("--row-numbers") > -1:
        input_params = input_params.filterIt(it != "--row-numbers")
        input_params.insert("--row-numbers", 0)

    try:
        var opts = p.parse(input_params)
        if opts.row_numbers:
            PRINT_RN = true
        p.run(input_params)
    except UsageError as E:
        input_params.add("-h")
        p.run(input_params)
    except Exception as E:
        if commandLineParams().find("--debug") > -1:
            stderr.write_line "Error".bgWhite.fgRed & fmt": {E.msg}".fgRed
            raise
        else:
            quit_error(E)

