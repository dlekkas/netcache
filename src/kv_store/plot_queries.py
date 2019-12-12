import matplotlib.pyplot as plt
import numpy as np
import sys

def main():

    if len(sys.argv) != 4:
        print("Usage: python3 plotqueries.py <number_of_servers> <show/save> <yaxis_limit>")
        return

    NO_SERVERS = int(sys.argv[1])

    no_queries = list()

    for i in range(1,NO_SERVERS+1):
        with open("../p4/server" + str(i) + ".log") as fp:
            last = fp.readlines()[-1]
            answered_queries = last.split("     ")[-1]
            no_queries.append(int(answered_queries.strip()))

    server_names = ["Server"+str(i) for i in range(1,NO_SERVERS+1)]

    xvals = range(1,NO_SERVERS+1)
    plt.bar(xvals,no_queries)
    plt.xticks(xvals, server_names)

    axes = plt.gca()
    axes.set_ylim([0,int(sys.argv[3])])

    if sys.argv[2] == "show":
        plt.show()
    elif sys.argv[2] == "save":
        plt.savefig("plot.png")
    else:
        print("Unknown option: " + sys.argv[2])

if __name__=="__main__":
    main()
