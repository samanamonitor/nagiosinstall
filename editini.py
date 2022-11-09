#!/usr/bin/python

import sys
import ConfigParser
config = ConfigParser.RawConfigParser()

def usage():
    print("USAGE: %s <filename> <set/get> <section> <option> [<value>]" % sys.argv[0])
    exit(-1)


if len(sys.argv) < 3:
    usage()
filename=argv[1]
action=argv[2]
if (action == 'set' and len(sys.argv) != 6) or \
        (action == 'get' and len(sys.argv) != 5):
    usage()

section = argv[3]
option = argv[4]
value = argv[5]
with open(filename, "r+") as f:
    config.readfp(f)
    config.set(section, option, value)
    config.write(f)
