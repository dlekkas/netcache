#include <core.p4>
#include <v1model.p4>


// BLOOM FILTER REGISTERS
register<bit<1>>(BLOOM_FILTER_ENTRIES) bloom1;
register<bit<1>>(BLOOM_FILTER_ENTRIES) bloom2;
register<bit<1>>(BLOOM_FILTER_ENTRIES) bloom3;


#define SKETCH_BUCKET_LENGTH 65535
#define SKETCH_CELL_BIT_WIDTH 16
#define SKETCH_IDX_WIDTH 16

// COUNT MIN SKETCH REGISTERS
register<bit<SKETCH_CELL_BIT_WIDTH>>(SKETCH_BUCKET_LENGTH) sketch1;
register<bit<SKETCH_CELL_BIT_WIDTH>>(SKETCH_BUCKET_LENGTH) sketch2;
register<bit<SKETCH_CELL_BIT_WIDTH>>(SKETCH_BUCKET_LENGTH) sketch3;
register<bit<SKETCH_CELL_BIT_WIDTH>>(SKETCH_BUCKET_LENGTH) sketch4;


action inspect_bloom_filter() {

	hash(meta.bloom_idx1, HashAlgorithm.crc32_custom, (bit<1>) 0,
			{ hdr.netcache.key }, (bit<16>) BLOOM_FILTER_ENTRIES);

	hash(meta.bloom_idx2, HashAlgorithm.crc32_custom, (bit<1>) 0,
			{ hdr.netcache.key }, (bit<16>) BLOOM_FILTER_ENTRIES);

	hash(meta.bloom_idx3, HashAlgorithm.crc32_custom, (bit<1>) 0,
			{ hdr.netcache.key }, (bit<16>) BLOOM_FILTER_ENTRIES);


	bit<1> val_1;
	bloom1.read(val_1, (bit<32>) meta.bloom_idx1);
	bit<1> val_2;
	bloom2.read(val_2, (bit<32>) meta.bloom_idx2);
	bit<1> val_3;
	bloom3.read(val_3, (bit<32>) meta.bloom_idx3);

	// if the following condition holds true then the key already exists
	// with high probability in the bloom filter and we won't send it to
	// the controller since it is already reported
	if (!(val_1 == 1 && val_2 == 1 && val_3 == 1)) {
		meta.hot_query = 1;
	}


}


action update_bloom_filter() {

	bloom1.write((bit<32>) meta.bloom_idx1, (bit<1>) 1);
	bloom2.write((bit<32>) meta.bloom_idx2, (bit<1>) 1);
	bloom3.write((bit<32>) meta.bloom_idx3, (bit<1>) 1);

}


action update_count_min_sketch() {

	bit<SKETCH_IDX_WIDTH> sketch_idx1;
	bit<SKETCH_CELL_BIT_WIDTH> sketch_val1;
	hash(sketch_idx1, HashAlgorithm.crc32_custom, (bit<1>) 0,
			{hdr.netcache.key}, (bit<16>) SKETCH_BUCKET_LENGTH);
	sketch1.read(sketch_val1, (bit<32>) sketch_idx1);
	sketch1.write((bit<32>) sketch_idx1, sketch_val1+1);


	bit<SKETCH_IDX_WIDTH> sketch_idx2;
	bit<SKETCH_CELL_BIT_WIDTH> sketch_val2;
	hash(sketch_idx2, HashAlgorithm.crc32_custom, (bit<1>) 0,
			{hdr.netcache.key}, (bit<16>) SKETCH_BUCKET_LENGTH);
	sketch2.read(sketch_val2, (bit<32>) sketch_idx2);
	sketch2.write((bit<32>) sketch_idx2, sketch_val2+1);


	bit<SKETCH_IDX_WIDTH> sketch_idx3;
	bit<SKETCH_CELL_BIT_WIDTH> sketch_val3;
	hash(sketch_idx3, HashAlgorithm.crc32_custom, (bit<1>) 0,
			{hdr.netcache.key}, (bit<16>) SKETCH_BUCKET_LENGTH);
	sketch3.read(sketch_val3, (bit<32>) sketch_idx3);
	sketch3.write((bit<32>) sketch_idx3, sketch_val3+1);

	bit<SKETCH_IDX_WIDTH> sketch_idx4;
	bit<SKETCH_CELL_BIT_WIDTH> sketch_val4;
	hash(sketch_idx4, HashAlgorithm.crc32_custom, (bit<1>) 0,
			{hdr.netcache.key}, (bit<16>) SKETCH_BUCKET_LENGTH);
	sketch4.read(sketch_val4, (bit<32>) sketch_idx4);
	sketch4.write((bit<32>) sketch_idx4, sketch_val4+1);


	// take the minimum out of all the sketch values

	if (sketch_val1 <= sketch_val2 && sketch_val1 <= sketch_val3 &&
			sketch_val1 <= sketch_val4) {
		meta.key_cnt = sketch_val1;
	}

	if (sketch_val2 <= sketch_val1 && sketch_val2 <= sketch_val3 &&
			sketch_val2 <= sketch_val4) {
		meta.key_cnt = sketch_val2;
	}

	if (sketch_val3 <= sketch_val1 && sketch_val3 <= sketch_val2 &&
			sketch_val3 <= sketch_val4) {
		meta.key_cnt = sketch_val3;
	}

	if (sketch_val4 <= sketch_val1 && sketch_val4 <= sketch_val2 &&
			sketch_val4 <= sketch_val3) {
		meta.key_cnt = sketch_val4;
	}

}
