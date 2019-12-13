#include <core.p4>
#include <v1model.p4>

#include "../include/headers.p4"


control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

	#include "query_statistics.p4"

	// per-key counter to keep query frequency of each cached item
	counter((bit<32>) NETCACHE_ENTRIES * NETCACHE_VTABLE_NUM, CounterType.packets) query_freq_cnt;


    apply {

		if (hdr.netcache.isValid()) {

			// if the bitmap is not full of zeros then we had cache hit
			bool cache_hit = (meta.vt_bitmap != 0);

			if (hdr.netcache.op == READ_QUERY) {


				if (!cache_hit) {

					// waiting for the answer of the KV store allows us to
					// retrieve the actual key-value pair from the reply
					if (pkt_is_not_mirrored && hdr.udp.srcPort != NETCACHE_PORT) {

						update_count_min_sketch();
						if (meta.key_cnt >= HOT_KEY_THRESHOLD) {

							inspect_bloom_filter();
							if (meta.hot_query == 1) {
								update_bloom_filter();

								// inform the server that he will receive a read query
								// for a hot key (this is needed, so he will block until
								// the insertion in cache is completed) - cache coherence
								hdr.netcache.op = HOT_READ_QUERY;

								//clone(CloneType.E2E, CONTROLLER_MIRROR_SESSION);
							}
						}
					}

				} else {
					// update query frequency counter for cached item
					query_freq_cnt.count((bit<32>) meta.key_idx);
				}



			// if the server informs us that the delete operation on the key completed
			// successfully then we forward this packet to the controller to update the
			// cache and validate the key again
			} else if (hdr.netcache.op == DELETE_COMPLETE && cache_hit) {

				if (pkt_is_not_mirrored && hdr.tcp.srcPort == NETCACHE_PORT) {
					clone(CloneType.E2E, CONTROLLER_MIRROR_SESSION);
				}

			}

		}

	}

}
