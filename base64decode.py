#!/usr/bin/env python3
#
# save this as a file with the .py extension and chmod +x
# usage: script.py /path/to/export.exp

import base64
import sys

def base64_convert():
    if len(sys.argv) > 1 :
        infile = open(sys.argv[1])
    else :
        print('Usage: ' + sys.argv[0] + ' file.exp')
        sys.exit(10)

    config = base64.b64decode(infile.read().encode()).decode('utf-8').replace('&', '\n')
    infile.close()

    print(config)

if __name__ == "__main__":
    base64_convert()
