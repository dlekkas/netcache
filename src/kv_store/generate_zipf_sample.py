import numpy as np
from random import shuffle

def main(n_servers, n_queries):

    ZIPF_PARAM = 2.0

    keys = list()
    sample = list()

    # adds all generated keys to the set of keys to sample from
    for i in range(1,1+int(n_servers)):
        with open('data/server'+str(i)+'.txt') as f:
            content = f.readlines()
        content = [x.strip().split('=')[0] for x in content]
        keys.extend(content)

    # shuffle keys
    shuffle(keys)

    # draw random query items
    while len(sample) < int(n_queries):

        # zipf distribution will return any natural number (>= 1)
        # the probability decreases for larger values
        # when the index is larger than the number of keys
        # we sample, we simply try again
        query_index = np.random.zipf(ZIPF_PARAM, 1)[0]
        if query_index <= len(keys):
            sample.append(keys[query_index-1])

    with open('data/zipf_sample.txt', 'w') as f:
    	for query_item in sample:
            f.write("%s\n" % query_item)

if __name__=="__main__":

    import argparse
    parser = argparse.ArgumentParser()

    parser.add_argument('--n_servers')
    parser.add_argument('--n_queries')
    args = parser.parse_args()

    main(args.n_servers, args.n_queries)
