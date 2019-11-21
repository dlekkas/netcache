#include <core.p4>
#include <v1model.p4>

#include "../include/headers.p4"

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

	// TODO: declare value tables here, we need 8 value tables and we will
	// use them to construct the final value that we return to the client.
	// To construct the final value, we append the value from each tables

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

		hdr.netcache.value = hdr.netcache.value | ((bit<NETCACHE_VALUE_WIDTH_MAX>) curr_stage_val);
		valid_stages_num = valid_stages_num + 1;
	}


	action process_array_1() {
		bit<NETCACHE_VTABLE_SLOT_WIDTH> curr_stage_val;
		vt1.read(curr_stage_val, (bit<32>) meta.vt_idx);

		bit<8> shift_pos = 0;
		if (valid_stages_num != 0) {
			shift_pos = (valid_stages_num >> 3) - valid_stages_num;
		}

		bit<NETCACHE_VALUE_WIDTH_MAX> tmp =
			(((bit<NETCACHE_VALUE_WIDTH_MAX>) curr_stage_val) << shift_pos);
		hdr.netcache.value = hdr.netcache.value | tmp;
		valid_stages_num = valid_stages_num + 1;
	}

	action process_array_2() {
		bit<NETCACHE_VTABLE_SLOT_WIDTH> curr_stage_val;
		vt2.read(curr_stage_val, (bit<32>) meta.vt_idx);

		bit<8> shift_pos = 0;
		if (valid_stages_num != 0) {
			shift_pos = (valid_stages_num >> 3) - valid_stages_num;
		}

		bit<NETCACHE_VALUE_WIDTH_MAX> tmp =
			(((bit<NETCACHE_VALUE_WIDTH_MAX>) curr_stage_val) << shift_pos);
		hdr.netcache.value = hdr.netcache.value | tmp;
		valid_stages_num = valid_stages_num + 1;
	}

	action process_array_3() {
		bit<NETCACHE_VTABLE_SLOT_WIDTH> curr_stage_val;
		vt3.read(curr_stage_val, (bit<32>) meta.vt_idx);

		bit<8> shift_pos = 0;
		if (valid_stages_num != 0) {
			shift_pos = (valid_stages_num >> 3) - valid_stages_num;
		}

		bit<NETCACHE_VALUE_WIDTH_MAX> tmp =
			(((bit<NETCACHE_VALUE_WIDTH_MAX>) curr_stage_val) << shift_pos);
		hdr.netcache.value = hdr.netcache.value | tmp;
		valid_stages_num = valid_stages_num + 1;
	}

	action process_array_4() {
		bit<NETCACHE_VTABLE_SLOT_WIDTH> curr_stage_val;
		vt4.read(curr_stage_val, (bit<32>) meta.vt_idx);

		bit<8> shift_pos = 0;
		if (valid_stages_num != 0) {
			shift_pos = (valid_stages_num >> 3) - valid_stages_num;
		}

		bit<NETCACHE_VALUE_WIDTH_MAX> tmp =
			(((bit<NETCACHE_VALUE_WIDTH_MAX>) curr_stage_val) << shift_pos);
		hdr.netcache.value = hdr.netcache.value | tmp;
		valid_stages_num = valid_stages_num + 1;
	}

	action process_array_5() {
		bit<NETCACHE_VTABLE_SLOT_WIDTH> curr_stage_val;
		vt5.read(curr_stage_val, (bit<32>) meta.vt_idx);

		bit<8> shift_pos = 0;
		if (valid_stages_num != 0) {
			shift_pos = (valid_stages_num >> 3) - valid_stages_num;
		}

		bit<NETCACHE_VALUE_WIDTH_MAX> tmp =
			(((bit<NETCACHE_VALUE_WIDTH_MAX>) curr_stage_val) << shift_pos);
		hdr.netcache.value = hdr.netcache.value | tmp;
		valid_stages_num = valid_stages_num + 1;
	}

	action process_array_6() {
		bit<NETCACHE_VTABLE_SLOT_WIDTH> curr_stage_val;
		vt6.read(curr_stage_val, (bit<32>) meta.vt_idx);

		bit<8> shift_pos = 0;
		if (valid_stages_num != 0) {
			shift_pos = (valid_stages_num >> 3) - valid_stages_num;
		}

		bit<NETCACHE_VALUE_WIDTH_MAX> tmp =
			(((bit<NETCACHE_VALUE_WIDTH_MAX>) curr_stage_val) << shift_pos);
		hdr.netcache.value = hdr.netcache.value | tmp;
		valid_stages_num = valid_stages_num + 1;
	}

	action process_array_7() {
		bit<NETCACHE_VTABLE_SLOT_WIDTH> curr_stage_val;
		vt7.read(curr_stage_val, (bit<32>) meta.vt_idx);

		bit<8> shift_pos = 0;
		if (valid_stages_num != 0) {
			shift_pos = (valid_stages_num >> 3) - valid_stages_num;
		}

		bit<NETCACHE_VALUE_WIDTH_MAX> tmp =
			(((bit<NETCACHE_VALUE_WIDTH_MAX>) curr_stage_val) << shift_pos);
		hdr.netcache.value = hdr.netcache.value | tmp;
		valid_stages_num = valid_stages_num + 1;
	}

	table vtable_0 {
		key = {
			meta.vt_bitmap[0:0]: exact;
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
			meta.vt_bitmap[1:1]: exact;
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
			meta.vt_bitmap[2:2]: exact;
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
			meta.vt_bitmap[3:3]: exact;
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
			meta.vt_bitmap[4:4]: exact;
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
			meta.vt_bitmap[5:5]: exact;
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
			meta.vt_bitmap[6:6]: exact;
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
			meta.vt_bitmap[7:7]: exact;
		}
		actions = {
			process_array_7;
			NoAction;
		}
		size = NETCACHE_ENTRIES;
		default_action = NoAction;
	}


    apply {
		if (hdr.netcache.op == READ_QUERY) {
			vtable_0.apply();
			vtable_1.apply();
			vtable_2.apply();
			vtable_3.apply();
			vtable_4.apply();
			vtable_5.apply();
			vtable_6.apply();
			vtable_7.apply();
		}
	}
}
