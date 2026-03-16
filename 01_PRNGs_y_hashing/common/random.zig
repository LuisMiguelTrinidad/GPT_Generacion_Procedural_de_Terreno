const std = @import("std");

const C1: u64 = 0xa0761d6478bd642f; //Wyrand
const C2: u64 = 0xe7037ed1a0b428db; //Wyrand
const C3: u64 = 0x8ebc6af09c88c6e3; //Wyrand

var custom_hash_seed_v1: u64 = 0;
//custom hash v1 no tiene inicializacion
pub inline fn custom_hash_v1(seed_state: u64, x: i64, y: i64) u64 {
	var hash = seed_state ^ (@as(u64, @bitCast(x)) *% C1) ^ (@as(u64, @bitCast(y)) *% C2);

	var res: u128 = std.math.mulWide(u64, hash, std.math.rotr(u64, hash, 32));
	hash = @as(u64, @truncate(res)) ^ @as(u64, @truncate(res >> 64));

	res = std.math.mulWide(u64, hash, std.math.rotr(u64, hash, 32));
	hash = @as(u64, @truncate(res)) ^ @as(u64, @truncate(res >> 64));

	return hash ^ (hash >> 16);
}

//custom hash v2 está en pruebas aún
var custom_hash_seed_v2: u64 = 0;

pub inline fn custom_hash_init_v2(seed: u64) u64 {
	var hash = seed;
	for (0..7) |_| {
		var res: u128 = std.math.mulWide(u64, hash, C1);
		hash = @as(u64, @truncate(res)) ^ @as(u64, @truncate(res >> 64));
		hash ^= hash << 13;
		hash ^= hash >> 7;
		hash ^= hash << 17;
		hash += C1;

		res = std.math.mulWide(u64, hash, C2);
		hash = @as(u64, @truncate(res)) ^ @as(u64, @truncate(res >> 64));
		hash ^= hash << 13;
		hash ^= hash >> 7;
		hash ^= hash << 17;
		hash += C2;

		res = std.math.mulWide(u64, hash, std.math.rotr(u64, hash, 32));
		hash = @as(u64, @truncate(res)) ^ @as(u64, @truncate(res >> 64));
		hash ^= hash << 13;
		hash ^= hash >> 7;
		hash ^= hash << 17;
		custom_hash_seed_v2 ^= custom_hash_seed_v2 >> @as(u6, @truncate(custom_hash_seed_v2 & 0b111111));
	}
	custom_hash_seed_v2 = hash;
	return custom_hash_seed_v2;
}

pub inline fn custom_hash_v2_no_init(seed: u64, x: i64, y: i64) u64 {
	const ux = @as(u64, @bitCast(x));
	const uy = @as(u64, @bitCast(y));

	const mix_x = ux *% C3;
	const mix_y = uy *% C2;
	var hash = seed ^ mix_x;
	
	// Un único multiplicador masivo al final mezcla todo por igual
	hash = rapidmix(hash, mix_y);
	return hash ^ @byteSwap(hash) ^ std.math.rotr(u64, hash, 17);
}

pub inline fn custom_hash_v2_full(seed: u64, x: i64, y: i64) u64 {
	return custom_hash_v2_no_init(custom_hash_init_v2(seed), x, y);
}

//rapidhashnano hardcodeado a nuestro payload exacto.
var rapid_seed: u64 = 0;

// Constantes oficiales de rapidhash
const rapid_secret_1: u64 = 0x8bb84b93962eacc9;
const rapid_secret_2: u64 = 0x4b33a62ed433d4a3;
const rapid_secret_7: u64 = 0xaaaaaaaaaaaaaaaa;

inline fn rapidmix(a: u64, b: u64) u64 {
	const r: u128 = std.math.mulWide(u64, a, b);
	return @as(u64, @truncate(r)) ^ @as(u64, @truncate(r >> 64));
}

inline fn rapidmum(a: *u64, b: *u64) void {
	const r: u128 = std.math.mulWide(u64, a.*, b.*);
	a.* = @truncate(r);
	b.* = @truncate(r >> 64);
}

pub inline fn rapidhashnano_init_seed(seed: u64) u64 {
	rapid_seed = rapidmix(seed ^ rapid_secret_2, rapid_secret_1);
	return rapid_seed;
}

pub inline fn rapidhashnano_full(seed: u64, x: i64, y: i64) u64 {
	return rapidhashnano_no_init(rapidhashnano_init_seed(seed), x, y);
}

pub inline fn rapidhashnano_no_init(seed: u64, x: i64, y: i64) u64 {
	var hash: u64 = seed;

	hash ^= 16;

	var a: u64 = @bitCast(x);
	var b: u64 = @bitCast(y);

	a^= rapid_secret_1;
	b^= hash;
	rapidmum(&a, &b);

	return rapidmix(a ^ rapid_secret_7, b ^ rapid_secret_1 ^ 16);
}

pub fn xorshift64(state_in: u64) u64 {
	var state = state_in;
	state ^= state << 13;
	state ^= state >> 7;
	state ^= state << 17;
	return state;
}
