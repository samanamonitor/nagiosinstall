#!/usr/bin/python3

import sys
import iniparse
config = iniparse.RawConfigParser()

def usage():
    print("USAGE: %s <filename> <set/get> <section> <option> [<value>]" % sys.argv[0])
    exit(-1)


if len(sys.argv) < 3:
    usage()
filename=sys.argv[1]
action=sys.argv[2]
if (action == 'set' and len(sys.argv) != 6) or \
        (action == 'get' and len(sys.argv) != 5):
    usage()

section = sys.argv[3]
option = sys.argv[4]
value = sys.argv[5]
with open(filename, "r") as f:
    config.readfp(f)

with open(filename, "w") as f:
    config.set(section, option, value)
    config.write(f)
