`include "uvm_macros.svh"
import uvm_pkg::*;

import alu_pkg::*;

module alu_tb_top;
	alu_if #(.XLEN(32)) virt_alu_if();

	// DUT instantiation
	alu #(.XLEN(32)) _alu(
		.a(virt_alu_if.a),
		.b(virt_alu_if.b),
		.op(virt_alu_if.op),
		.sign(virt_alu_if.sign),
		.result(virt_alu_if.result),
		.zero(virt_alu_if.zero)
	);

	initial begin
		// provide the virtual interface to the driver via uvm_config_db
		uvm_config_db#(virtual alu_if)::set(null, "*", "virt_alu_if", virt_alu_if);
		run_test("alu_test");
	end
endmodule
