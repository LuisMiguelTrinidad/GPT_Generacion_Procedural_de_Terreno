const std = @import("std");

const C1: u64 = 0xbf58476d1ce4e5b9;
const C2: u64 = 0xc4ceb9fe1a85ec53;

pub inline fn custom_hash(s: u64, x: i64, y: i64) u64 {
  var hash = s ^ (@as(u64, @bitCast(x)) *% C1) ^ (@as(u64, @bitCast(y)) *% C2);

  var res: u128 = std.math.mulWide(u64, hash, std.math.rotr(u64, hash, 32));
  hash = @as(u64, @truncate(res)) ^ @as(u64, @truncate(res >> 64));

  res = std.math.mulWide(u64, hash, std.math.rotr(u64, hash, 32));
  hash = @as(u64, @truncate(res)) ^ @as(u64, @truncate(res >> 64));
  hash ^= (hash >> 16);

  return hash;
}

pub inline fn murmur_hash(s: u64, x: i64, y: i64) u64 {
  return std.hash.Murmur2_64.hashUint64WithSeed(
    (@as(u64, @bitCast(x)) *% C1) ^ (@as(u64, @bitCast(y)) *% C2),
    s,
  );
}


