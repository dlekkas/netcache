#include <core.p4>
#include <v1model.p4>

#include "../include/headers.p4"


control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

	action drop() {
		mark_to_drop(standard_metadata);
	}


	action set_egress_port(egressSpec_t port) {
		standard_metadata.egress_spec = port;
	}

	/* Simple l2 forwarding logic for testing purposes */
	table l2_forward {
		key = {
			standard_metadata.ingress_port : exact;
		}
		actions = {
			set_egress_port;
			drop;
		}

		size = 4;
		default_action = drop();
	}

	/* store bitmap and index of value table as metadata to have them available at
	 * egress pipeline where the value tables reside. this action will be called
	 * only in case of a cache hit */
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
			lookup_table.apply();
			if (hdr.netcache.op == READ_QUERY) {
				// TODO: set routing information by matching on source address
				// since the switch will reply directly to client
			}
		}

		l2_forward.apply();
	}
}
