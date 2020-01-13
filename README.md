# NetCache: Balancing Key-Value Stores with Fast In-Network Caching

This is an open source implementation of the [NetCache paper](https://www.cs.jhu.edu/~xinjin/files/SOSP17_NetCache.pdf).
Unlike the paper that targets the Tofino chip, we implement NetCache while targeting the
BMv2 simple\_switch architecture. Since the main principles of the implementation stay the same,
this repository can also be used as a reference for any target architecture.


## Introduction
Recent advancements on the field of programmable switches along with the introduction of
the PISA architecture has enabled us to rethink and redesign various systems by allowing
us to program the switch packet-processing pipeline while being able to operate at line-rate.
Many key value stores have shifted away from flash and disk based storage to keeping their
data in-memory which requires a layer that could handle queries significanlty faster if we
want to provide caching functionality. Netcache exploits the capabilities of modern switches
to provide such a layer and offers in-network caching for in-memory key value stores.

Netcache is a novel approach of implementing a blazingly fast cache residing inside the switch.
Due to the current limitations in terms of memory on the programmable switches, this cache is
not supposed to be an ordinary fully-fledged cache, rather it is supposed to achieve a medium
cache hit ratio (< 50 %). This ratio proves to be sufficient to serve as a load balancer
because highly skewed workloads with disproportionately more accesses to a few hot keys
comprise most of the real-world access patterns in typical key-value stores.

Our Netcache implementation contains the following components:
*  Data plane design of the P4 switch
*  Controller using Thrift API to dynamically modify P4 switch behavior (control plane)

Apart from the Netcache implementation, we also implemented the following:
*  Simple distributed in-memory key value store (without data replication)
*  Python client API for our in-memory key value store

## System Architecture
The architecture of Netcache is divided in the data-plane logic which is implemented
in P4 and runs directly inside the switch (by compiling and loading the executable),
and the control-plane logic which is implemented in Python and utilizes the Thrift
API to dynamically modify various components of the switch (e.g match-action tables
and registers).

The data plane design is optimized to utilize as less memory as possible since it
is restricted by the memory limitations of the P4 switch. On the other hand, the
controller runs in a typical machine (e.g server) and its communication with the
switch does not require massive optimization since this communication is not
happening on the critical data path.


### Data-Plane Design
The data plane architecture of Netcache comprises of the following important modules:
*  Value Processing Module
*  Query Statistics Module
*  L2/L3 Forwarding Module


#### Value Processing module
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


#### Query Statistics module
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


![Query Statistics Module](https://github.com/dlekkas/netcache/blob/master/report/figures/query_statistics.jpg)

Additionally, to restrict the numbers of bits used by each array index of the count-min sketch,
bloom filter and also by the counters of cached keys, Netcache employs a scheme of reseting
the registers after a configurable time interval. In contrast with the paper, we have not
employed a sampling component in front of the query statistics module and we rather prefer
to examine all packets to extract our statistics.


#### L2/L3 Forwarding module
This module employs the typical networking functionality and is responsible for forwarding or
routing packets by using standard L2/L3 protocols. In our case, since the routing/forwarding
behavior was not our primary goal, we have currently implemented a simple static l2 forwarding
scheme.to

The controller on start up, reads the topology and all the interconnected interfaces and populates
an l2 forwarding match-action table inside the P4 switch which contains static assignments by
matching on the L2 destination address and by providing the egress port that the corresponding
packet should be forwarded to.


### Controller
The controller has the responsibility of receiving hot key reports from the switch and updating
the cache accordingly by modifying the lookup table inside the P4 switch and by allocating the
memory required to store the value. As mentioned before (value processing module), the memory
of where the value resides is represented by a tuple of an index and a bitmap.

#### Memory Management Unit
To decide where to place each key-value pair in the cache, the controller implements the
First-Fit algorithm which is a classic heuristic algorithm for bin packing problems and we
use this approach to allocate memory slots to a given key. To evict a key we simply deallocate
its memory by representing those memory slots as empty and adding them again to the memory
pool of the controller.

#### Cache Eviction Policy
As proposed by the Netcache paper, we use an eviction policy similar to the policy employed by
Redis 3.0 (described in [Redis blog](https://redis.io/topics/lru-cache). In contrast to the
paper we do not take into account the counters of the uncached keys by the count-min sketch
and we rather prefer to only use the counters for cached keys.

Particularly, we employ an approximated LFU (Least Frequently Used) algorithm by periodically
checking whether we have exceeded a specific memory usage (e.g 80%) and if we are above this
limit then we sample a configurable amount of the cached keys and we evict from cache the K
keys with the smallest counters. This operation can be implemented efficiently by using
quick select algorithm to find the K elements with the smallest values.


#### Cache Coherency Unit
Since the controller inserts and deletes items from cache we should ensure that cache
coherency is also achieved and to assure that we need the controller to be able to
communicate with the key value store servers.

The controller maintains an out-of-band channel to communicate with the servers through
Unix sockets due to the peculiarities of enabling ordinary TCP/IP communication between
them (e.g residing in different network namespaces).

When a delete/insert is completed, the controller informs the server in order to tell
him to stop blocking further updates on the given key.


## Key Value Store
In order to evaluate Netcache we implemented our own in-memory distributed key value store
based on simple primitives but we also wanted this key value store to be able to adequately
serve multiple clients and multiple servers present in our experiment scenarios.

### Partitioning Scheme
For our key-value store we decided to shard our data based on a simple range based partitioning
scheme. Basically, we decide where to store each key by taking into account only its first letter
and using this letter to get the integer corresponding to its ascii representation.

We also want to experiment with consistent hashing partioning with offers much more robust
partitioning and is also used widely by several distributed database products. Though, by
prepopulating the servers with values we could equally load them with data and avoid skewness
that would appear for such a partioning scheme in a real-world scenario.


