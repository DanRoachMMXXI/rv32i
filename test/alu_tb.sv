module alu_tb();
	logic [31:0] a;
	logic [31:0] b;

	logic [2:0] op;
	logic sub;

	logic [31:0] result;

	alu alu(
		.a(a),
		.b(b),
		.op(op),
		.sign(sub),
		.result(result));

	initial begin
		// add 5 + 7
		a = 5;
		b = 7;
		op = 0;
		sub = 0;
		#10 $display("add: %0d + %0d: %0d", a, b, result);

		// sub 5 - 7 (overflow)
		sub = 1;
		#10 $display("sub: %0d - %0d: %0d", a, b, result);

		// sub 10 - 7 (no overflow)
		a = 10;
		#10 $display("sub: %0d - %0d: %0d", a, b, result);

		sub = 0;

		// left shift 0x0000000F << 4
		a = 'h0000000F;
		b = 'h00000004;
		op = 3'b001;
		#10 $display("sll: 0x%0h << 0x%0h: 0x%0h", a, b, result);
		//
		// left shift 0x0000000F << 6
		a = 'h0000000F;
		b = 'h00000006;
		op = 3'b001;
		#10 $display("sll: 0x%0h << 0x%0h: 0x%0h", a, b, result);

		// slt (signed) 10 < 5
		a = 10;
		b = 5;
		op = 3'b010;
		#10 $display("slt: %0d < %0d: %0d", a, b, result);

		// slt (signed) 10 < 12
		b = 12;
		#10 $display("slt: %0d < %0d: %0d", a, b, result);

		// sltu 10 < 12
		op = 3'b011;
		#10 $display("sltu: %0d < %0d: %0d", a, b, result);

		// sltu 10 < -1
		b = -1;
		#10 $display("sltu: %0d < %0d: %0d", a, b, result);

		// xor 0xF ^ 0x6
		a = 'hF;
		b = 'h6;
		op = 3'b100;
		#10 $display("xor: 0x%0h ^ 0x%0h: 0x%0h", a, b, result);

		// srl
		a = 'hF0000000;
		b = 4;
		op = 3'b101;
		#10 $display("srl: 0x%0h >> 0x%0h: 0x%0h", a, b, result);

		// sra
		sub = 1;
		#10 $display("sra: 0x%0h >>> 0x%0h: 0x%0h", a, b, result);
		sub = 0;
		
		// or 0xF | 0x6
		a = 'hF;
		b = 'h6;
		op = 3'b110;
		#10 $display("or: 0x%0h | 0x%0h: 0x%0h", a, b, result);

		// and 0xF & 0x6
		op = 3'b111;
		#10 $display("and: 0x%0h & 0x%0h: 0x%0h", a, b, result);

		$finish(0);
	end
endmodule
