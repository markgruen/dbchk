import re
import sys
import argparse
from operator import itemgetter
import psutil

def get_oratab(oratab_path):
    oratab = ''
    with open(oratab_path, 'r') as oraf:
        oratab = [line for line in oraf if line.strip() and 
                    not line.strip().startswith('#')]
    return oratab

def main(oratab):

    sids = [sid.split(':')[0] for sid in oratab]
    pmons = [psutil.Process(p).cmdline()[0].split('_')[2] for p in psutil.pids() 
                if psutil.Process(p).cmdline() != [] and 
                re.search(r'ora_pmon_[a-zA-Z0-9]+', psutil.Process(p).cmdline()[0])]
    orastat = [(sid, ('Down', 'Up')[sid in pmons]) for sid in sids]
    sorted(sorted(orastat, key=itemgetter(0)), key=itemgetter(1), reverse=True)
    print('\n'.join(['{:>12} : {}'.format(*e) for e in orastat]))


if __name__ == '__main__': 
    parser = argparse.ArgumentParser(description='Check instances configured in /etc/oratab and status')
    parser.add_argument('oratab_path', nargs='?', metavar='oratab path')
    args = parser.parse_args()
    if args.oratab_path:
        oratab = get_oratab(args.oratab_path)
    elif not sys.stdin.isatty():
        oratab = [line for line in sys.stdin if line.strip() and
                    not line.strip().startswith('#')]
    else:
        parser.print_help()
        sys.exit(0)
    main(oratab)
