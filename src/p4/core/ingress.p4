#include <core.p4>
#include <v1model.p4>

#include "../include/headers.p4"

#define CONTROLLER_MIRROR_SESSION 100

#define pkt_instance_type_normal 0
#define pkt_instance_type_ingress_clone 1
#define pkt_instance_type_egress_clone 2
#define pkt_instance_type_coalesced 3
#define pkt_instance_type_ingress_recirc 4
#define pkt_instance_type_replication 5
#define pkt_instance_type_resubmit 6

#define pkt_is_mirrored \
	((standard_metadata.instance_type != pkt_instance_type_normal) && \
	 (standard_metadata.instance_type != pkt_instance_type_replication))

#define pkt_is_not_mirrored \
	 ((standard_metadata.instance_type == pkt_instance_type_normal) || \
	  (standard_metadata.instance_type == pkt_instance_type_replication))


control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {


	action drop() {
		mark_to_drop(standard_metadata);
	}

	action set_egress_port(egressSpec_t port) {
		standard_metadata.egress_spec = port;
	}


	/* Simple l2 forwarding logic */
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
	  * return to the sender (tcp is more subtle than just swapping addresses) */
	action ret_pkt_to_sender() {

		macAddr_t macTmp;
		macTmp = hdr.ethernet.srcAddr;
		hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
		hdr.ethernet.dstAddr = macTmp;

		ip4Addr_t ipTmp;
		ipTmp = hdr.ipv4.srcAddr;
		hdr.ipv4.srcAddr = hdr.ipv4.dstAddr;
		hdr.ipv4.dstAddr = ipTmp;

		bit<16> portTmp;
		if (hdr.udp.isValid()) {
			portTmp = hdr.udp.srcPort;
			hdr.udp.srcPort = hdr.udp.dstPort;
			hdr.udp.dstPort = portTmp;
		} else if (hdr.tcp.isValid()) {
			portTmp = hdr.tcp.srcPort;
			hdr.tcp.srcPort = hdr.tcp.dstPort;
			hdr.tcp.dstPort = portTmp;
		}

	}


	/* store metadata for a given key to find its values and index it properly */
	action set_lookup_metadata(vtableBitmap_t vt_bitmap, vtableIdx_t vt_idx, keyIdx_t key_idx) {

		meta.vt_bitmap = vt_bitmap;
		meta.vt_idx = vt_idx;
		meta.key_idx = key_idx;

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

		size = NETCACHE_ENTRIES * NETCACHE_VTABLE_NUM;
		default_action = NoAction;

	}


    // register storing a bit to indicate whether an element in the cache
    // is valid or invalid
    register<bit<1>>(NETCACHE_ENTRIES * NETCACHE_VTABLE_NUM) cache_status;

	// maintain 8 value tables since we need to spread them across stages
	// where part of the value is created from each stage (4.4.2 section)
	register<bit<NETCACHE_VTABLE_SLOT_WIDTH>>(NETCACHE_ENTRIES) vt0;
	register<bit<NETCACHE_VTABLE_SLOT_WIDTH>>(NETCACHE_ENTRIES) vt1;
	register<bit<NETCACHE_VTABLE_SLOT_WIDTH>>(NETCACHE_ENTRIES) vt2;
	register<bit<NETCACHE_VTABLE_SLOT_WIDTH>>(NETCACHE_ENTRIES) vt3;
	register<bit<NETCACHE_VTABLE_SLOT_WIDTH>>(NETCACHE_ENTRIES) vt4;
	register<bit<NETCACHE_VTABLE_SLOT_WIDTH>>(NETCACHE_ENTRIES) vt5;
	register<bit<NETCACHE_VTABLE_SLOT_WIDTH>>(NETCACHE_ENTRIES) vt6;
	register<bit<NETCACHE_VTABLE_SLOT_WIDTH>>(NETCACHE_ENTRIES) vt7;

	// count how many stages actually got triggered (1s on bitmap)
	// this variable is needed for the shifting logic
	bit<8> valid_stages_num = 0;

	// build the value incrementally by concatenating the value
	// attained by each register array (stage) based on whether the
	// corresponding bit of the bitmap stored in metadata is set

	// the way of implementing the 'append' of each value from each stage is based
	// on a few constraints of the simple_switch architecture. The constraints are:
	// 1) Concatenation of bit strings is only allowed for strings of same bit width
	// 2) Bitwise operations are only allowed for types of same bit width
	// 3) Multiplication is not supported (only shifting by power of 2)

	// Our approach to appending is to do OR operations between the value of the key
	// (in the header) with every value of any valid stage (bitmap bit set to 1). As
	// we progress through the stages, we need to shift the value we read from array
	// at stage i by 7 * (1s in bitmap till position i) in order to put the value in
	// the correct position of the final value. To calculate the shifting we need
	// (i.e 7 * (1s in bitmap so far)), we convert it to
	// 8 * (1s in bitmap so far) - (1s in bitmap so far) to avoid multiplication
	// and be able to do it while only using shifting operators

	action process_array_0() {
		// store value of the array at this stage
		bit<NETCACHE_VTABLE_SLOT_WIDTH> curr_stage_val;
		vt0.read(curr_stage_val, (bit<32>) meta.vt_idx);

		hdr.netcache.value = (bit<NETCACHE_VALUE_WIDTH_MAX>) curr_stage_val;
		valid_stages_num = valid_stages_num + 1;
	}


	action process_array_1() {
		bit<NETCACHE_VTABLE_SLOT_WIDTH> curr_stage_val;
		vt1.read(curr_stage_val, (bit<32>) meta.vt_idx);

		bit<8> shift_pos = 0;
		if (valid_stages_num != 0) {
			shift_pos = 64 << (valid_stages_num - 1);
		}

		hdr.netcache.value = (bit<NETCACHE_VALUE_WIDTH_MAX>) hdr.netcache.value << 64;
		hdr.netcache.value = hdr.netcache.value | (bit<NETCACHE_VALUE_WIDTH_MAX>) curr_stage_val;

		valid_stages_num = valid_stages_num + 1;
	}

	action process_array_2() {
		bit<NETCACHE_VTABLE_SLOT_WIDTH> curr_stage_val;
		vt2.read(curr_stage_val, (bit<32>) meta.vt_idx);

		bit<8> shift_pos = 0;
		if (valid_stages_num != 0) {
			shift_pos = 64 << (valid_stages_num - 1);
		}

		hdr.netcache.value = (bit<NETCACHE_VALUE_WIDTH_MAX>) hdr.netcache.value << 64;
		hdr.netcache.value = hdr.netcache.value | (bit<NETCACHE_VALUE_WIDTH_MAX>) curr_stage_val;

		valid_stages_num = valid_stages_num + 1;
	}

	action process_array_3() {
		bit<NETCACHE_VTABLE_SLOT_WIDTH> curr_stage_val;
		vt3.read(curr_stage_val, (bit<32>) meta.vt_idx);

		bit<8> shift_pos = 0;
		if (valid_stages_num != 0) {
			shift_pos = 64 << (valid_stages_num - 1);
		}

		hdr.netcache.value = (bit<NETCACHE_VALUE_WIDTH_MAX>) hdr.netcache.value << 64;
		hdr.netcache.value = hdr.netcache.value | (bit<NETCACHE_VALUE_WIDTH_MAX>) curr_stage_val;

		valid_stages_num = valid_stages_num + 1;
	}

	action process_array_4() {
		bit<NETCACHE_VTABLE_SLOT_WIDTH> curr_stage_val;
		vt4.read(curr_stage_val, (bit<32>) meta.vt_idx);

		bit<8> shift_pos = 0;
		if (valid_stages_num != 0) {
			shift_pos = 64 << (valid_stages_num - 1);
		}

		hdr.netcache.value = (bit<NETCACHE_VALUE_WIDTH_MAX>) hdr.netcache.value << 64;
		hdr.netcache.value = hdr.netcache.value | (bit<NETCACHE_VALUE_WIDTH_MAX>) curr_stage_val;

		valid_stages_num = valid_stages_num + 1;
	}

	action process_array_5() {
		bit<NETCACHE_VTABLE_SLOT_WIDTH> curr_stage_val;
		vt5.read(curr_stage_val, (bit<32>) meta.vt_idx);

		bit<8> shift_pos = 0;
		if (valid_stages_num != 0) {
			shift_pos = 64 << (valid_stages_num - 1);
		}

		hdr.netcache.value = (bit<NETCACHE_VALUE_WIDTH_MAX>) hdr.netcache.value << 64;
		hdr.netcache.value = hdr.netcache.value | (bit<NETCACHE_VALUE_WIDTH_MAX>) curr_stage_val;

		valid_stages_num = valid_stages_num + 1;
	}

	action process_array_6() {
		bit<NETCACHE_VTABLE_SLOT_WIDTH> curr_stage_val;
		vt6.read(curr_stage_val, (bit<32>) meta.vt_idx);

		bit<8> shift_pos = 0;
		if (valid_stages_num != 0) {
			shift_pos = 64 << (valid_stages_num - 1);
		}

		hdr.netcache.value = (bit<NETCACHE_VALUE_WIDTH_MAX>) hdr.netcache.value << 64;
		hdr.netcache.value = hdr.netcache.value | (bit<NETCACHE_VALUE_WIDTH_MAX>) curr_stage_val;

		valid_stages_num = valid_stages_num + 1;
	}

	action process_array_7() {
		bit<NETCACHE_VTABLE_SLOT_WIDTH> curr_stage_val;
		vt7.read(curr_stage_val, (bit<32>) meta.vt_idx);

		bit<8> shift_pos = 0;
		if (valid_stages_num != 0) {
			shift_pos = 64 << (valid_stages_num - 1);
		}

		hdr.netcache.value = (bit<NETCACHE_VALUE_WIDTH_MAX>) hdr.netcache.value << 64;
		hdr.netcache.value = hdr.netcache.value | (bit<NETCACHE_VALUE_WIDTH_MAX>) curr_stage_val;

		valid_stages_num = valid_stages_num + 1;
	}


	table vtable_0 {
		key = {
			meta.vt_bitmap[7:7]: exact;
		}
		actions = {
			process_array_0;
			NoAction;
		}
		size = NETCACHE_ENTRIES;
		default_action = NoAction;
	}

	table vtable_1 {
		key = {
			meta.vt_bitmap[6:6]: exact;
		}
		actions = {
			process_array_1;
			NoAction;
		}
		size = NETCACHE_ENTRIES;
		default_action = NoAction;
	}

	table vtable_2 {
		key = {
			meta.vt_bitmap[5:5]: exact;
		}
		actions = {
			process_array_2;
			NoAction;
		}
		size = NETCACHE_ENTRIES;
		default_action = NoAction;
	}

	table vtable_3 {
		key = {
			meta.vt_bitmap[4:4]: exact;
		}
		actions = {
			process_array_3;
			NoAction;
		}
		size = NETCACHE_ENTRIES;
		default_action = NoAction;
	}

	table vtable_4 {
		key = {
			meta.vt_bitmap[3:3]: exact;
		}
		actions = {
			process_array_4;
			NoAction;
		}
		size = NETCACHE_ENTRIES;
		default_action = NoAction;
	}

	table vtable_5 {
		key = {
			meta.vt_bitmap[2:2]: exact;
		}
		actions = {
			process_array_5;
			NoAction;
		}
		size = NETCACHE_ENTRIES;
		default_action = NoAction;
	}

	table vtable_6 {
		key = {
			meta.vt_bitmap[1:1]: exact;
		}
		actions = {
			process_array_6;
			NoAction;
		}
		size = NETCACHE_ENTRIES;
		default_action = NoAction;
	}

	table vtable_7 {
		key = {
			meta.vt_bitmap[0:0]: exact;
		}
		actions = {
			process_array_7;
			NoAction;
		}
		size = NETCACHE_ENTRIES;
		default_action = NoAction;
	}



	apply {

		if (hdr.netcache.isValid()) {


            switch(lookup_table.apply().action_run) {

				set_lookup_metadata: {

                    if (hdr.netcache.op == READ_QUERY){

						bit<1> cache_valid_bit;
						cache_status.read(cache_valid_bit, (bit<32>) meta.key_idx);

						// read query should be answered by switch if the key
						// resides in cache and its entry is valid
						meta.cache_valid = (cache_valid_bit == 1);

						/*
						if(meta.cache_valid && hdr.udp.srcPort != NETCACHE_PORT) {
							ret_pkt_to_sender();
						}
						*/


						if (meta.cache_valid && hdr.udp.srcPort != NETCACHE_PORT) {
							vtable_0.apply(); vtable_1.apply(); vtable_2.apply(); vtable_3.apply();
							vtable_4.apply(); vtable_5.apply(); vtable_6.apply(); vtable_7.apply();

							ret_pkt_to_sender();
						}

                    }


					// if the key of the write query exists in the cache then we should inform
					// the controller to initiate the 3-way cache coherency handshake
                    else if (hdr.netcache.op == WRITE_QUERY) {

                        cache_status.write((bit<32>) meta.key_idx, (bit<1>) 0);

						hdr.netcache.op = CACHED_UPDATE;
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

                        cache_status.write((bit<32>) meta.key_idx, (bit<1>) 0);

					}

					else if (hdr.netcache.op == UPDATE_COMPLETE) {

						// if it's an update query then ensure that the switch will
						// forward the packet back to the server to complete the
						// cache coherency handshake
						ret_pkt_to_sender();

						bit<8> stages_cnt = 0;
						bit<8> shift_pos = 0;


						if (meta.vt_bitmap[0:0] == 1) {
							bit<NETCACHE_VTABLE_SLOT_WIDTH> new_val;
							new_val = (bit<NETCACHE_VTABLE_SLOT_WIDTH>) (hdr.netcache.value >> shift_pos);

							vt7.write((bit<32>) meta.vt_idx, new_val);

							shift_pos = shift_pos + NETCACHE_VTABLE_SLOT_WIDTH;
						}

						if (meta.vt_bitmap[1:1] == 1) {
							bit<NETCACHE_VTABLE_SLOT_WIDTH> new_val;
							new_val = (bit<NETCACHE_VTABLE_SLOT_WIDTH>) (hdr.netcache.value >> shift_pos);

							vt6.write((bit<32>) meta.vt_idx, new_val);

							shift_pos = shift_pos + NETCACHE_VTABLE_SLOT_WIDTH;
						}

						if (meta.vt_bitmap[2:2] == 1) {
							bit<NETCACHE_VTABLE_SLOT_WIDTH> new_val;
							new_val = (bit<NETCACHE_VTABLE_SLOT_WIDTH>) (hdr.netcache.value >> shift_pos);

							vt5.write((bit<32>) meta.vt_idx, new_val);

							shift_pos = shift_pos + NETCACHE_VTABLE_SLOT_WIDTH;
						}

						if (meta.vt_bitmap[3:3] == 1) {
							bit<NETCACHE_VTABLE_SLOT_WIDTH> new_val;
							new_val = (bit<NETCACHE_VTABLE_SLOT_WIDTH>) (hdr.netcache.value >> shift_pos);

							vt4.write((bit<32>) meta.vt_idx, new_val);

							shift_pos = shift_pos + NETCACHE_VTABLE_SLOT_WIDTH;
						}

						if (meta.vt_bitmap[4:4] == 1) {
							bit<NETCACHE_VTABLE_SLOT_WIDTH> new_val;
							new_val = (bit<NETCACHE_VTABLE_SLOT_WIDTH>) (hdr.netcache.value >> shift_pos);

							vt3.write((bit<32>) meta.vt_idx, new_val);

							shift_pos = shift_pos + NETCACHE_VTABLE_SLOT_WIDTH;
						}

						if (meta.vt_bitmap[5:5] == 1) {
							bit<NETCACHE_VTABLE_SLOT_WIDTH> new_val;
							new_val = (bit<NETCACHE_VTABLE_SLOT_WIDTH>) (hdr.netcache.value >> shift_pos);

							vt2.write((bit<32>) meta.vt_idx, new_val);

							shift_pos = shift_pos + NETCACHE_VTABLE_SLOT_WIDTH;
						}

						if (meta.vt_bitmap[6:6] == 1) {
							bit<NETCACHE_VTABLE_SLOT_WIDTH> new_val;
							new_val = (bit<NETCACHE_VTABLE_SLOT_WIDTH>) (hdr.netcache.value >> shift_pos);

							vt1.write((bit<32>) meta.vt_idx, new_val);

							shift_pos = shift_pos + NETCACHE_VTABLE_SLOT_WIDTH;
						}

						if (meta.vt_bitmap[7:7] == 1) {
							bit<NETCACHE_VTABLE_SLOT_WIDTH> new_val;
							new_val = (bit<NETCACHE_VTABLE_SLOT_WIDTH>) (hdr.netcache.value >> shift_pos);

							vt0.write((bit<32>) meta.vt_idx, new_val);
						}


						cache_status.write((bit<32>) meta.key_idx, (bit<1>) 1);

						hdr.netcache.op = UPDATE_COMPLETE_OK;

					}

				}

				NoAction: {

					if (hdr.netcache.op == HOT_READ_QUERY) {

						// inform the controller for the hot key to insert to cache
						if (pkt_is_not_mirrored) {
							clone(CloneType.I2E, CONTROLLER_MIRROR_SESSION);
						}

					}
				}


            }

        }

		l2_forward.apply();
	}

}
