import matplotlib.pyplot as plt
import numpy as np
import sys

def main(input_file):

    """
    if len(sys.argv) != 4:
        print("Usage: python3 plotqueries.py <number_of_servers> <show/save> <yaxis_limit>")
        return
    """
    """
    for i in range(1,NO_SERVERS+1):
        with open("../p4/server" + str(i) + ".log") as fp:
            last = fp.readlines()[-1]
            answered_queries = last.split("     ")[-1]
            no_queries.append(int(answered_queries.strip()))
    """

    # the code below assumes the format of the output printed by the
    # script exec_queries.py

    yvalues = []
    xlabels = []

    with open(input_file, 'r') as fp:
        lines = fp.readlines()

        for i in range(0, len(lines) - 1, 2):
            server_name = lines[i].split(']')[0][1:]
            n_requests = lines[i].split('=')[1].strip()
            throughput = lines[i+1].split('=')[1].strip()

            yvalues.append(int(n_requests))
            xlabels.append(server_name)


    xvalues = range(1, len(xlabels) + 1)

    plt.bar(xvalues, yvalues)
    plt.xticks(xvalues, xlabels)

    axes = plt.gca()
    axes.set_ylim([0, 1.3 * max(yvalues)])

    plt.savefig("plot.png")


if __name__=="__main__":

    import argparse
    parser = argparse.ArgumentParser()

    parser.add_argument('--input', help='input file of results to generate plot', required=True)
    args = parser.parse_args()

    main(args.input)
