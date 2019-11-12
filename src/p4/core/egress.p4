#include <core.p4>
#include <v1model.p4>

#include "../include/headers.p4"

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

	// TODO: declare value tables here, we need 8 value tables and we will
	// use them to construct the final value that we return to the client.
	// To construct the final value, we append the value from each tables

    apply {  }
}

