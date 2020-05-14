import sequtils
import helpers



import strutils
import streams


from math import sum

proc stack*(files: seq[string], sep: var string, delim_out: var string, skip_empty_lines: bool, header_out: bool, add_basename: var bool, add_filename: var bool) =
    var
        stack_header: seq[string]
        header: seq[string]
        columns: seq[string]
        delim: string
        match_col: int
        output_header = header_out
        add_col = true
        anno_added = false

    # Generate stack header and infer delimiters
    for path in files:
        (columns, delim) = parse_header(path, sep)
        for col in columns:
            if col != "" and (col in stack_header) == false:
                stack_header.add col
        if anno_added == false:
            add_annotation_cols(stack_header, 0, add_col, path, add_basename, add_filename)
            anno_added = true

    if delim_out in ["tab", "tabs", "\t"]:
        delim_out = "\t"
    
    # Collate columns
    for path in files:
        # Print header
        (header, delim) = helpers.parse_header(path)
        # Reduce the line out by the length of added columns to prevent
        # extra blank columns from appearing
        let anno_col_length = @[add_basename, add_filename].mapIt(cast[int](it)).sum()
        var line_out = newSeq[string](stack_header.len - anno_col_length)
        var n = 0
        for line in helpers.stream_file(path).lines:
            if skip_empty_lines and line.strip() == "":
                continue
            add_annotation_cols(line_out, n, false, path, add_basename, add_filename)
            if n > 0:
                var sep_use = sep
                var cols: seq[string]
                for x in line.split(sep):
                    cols.add x.strip(chars = {'\"', '\''})
                for ncol in 0..<header.len:
                    match_col = stack_header.find(header[ncol]) 
                    if match_col > -1 and ncol <= (cols.len - 1):
                        line_out[match_col] = cols[ncol]
                print_row(line_out, delim_out)
            elif n == 0:
                if sep == "<auto>":
                    sep = infer_delim(line)
                if delim_out == "<auto>":
                    delim_out = infer_delim(line)
            if output_header == true:
                # Infer line delimiter of first file and output header
                print_row(stack_header, delim_out)
                output_header = false
            n += 1