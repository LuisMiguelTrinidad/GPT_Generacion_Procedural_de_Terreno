const std = @import("std");

//###########################
//#        CUSTOM_V1        #
//###########################
pub inline fn custom_hash_init_v1(seed: u64) u64 {
	return splitmix64(seed);
}

pub inline fn custom_hash_v1_no_init(seed: u64, x: u64, y: u64) u64 {
	const pre: u64 = x +% 11811329173984144537;
	
	const pro: u128 = std.math.mulWide(u64, pre ^ seed, y +% pre);
	const hash: u64 = @as(u64, @truncate(pro)) ^ @as(u64, @truncate(pro >> 64));
	
	const swapped = @byteSwap(hash);
	return swapped ^ (hash +% std.math.rotr(u64, swapped, 13));
}

pub inline fn custom_hash_v1_full(seed: u64, x: u64, y: u64) u64 {
	return custom_hash_v1_no_init(custom_hash_init_v1(seed), x, y);
}

//###########################
//#        CUSTOM_V2        #
//###########################
pub inline fn custom_hash_init_v2(seed: u64) u64 {
	return splitmix64(seed);
}

pub inline fn custom_hash_v2_no_init(seed: u64, x: u64, y: u64) u64 {
	const mix_x: u64 = x ^ seed;
	const mix_y: u64 = (mix_x ^ y) *% 11811329173984144537;

	var pro: u128 = std.math.mulWide(u64, mix_y, mix_x);
	pro = std.math.mulWide(u64, @as(u64, @truncate(pro)), @truncate(pro >> 64));

	return @as(u64, @truncate(pro)) ^ @as(u64, @truncate(pro >> 64));
}

pub inline fn custom_hash_v2_full(seed: u64, x: u64, y: u64) u64 {
	return custom_hash_v2_no_init(custom_hash_init_v2(seed), x, y);
}

//###########################
//#        RAPIDHASH        #
//###########################

// Constantes oficiales de rapidhash
const secret_1: u64 = 0x8bb84b93962eacc9;
const secret_2: u64 = 0x4b33a62ed433d4a3;
const secret_7: u64 = 0xaaaaaaaaaaaaaaaa;

var rapid_seed: u64 = 0;
pub inline fn rapidhashnano_init_seed(seed: u64) u64 {
	const pro: u128 = std.math.mulWide(u64, seed ^ secret_2, secret_1);
	return seed ^ @as(u64, @truncate(pro)) ^ @as(u64, @truncate(pro >> 64));
}

pub inline fn rapidhashnano_full(seed: u64, x: u64, y: u64) u64 {
	return rapidhashnano_no_init(rapidhashnano_init_seed(seed), x, y);
}

pub inline fn rapidhashnano_no_init(seed: u64, x: u64, y: u64) u64 {
	var pro: u128 = std.math.mulWide(u64, x ^ secret_1, y ^ seed ^ 16);
	pro = std.math.mulWide(
		u64, 
		@as(u64, @truncate(pro)) ^ secret_7, 
		@as(u64, @truncate(pro >> 64)) ^ secret_1 ^ 16
	); 

	return @as(u64, @truncate(pro)) ^ @as(u64, @truncate(pro >> 64));
}

//###########################
//#        XORSHIFT         #
//###########################

pub fn xorshift64(state_in: u64) u64 {
	var state = state_in;
	state ^= state << 13;
	state ^= state >> 7;
	state ^= state << 17;

	return state;
}

//###########################
//#        SPLITMIX         #
//###########################
pub fn splitmix64(state_in: u64) u64 {
	var z = state_in +% 0x9e3779b97f4a7c15;
	z = (z ^ (z >> 30)) *% 0xbf58476d1ce4e5b9;
	z = (z ^ (z >> 27)) *% 0x94d049bb133111eb;

	return z ^ (z >> 31);
}