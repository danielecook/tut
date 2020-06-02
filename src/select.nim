import sequtils
import helpers
import parsecsv
import strutils
import streams

proc select*(cols_string: string, files: seq[string], add_col: bool, sep: string, add_basename: bool, add_filename: bool) =
    let cols = cols_string.split(",")
    var delim: string
    var columns: seq[string]
    var line_out = newSeq[string](cols.len)
    var n = 0

    var csv: CsvParser
    
    # Determine what type of selection is happening
    try:
        # If all columns are integers, we can simply output cols by index
        var select_cols = cols.mapIt(it.parseInt - 1)

        for file_n in 0..<files.len:
            var path = files[file_n]
            (columns, delim) = parse_header(path, sep)
            open(csv, path, separator = delim[0])
            while readRow(csv):
                print_row(select_cols.mapIt(csv.row[it]), delim)

    except ValueError:
        #[
             If columns are referenced by name, we'll need
             to rely on a hash table to select them.
        ]#
        var select_cols = cols
        var column_indices = newSeq[int](select_cols.len)


        for file_n in 0..<files.len:
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

            for line in stream_file(path).lines:
                if file_n == 0 or n > 0:
                    add_annotation_cols(line_out, n, false, path, add_basename, add_filename)
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
