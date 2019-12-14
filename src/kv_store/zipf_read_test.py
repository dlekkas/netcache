from client_api import NetCacheClient

import numpy as np


def main(n_servers, disable_cache):
    client = NetCacheClient(n_servers=n_servers, no_cache=disable_cache)

    filepath = "data/zipf_sample.txt"

    sample = list()

    with open(filepath) as fp:
        line = fp.readline()
        while line:
            sample.append(line.strip())
            line = fp.readline()

    for query in sample:
        client.read(query)

    print("\n########## SERVER METRICS REPORT ##########\n")
    client.request_metrics_report()

if __name__=="__main__":

    import argparse
    parser = argparse.ArgumentParser()

    parser.add_argument('--n-servers', help='number of servers', type=int, required=False, default=1)
    parser.add_argument('--disable-cache', help='disable in-network caching', action='store_true')
    args = parser.parse_args()

    main(args.n_servers, args.disable_cache)
