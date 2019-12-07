#include <core.p4>
#include <v1model.p4>

#include "../include/headers.p4"


control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    // register storing a bit to indicate whether an element in the cache
    // is valid or invalid. there are as many entries as slots in our
    // register array in the egress pipeline. hence we assume for now that
    // each slot will only store one cached item
    register<bit<1>>(NETCACHE_ENTRIES) cache_status;

	action drop() {
		mark_to_drop(standard_metadata);
	}

	action set_egress_port(egressSpec_t port) {
		standard_metadata.egress_spec = port;
	}

	/* Simple l2 forwarding logic for testing purposes */
	table l2_forward {
		key = {
			hdr.ethernet.dstAddr: exact;
		}

		actions = {
			set_egress_port;
			drop;
		}

		size = 1024;
		default_action = drop();
	}

	 /* update the packet header by swapping the source and destination addresses
	  * and ports in L2-L4 header fields in order to make the packet ready to
	  * return to the client */
	action ret_pkt_to_client() {
		macAddr_t macTmp;
		macTmp = hdr.ethernet.srcAddr;
		hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
		hdr.ethernet.dstAddr = macTmp;

		ip4Addr_t ipTmp;
		ipTmp = hdr.ipv4.srcAddr;
		hdr.ipv4.srcAddr = hdr.ipv4.dstAddr;
		hdr.ipv4.dstAddr = ipTmp;

		bit<16> udpPortTmp;
		udpPortTmp = hdr.udp.srcPort;
		hdr.udp.srcPort = hdr.udp.dstPort;
		hdr.udp.dstPort = udpPortTmp;
	}


	/* store bitmap and index of value table as metadata to have them available at
	 * egress pipeline where the value tables reside */
	action set_lookup_metadata(vtableBitmap_t bitmap, vtableIdx_t idx) {
		meta.vt_bitmap = bitmap;
		meta.vt_idx = idx;
	}

	/* define cache lookup table */
	table lookup_table {
		key = {
			hdr.netcache.key : exact;
		}

		actions = {
			set_lookup_metadata;
			NoAction;
		}

		size = NETCACHE_ENTRIES;
		default_action = NoAction;
	}


	apply {

		if (hdr.netcache.isValid()) {

            switch(lookup_table.apply().action_run) {

				set_lookup_metadata: {

                    if(hdr.netcache.op == READ_QUERY){

						bit<1> cache_valid_bit;
						cache_status.read(cache_valid_bit, (bit<32>) meta.vt_idx);

						// read query should be answered by switch if the key
						// resides in cache and its entry is valid
						meta.cache_valid = (cache_valid_bit == 1);

						if(meta.cache_valid) {
							ret_pkt_to_client();
						}

                    }

                    // write query is forwarded to key-value server and if the
					// key resides in cache then its entry is invalidated
                    else if(hdr.netcache.op == WRITE_QUERY) {
                        cache_status.write((bit<32>) meta.vt_idx, (bit<1>) 0);
                    }
                    // the server will block subsequent writes and update the entry
                    // in the cache. to notify the server that the entry is cached
                    // we set a special header

                    // delete query is forwarded to key-value server and if the
					// key resides in cache then its entry is invalidated
                    // the paper does not specify what we should do additionally
                    // probably the kv-store should delete the entry and notify the
                    // controller as well -> perhaps use the mirroring CPU port approach as well
                    else if (hdr.netcache.op == DELETE_QUERY) {

                        cache_status.write((bit<32>) meta.vt_idx, (bit<1>) 0);

                    }

                }

            }

        }

		l2_forward.apply();
	}

}
