from random import shuffle

import numpy as np
import argparse

DATA_DIR='data/'

def main(n_servers, n_queries, skew):

    alpha = 1.0 / (1.0 - skew)

    keys = []
    sample = []

    # adds all generated keys to the set of keys to sample from
    for i in range(1, 1+int(n_servers)):
        with open(DATA_DIR + 'server' + str(i) + '.txt') as f:
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
        query_index = np.random.zipf(alpha, 1)[0]
        if query_index <= len(keys):
            sample.append(keys[query_index-1])


    sample_file = '{}zipf_sample_{}_{}.txt'.format(DATA_DIR, n_queries,
            str(skew).replace('.',''))

    with open(sample_file, 'w') as f:
    	for query_item in sample:
            f.write("%s\n" % query_item)



def check_valid_skew(value):
    ivalue = float(value)
    if ivalue >= 1 or ivalue <= 0:
        raise argparse.ArgumentTypeError("value should be (0 < skew < 1)")
    return ivalue

if __name__=="__main__":

    parser = argparse.ArgumentParser()

    parser.add_argument('--n-servers', help='number of servers', type=int, required=True)
    parser.add_argument('--n-queries', help='number of queries to generate', type=int, required=True)
    parser.add_argument('--skew', help='skewness of the workload (0 < skew < 1)', type=check_valid_skew,
            required=False, default=0.9)
    args = parser.parse_args()

    main(args.n_servers, args.n_queries, args.skew)
