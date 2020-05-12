import strutils
import streams
import zip/gzipfiles
import memfiles



proc stream_file*(path: string): Stream =
    # Opens plain text or gzipped files
    let stream: Stream =
        if path.endsWith(".gz") or path.endsWith(".gzip"):
            newGZFileStream(path)
        else:
            newFileStream(path, fmRead)
            #newMemMapFileStream(path, fmRead)
    return stream