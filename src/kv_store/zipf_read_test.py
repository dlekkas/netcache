from client_api import NetCacheClient
import numpy as np

def main():
    client = NetCacheClient(n_servers=4)

    filepath = "data/zipf_sample.txt"

    sample = list()

    with open(filepath) as fp:
        line = fp.readline()
        while line:
            sample.append(line.strip())
            line = fp.readline()

    for query in sample:
        client.read(query)

if __name__=="__main__":
    main()
