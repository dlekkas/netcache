#include <core.p4>
#include <v1model.p4>


#define BLOOM_FILTER_ENTRIES 4096
#define BLOOM_IDX_WIDTH 12


register<bit<1>>(BLOOM_FILTER_ENTRIES) bloom_arr1;
register<bit<1>>(BLOOM_FILTER_ENTRIES) bloom_arr2;
register<bit<1>>(BLOOM_FILTER_ENTRIES) bloom_arr3;


action inspect_bloom_filter() {

	bit<BLOOM_IDX_WIDTH> bloom_idx1;
	hash(bloom_idx1, HashAlgorithm.crc32, (bit<1>) 0,
			{ hdr.netcache.key }, (bit<16>) BLOOM_FILTER_ENTRIES);

	bit<BLOOM_IDX_WIDTH> bloom_idx2;
	hash(bloom_idx2, HashAlgorithm.crc32, (bit<1>) 0,
			{ hdr.netcache.key }, (bit<16>) BLOOM_FILTER_ENTRIES);

	bit<BLOOM_IDX_WIDTH> bloom_idx3;
	hash(bloom_idx3, HashAlgorithm.crc16, (bit<1>) 0,
			{ hdr.netcache.key }, (bit<16>) BLOOM_FILTER_ENTRIES);


	bit<1> val_1;
	bloom_arr1.read(val_1, (bit<32>) bloom_idx1);
	bit<1> val_2;
	bloom_arr2.read(val_2, (bit<32>) bloom_idx2);
	bit<1> val_3;
	bloom_arr3.read(val_3, (bit<32>) bloom_idx3);

	// if the following condition holds true then the key already exists
	// with high probability in the bloom filter and we won't send it to
	// the controller since it is already reported
	if (!(val_1 == 1 && val_2 == 1 && val_3 == 1)) {
		meta.hot_query = 1;
	}


}


action update_bloom_filter() {

	// acquire indices of each bloom array
	bit<BLOOM_IDX_WIDTH> bloom_idx1;
	hash(bloom_idx1, HashAlgorithm.crc32, (bit<1>) 0,
			{ hdr.netcache.key }, (bit<16>) BLOOM_FILTER_ENTRIES);

	bit<BLOOM_IDX_WIDTH> bloom_idx2;
	hash(bloom_idx2, HashAlgorithm.crc32, (bit<1>) 0,
			{ hdr.netcache.key }, (bit<16>) BLOOM_FILTER_ENTRIES);

	bit<BLOOM_IDX_WIDTH> bloom_idx3;
	hash(bloom_idx3, HashAlgorithm.crc16, (bit<1>) 0,
			{ hdr.netcache.key }, (bit<16>) BLOOM_FILTER_ENTRIES);


	// update the bloom filter
	bloom_arr1.write((bit<32>) bloom_idx1, (bit<1>) 1);
	bloom_arr2.write((bit<32>) bloom_idx2, (bit<1>) 1);
	bloom_arr3.write((bit<32>) bloom_idx3, (bit<1>) 1);

}

