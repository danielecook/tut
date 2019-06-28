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

from posix import signal, SIG_PIPE, SIG_IGN
signal(SIG_PIPE, SIG_IGN)


var PRINT_RN = false
var ROW_NUMBER = 0

proc print_row(line: seq[string], delim: string) =
    if PRINT_RN:
        if ROW_NUMBER == 0:
            echo "rn"  & delim & line.join(delim)
        else:
            echo $ROW_NUMBER & delim & line.join(delim)
        ROW_NUMBER += 1
    else:
        echo line.join(delim)

proc print_row(line: string, delim: string) =
    if PRINT_RN:
        if ROW_NUMBER == 0:
            echo "rn"  & delim & line
        else:
            echo $ROW_NUMBER & delim & line
        ROW_NUMBER += 1
    else:
        echo line


proc quit_error*(msg: string, error_code = 1) =
    stderr.write_line "Error".bgWhite.fgRed & fmt": {msg}".fgRed
    quit(error_code)

proc quit_error*(E: ref Exception, error_code = 1) =
    stderr.write_line ($E.name).bgWhite.fgRed & fmt": {E.msg}".fgRed
    quit(error_code)


proc infer_delim(header_line: string): string =
    # Attempt to identify the delimiter
    for delim in ["\t", ",", "|"]:
        if header_line.split(delim).len > 1:
            return delim
    return ","

proc parse_header(path: string, delim = "<auto>"): (seq[string], string) =
    # Parses a header and infers the delimiter
    # TODO: Extend to examine top N lines
    var parsed_header: seq[string]
    var sep: string
    var f = openFileStream(filename = path, mode = fmRead)
    if not isNil(f):
        var line = f.readLine()
        f.close()
        if delim == "<auto>":
            sep = infer_delim(line)
        else:
            sep = delim
        var c: uint32 = 0
        for x in line.split(sep):
            parsed_header.add(x.strip(chars = {'\"', '\''}))
    return (parsed_header, sep)

proc add_annotation_cols(line: var seq[string], n: int, add_col: bool, fname: string, add_basename: bool, add_filename: bool) =
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
                if add_basename and add_basename:
                    line[^1] = os.lastPathPart(fname)
                    line[^2] = fname
                elif add_basename:
                    line[^1] = os.lastPathPart(fname)
                elif add_filename:
                    line[^1] = fname


proc stack(files: seq[string], sep: var string, output_sep: var string, add_filename: bool, add_basename: bool) =
    var
        stack_header: seq[string]
        header: seq[string]
        columns: seq[string]
        delim: string
        match_col: int

    # Generate stack header and infer delimiters
    for path in files:
        (columns, delim) = parse_header(path, sep)
        for col in columns:
            if col != "" and (col in stack_header) == false:
                stack_header.add col

    if output_sep in ["tab", "tabs", "\t"]:
        output_sep = "\t"
    
    # Look for file lists
    #if files.len == 1 and files[0].endsWith(".list"):
    #    files = openFileStream(filename = files[0], mode = fmRead)
    # Collate collumns
    var header_out = false
    for path in files:
        # Print header
        (header, delim) = parse_header(path)
        var col_out = newSeq[string](stack_header.len)
        var n = 0
        for line in lines(path):
            if n > 0:
                var sep_use = sep
                var cols: seq[string]
                for x in line.split(sep):
                    cols.add x.strip(chars = {'\"', '\''})
                for ncol in 0..<header.len:
                    match_col = stack_header.find(header[ncol
                    ])
                    if match_col > -1 and ncol <= (cols.len - 1):
                        col_out[match_col] = cols[ncol]
                print_row(col_out, output_sep)
            elif n == 0:
                if sep == "<auto>":
                    sep = infer_delim(line)
                if output_sep == "<auto>":
                    output_sep = infer_delim(line)
            if header_out == false:
                # Infer line delimiter of first file and output header
                print_row(stack_header, output_sep)
                header_out = true
            n += 1

proc slice(line_range: string, files: seq[string], add_filename: bool, add_basename: bool) =
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
            r_start = parseInt(range_split[0])
        if str_end == "":
            r_end = high(int)
        else:
            r_end = parseInt(range_split[1])
    except ValueError:
        quit_error(malformed_msg)
    for f in files:
        var n = 0
        for line in lines(f):
            var delim = infer_delim(line)
            if n >= r_start and n <= r_end:
                var line_out = @[line]
                if add_filename or add_basename:
                    add_annotation_cols(line_out, n, true, f, add_filename, add_basename)
                    print_row(line_out, delim)
                else:
                    print_row(line, delim)
            n += 1
            
proc select(cols_string: string, files: seq[string], add_col: bool, sep: string, add_basename: bool, add_filename: bool) =
    let cols = cols_string.split(",")
    var delim: string
    var columns: seq[string]
    var line_out = newSeq[string](cols.len)
    var added_header = false

    # Determine what type of selection is happening
    try:
        # If all columns are integers, we can simply output cols by index
        var select_cols = cols.map(parseInt)


        for file_n in 0..<files.len:
            var path = files[file_n]
            (columns, delim) = parse_header(path, sep)
            var n = 0
            for line in lines(path):
                # If its the first file, ok to print the column header
                if file_n == 0 or n > 0:
                    add_annotation_cols(line_out, n, false, path, add_filename, add_basename)
                    for i in 0..<select_cols.len:
                        line_out[i] = line.split(delim)[select_cols[i]]
                    print_row(line_out, delim)
                n += 1

    except ValueError:
        #[
             If columns are referenced by name, we'll need
             to rely on a hash table to select them.
        ]#
        var select_cols = cols
        var column_indices = newSeq[int](select_cols.len)


        for file_n in 0..<files.len:
            var n = 0
            var path = files[file_n]
            (columns, delim) = parse_header(path, sep)

            for col in 0..<select_cols.len:
                var col_index = columns.find(select_cols[col])
                if col_index > -1:
                    column_indices[col] = col_index
                else:
                    try:
                        column_indices[col] = select_cols[col].parseInt
                    except ValueError:
                        column_indices[col] = -1
                        # Show user warning here?
                        discard
            
            for line in lines(path):
                if file_n == 0 or n > 0:
                    add_annotation_cols(line_out, n, false, path, add_filename, add_basename)
                    var current_line = line.split(delim)
                    for col in 0..<column_indices.len:
                        if column_indices[col] > -1:
                            line_out[col] = current_line[column_indices[col]]
                        else:
                            if n > 0:
                                line_out[col] = ""
                            else:
                                line_out[col] = select_cols[col]
                    print_row(line_out, delim)
                n += 1


proc check_file(fname: string): bool =
    if not fileExists(fname):
        quit_error(fmt"{fname} does not exist or is not readable")
        return false
    return true


proc parse_file_list(fnames: seq[string]): seq[string] =
    var fnames_set: seq[string]
    for path in fnames:
        if path.endsWith(".list"):
            stderr.write_line "Load".bgWhite.fgGreen & fmt" files listed in '{path}'"
            for line in lines(path):
                if check_file(line):
                    fnames_set.add line
        else:
            if check_file(path):
                fnames_set.add path
    return fnames_set



var p = newParser("tut"):
    flag("--row-numbers", help="Add Row Numbers")
    flag("--debug", help="Debug")
    help("Table Utilities")

    command("select"):
        flag("-a", "--add-filename", help="Create a right-most column for the filename")
        flag("-b", "--add-basename", help="Create a right-most column for the basename")
        option("-d", "--delimiter", help="The field separater", default="<auto>")
        arg("cols", nargs= 1, help="A comma-delimted list of column numbers or names. Use '0' for everything.")
        arg("files", nargs= -1, help="Path")
        help("Select columns by name or index")
        run:
            if commandLineParams().len == 1:
                stderr.write p.help()
            elif opts.files.len == 0:
                quit_error("No files specified")
                quit()
            else:
                select(opts.cols, parse_file_list(opts.files), opts.add_filename, opts.delimiter, opts.add_filename, opts.add_basename)
            quit()

    command("slice"):
        flag("-a", "--add-filename", help="Create a right-most column for the filename")
        flag("-b", "--add-basename", help="Create a right-most column for the basename")
        arg("range", nargs= 1, help="A range of lines to slice (e.g. 1:20, :31, 30:)")
        arg("files", nargs= -1, help="Path")
        help("Get a range of rows from files")
        run:
            if commandLineParams().len == 1:
                stderr.write p.help()
            elif opts.files.len == 0:
                quit_error("No files specified")
                quit()
            else:
                slice(opts.range, parse_file_list(opts.files), opts.add_filename, opts.add_basename)
            quit()

    command("stack"):
        arg("files", nargs= -1, help="List files to stack")
        option("-t", "--threads", help="Threads")
        option("-d", "--delimiter", help="The field separater", default="<auto>")
        option("-p", "--output-delimiter", help="Separater to output; Defaults to that found in first file", default="\t")
        #flag("-s", "--slugify", help="Slugify field names")
        flag("-a", "--add-filename", help="Create a right-most column for the filename")
        flag("-b", "--add-basename", help="Create a right-most column for the basename")
        flag("-g", "--group", help="Add a column for the source field")
        flag("--debug", help="Debug")
        help("Combine delimited files by column")
        run:
            if commandLineParams().len == 1:
                stderr.write p.help()
            elif opts.files.len == 0:
                quit_error("No files specified")
                quit()
            var file_set = parse_file_list(opts.files)
            stack(file_set, opts.delimiter, opts.outputDelimiter, opts.add_filename, opts.add_basename)
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

