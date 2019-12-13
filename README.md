# NetCache: Balancing Key-Value Stores with Fast In-Network Caching

#### Authors
* Dimitris Lekkas (dlekkasp@gmail.com)
* Malte Brodmann (mbrodmann@student.ethz.ch)

This is an open source implementation of the [NetCache paper](https://www.cs.jhu.edu/~xinjin/files/SOSP17_NetCache.pdf).
Unlike the paper that targets the Tofino chip, we implement NetCache while targeting the
BMv2 simple\_switch architecture. Since the main principles of the implementation stay the same,
this repository can also be used as a reference for any target architecture.



## Introduction
Recent advancements on the field of programmable switches along with the introduction of
the PISA architecture has enabled us to rethink and redesign various systems by allowing
us to program the switch packet-processing pipeline while being able to operate at line-rate.
Many key value stores have shifted away from flash and disk based storage to keeping their
data in-memory which requires a layer that could reply queries significanlty faster if we
want to provide caching functionality. Netcache exploits the capabilities of modern switches
to provide such a layer and offer caching for in-memory key value stores.

Netcache is a novel approach of implementing a blazingly fast cache residing inside the switch.
Due to the current limitations in terms of memory on the programmable switches, this cache is
not supposed to be an ordinary fully-fledged cache, rather it is supposed to achieve a medium
cache hit ratio (< 50 %). This ratio proves to be sufficient to serve as a load balancer
because highly skewed workloads with disproportionately more accesses to a few hot keys
comprise most of the real-world access patterns in typical key-value stores.

## System Architecture
Netcache basically comprises of the following important modules:
*  Value Processing module
*  Query Statistics module
*  L2/L3 Forwarding module


### Value Processing module
This module is responsible for producing the actual values that will be returned to the
client who is performing the query. One major constraint of the P4 switches is that they
provide limited memory at each stage which does not enable us to keep the full cache as
a simple register array inside the switch. To circumvent this constraint, multiple
register arrays are used (along with multiple stages) and their values are combined
to produce the actual value.

To efficiently combine the values of each register array, the controller assigns to each key
inserted in the cache an index along with a bitmap (through match-action table)
which is later used by the packet processing pipeline to recreate the value corresponding
to this key. The index will be the position that will be accessed in the register array
at each stage, while the bitmap will indicate whether a register array at a specific stage
will contribute its value to the final value. This approach allows minimum memory consumption
while also surpassing the limit of being able to store only significantly small values
inside the switch.


### Query Statistics module
This module is responsible for deciding which key value pairs should be actually inserted
into the cache. The architecture of this module is also optimized to surpass the memory
constraints of the switch. The typical approach of keeping counters for each key accessed
and then inserting the most popular ones is not immediately applicable because there is not
enough memory to deploy such a solution. Netcache takes a probabilistic approach to this
problem by trading accuracy for less memory space.

For the above reasons, Netcache maintains the following probabilistic data structures:
*  Count-Min Sketch to keep the approximate frequency of queries on uncached keys
*  Bloom-Filter to avoid reporting hot keys multiple times to the controller
*  Register array of packet counters to count accesses to cached keys

Below, we provide the figure describing the query statistics module as presented in the paper:
![alt text](https://github.com/dlekkas/netcache/tree/master/report/figures/query_statistics.jpg)



In contrast with the paper, we have not employed a sampling component in front of the query
statistics module and we rather prefer to examine all packets to extract our statistics.

Additionally, to restrict the numbers of bits used by each array index of the count-min sketch,
bloom filter and also by the counters of cached keys, Netcache employs a scheme of reseting
the registers after a configurable time interval.

