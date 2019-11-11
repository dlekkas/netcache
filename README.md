# NetCache: Balancing Key-Value Stores with Fast In-Network Caching

#### Authors
* Dimitris Lekkas (dlekkasp@gmail.com)
* Malte Brodmann (mbrodmann@student.ethz.ch)

This is an open source implementation of the [NetCache paper](https://www.cs.jhu.edu/~xinjin/files/SOSP17_NetCache.pdf).
Unlike the paper that targets the Tofino chip, we implement NetCache while targeting the
BMv2 simple\_switch architecture. Since the main principles of the implementation stay the same,
this repository can also be used as a reference for any target architecture.
