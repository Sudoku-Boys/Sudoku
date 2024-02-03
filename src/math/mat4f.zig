inline fn unpacklo(v0: @Vector(4, f32), v1: @Vector(4, f32)) @Vector(4, f32) {
	return @shuffle(f32, v0, v1, @Vector(4, i32){0, -1, 1, -2});
}

inline fn unpackhi(v0: @Vector(4, f32), v1: @Vector(4, f32)) @Vector(4, f32) {
	return @shuffle(f32, v0, v1, @Vector(4, i32){2, -3, 3, -4});
}

inline fn movelh(v0: @Vector(4, f32), v1: @Vector(4, f32)) @Vector(4, f32) {
	return @shuffle(f32, v0, v1, @Vector(4, i32){0, 1, -1, -2});
}

inline fn movehl(v0: @Vector(4, f32), v1: @Vector(4, f32)) @Vector(4, f32) {
	return @shuffle(f32, v0, v1, @Vector(4, i32){-3, -4, 2, 3});
}

inline fn permute(v0: @Vector(4, f32), comptime mask: @Vector(4, i32)) @Vector(4, f32) {
	return @shuffle(f32, v0, undefined, mask);
}

pub const Mat4f = extern union {
	
	_ : extern struct {
		m00 : f32, m01 : f32, m02 : f32, m03 : f32,
		m10 : f32, m11 : f32, m12 : f32, m13 : f32,
		m20 : f32, m21 : f32, m22 : f32, m23 : f32,
		m30 : f32, m31 : f32, m32 : f32, m33 : f32,
	},
	f : [16]f32,
	v : [4]@Vector(4, f32),
	
	pub inline fn addf(o: *Mat4f, a: *Mat4f, b: f32) void {

		const broad = @Vector(4, f32){b, b, b, b};
		o.*.v[0] = a.*.v[0] + broad;
		o.*.v[1] = a.*.v[1] + broad;
		o.*.v[2] = a.*.v[2] + broad;
		o.*.v[3] = a.*.v[3] + broad;
	}

	pub inline fn subf(o: *Mat4f, a: *Mat4f, b: f32) void {

		const broad = @Vector(4, f32){b, b, b, b};
		o.*.v[0] = a.*.v[0] - broad;
		o.*.v[1] = a.*.v[1] - broad;
		o.*.v[2] = a.*.v[2] - broad;
		o.*.v[3] = a.*.v[3] - broad;
	}

	pub inline fn mulf(o: *Mat4f, a: *Mat4f, b: f32) void {

		const broad = @Vector(4, f32){b, b, b, b};
		o.*.v[0] = a.*.v[0] * broad;
		o.*.v[1] = a.*.v[1] * broad;
		o.*.v[2] = a.*.v[2] * broad;
		o.*.v[3] = a.*.v[3] * broad;
	}

	pub inline fn divf(o: *Mat4f, a: *Mat4f, b: f32) void {

		const broad = @Vector(4, f32){b, b, b, b};
		o.*.v[0] = a.*.v[0] / broad;
		o.*.v[1] = a.*.v[1] / broad;
		o.*.v[2] = a.*.v[2] / broad;
		o.*.v[3] = a.*.v[3] / broad;
	}

	pub inline fn iden(o: *Mat4f) void {

		o.*.v[0] = .{1, 0, 0, 0};
		o.*.v[1] = .{0, 1, 0, 0};
		o.*.v[2] = .{0, 0, 1, 0};
		o.*.v[3] = .{0, 0, 0, 1};
	}

	pub inline fn trans(o: *Mat4f, a: *Mat4f) void {

		const r0 = a.*.v[0];
		const r1 = a.*.v[1];
		const r2 = a.*.v[2];
		const r3 = a.*.v[3];
		
		const tr01a = unpacklo(r0, r1);
		const tr23a = unpacklo(r2, r3);
		const tr01b = unpackhi(r0, r1);
		const tr23b = unpackhi(r2, r3);

		o.*.v[0] = movelh(tr01a, tr23a);
		o.*.v[1] = movehl(tr23a, tr01a);
		o.*.v[2] = movelh(tr01b, tr23b);
		o.*.v[3] = movehl(tr23b, tr01b);
	}

	pub inline fn inv(o: *Mat4f, a: *Mat4f) void {
		
		// load input matrix
		const r0 = a.*.v[0];
		const r1 = a.*.v[1];
		const r2 = a.*.v[2];
		const r3 = a.*.v[3];
		
		// perute into intermediary groups
		const im01 = permute(r0, .{1, 0, 0, 0}); 
		const im02 = permute(r0, .{2, 2, 1, 1}); 
		const im03 = permute(r0, .{3, 3, 3, 2});

		const im11 = permute(r1, .{1, 0, 0, 0}); 
		const im12 = permute(r1, .{2, 2, 1, 1}); 
		const im13 = permute(r1, .{3, 3, 3, 2});

		const im21 = permute(r2, .{1, 0, 0, 0}); 
		const im22 = permute(r2, .{2, 2, 1, 1}); 
		const im23 = permute(r2, .{3, 3, 3, 2});

		const im31 = permute(r3, .{1, 0, 0, 0}); 
		const im32 = permute(r3, .{2, 2, 1, 1}); 
		const im33 = permute(r3, .{3, 3, 3, 2});
		
		// compute secondary intermediary groups
		const j0 = (im22 * im33) - (im23 * im32);
		const j1 = (im23 * im31) - (im21 * im33);
		const j2 = (im21 * im32) - (im22 * im31);
		const j3 = (im02 * im13) - (im03 * im12);
		const j4 = (im03 * im11) - (im01 * im13);
		const j5 = (im01 * im12) - (im02 * im11);

		// compute matrix of minors
		const m0 = (im11 * j0) + (im12 * j1) + (im13 * j2);
		const m1 = (im01 * j0) + (im02 * j1) + (im03 * j2);
		const m2 = (im31 * j3) + (im32 * j4) + (im33 * j5);
		const m3 = (im21 * j3) + (im22 * j4) + (im23 * j5);

		// calculate determinant intermediary, determinant is [0] - [1] + [2] - [3] of r0 * m0
		const di = r0 * m0;

		// calculate alternating sign inverse determinant for rows 0 and 2
		const rvasid = (permute(di, .{0, 1, 0, 1}) - permute(di, .{1, 0, 1, 0})) + (permute(di, .{2, 3, 2, 3}) - permute(di, .{3, 2, 3, 2}));
		const asid0 = asm volatile(
			\\ vrcpps %[av0], %[av1]
			: [av1] "=x" (-> @Vector(4, f32))
			: [av0] "x" (rvasid)
			:
		);
		// compute alternating sign inverse determinant for rows 1 and 3
		const asid1 = permute(asid0, .{1, 0, 1, 0});

		// calculate matrix of cofactors
		const n0 = m0 * asid0;
		const n1 = m1 * asid1;
		const n2 = m2 * asid0;
		const n3 = m3 * asid1;

		// transpose and store matrix
		const tr01a = unpacklo(n0, n1);
		const tr23a = unpacklo(n2, n3);
		const tr01b = unpackhi(n0, n1);
		const tr23b = unpackhi(n2, n3);

		o.*.v[0] = movelh(tr01a, tr23a);
		o.*.v[1] = movehl(tr23a, tr01a);
		o.*.v[2] = movelh(tr01b, tr23b);
		o.*.v[3] = movehl(tr23b, tr01b);
	}

	pub inline fn add(o: *Mat4f, a: *Mat4f, b: *Mat4f) void {

		o.*.v[0] = a.*.v[0] + b.*.v[0];
		o.*.v[1] = a.*.v[1] + b.*.v[1];
		o.*.v[2] = a.*.v[2] + b.*.v[2];
		o.*.v[3] = a.*.v[3] + b.*.v[3];
	}

	pub inline fn sub(o: *Mat4f, a: *Mat4f, b: *Mat4f) void {

		o.*.v[0] = a.*.v[0] - b.*.v[0];
		o.*.v[1] = a.*.v[1] - b.*.v[1];
		o.*.v[2] = a.*.v[2] - b.*.v[2];
		o.*.v[3] = a.*.v[3] - b.*.v[3];
	}

	pub inline fn mul(o: *Mat4f, a: *Mat4f, b: *Mat4f) void {

		// load matrix a
		const r0 = a.*.v[0];
		const r1 = a.*.v[1];
		const r2 = a.*.v[2];
		const r3 = a.*.v[3];

		// load matrix b
		const b0 = b.*.v[0];
		const b1 = b.*.v[1];
		const b2 = b.*.v[2];
		const b3 = b.*.v[3];
		
		// transpose matrix a
		const tr01a = unpacklo(r0, r1);
		const tr23a = unpacklo(r2, r3);
		const tr01b = unpackhi(r0, r1);
		const tr23b = unpackhi(r2, r3);

		const t0 = movelh(tr01a, tr23a);
		const t1 = movehl(tr23a, tr01a);
		const t2 = movelh(tr01b, tr23b);
		const t3 = movehl(tr23b, tr01b);

		// first row
		{
			const a0 = (permute(t0, .{0, 0, 0, 0}) * b0) + (permute(t2, .{0, 0, 0, 0}) * b2);
			const a1 = (permute(t1, .{0, 0, 0, 0}) * b1) + (permute(t3, .{0, 0, 0, 0}) * b3);
			o.*.v[0] = a0 + a1;
		}
		// second row
		{
			const a0 = (permute(t0, .{1, 1, 1, 1}) * b0) + (permute(t2, .{1, 1, 1, 1}) * b2);
			const a1 = (permute(t1, .{1, 1, 1, 1}) * b1) + (permute(t3, .{1, 1, 1, 1}) * b3);
			o.*.v[1] = a0 + a1;
		}
		// third row
		{
			const a0 = (permute(t0, .{2, 2, 2, 2}) * b0) + (permute(t2, .{2, 2, 2, 2}) * b2);
			const a1 = (permute(t1, .{2, 2, 2, 2}) * b1) + (permute(t3, .{2, 2, 2, 2}) * b3);
			o.*.v[2] = a0 + a1;
		}
		// fourth row
		{
			const a0 = (permute(t0, .{3, 3, 3, 3}) * b0) + (permute(t2, .{3, 3, 3, 3}) * b2);
			const a1 = (permute(t1, .{3, 3, 3, 3}) * b1) + (permute(t3, .{3, 3, 3, 3}) * b3);
			o.*.v[3] = a0 + a1;
		}
	}

	pub inline fn div(o: *Mat4f, a: *Mat4f, b: *Mat4f) void {
		var m: @This() = undefined;
		inv(&m, b);
		mul(o, a, &m);
	}

	pub inline fn mulv(o: *@Vector(4, f32), a: *Mat4f, b: *@Vector(4, f32)) void {
		// load matrix a
		const r0 = a.*.v[0];
		const r1 = a.*.v[1];
		const r2 = a.*.v[2];
		const r3 = a.*.v[3];
		
		// transpose matrix a
		const tr01a = unpacklo(r0, r1);
		const tr23a = unpacklo(r2, r3);
		const tr01b = unpackhi(r0, r1);
		const tr23b = unpackhi(r2, r3);

		const t0 = movelh(tr01a, tr23a);
		const t1 = movehl(tr23a, tr01a);
		const t2 = movelh(tr01b, tr23b);
		const t3 = movehl(tr23b, tr01b);

		// permute column vector into rows
		const p0 = permute(v, .{0, 0, 0, 0});
		const p1 = permute(v, .{1, 1, 1, 1});
		const p2 = permute(v, .{2, 2, 2, 2});
		const p3 = permute(v, .{3, 3, 3, 3});

		// mathimus maximus
		o.* = (p0 * t0) + (p1 * t1) + (p2 * t2) + (p3 * t3);
	}
};