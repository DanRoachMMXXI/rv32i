`include "uvm_macros.svh"
import uvm_pkg::*;

class alu_transaction #(parameter XLEN=32) extends uvm_sequence_item;
	`uvm_object_utils(alu_transaction)

	rand logic [XLEN-1:0] a;
	rand logic [XLEN-1:0] b;
	rand logic [2:0] op;
	rand logic sign;

	constraint c_a {
		a >= 0;
		a <= {XLEN{1'b1}};
	}
	constraint c_b {
		b >= 0;
		b <= {XLEN{1'b1}};
	}
	constraint c_op {
		op >= 1'b000;
		op <= 1'b111;
	}
	constraint c_sign {
		if (!(op inside { 1'b000, 1'b1011 }))
			sign == 0;
	}

	// outputs
	// not rand, will be set by the monitor reading the virtual if
	logic [XLEN-1:0] result;
	logic zero;

	function new(string name = "");
		super.new(name);
	endfunction
endclass
