`include "uvm_macros.svh"
import uvm_pkg::*;

import instruction_decode_pkg::*;

module instruction_decode_tb_top;
	instruction_decode_if #(.XLEN(32)) virt_instruction_decode_if();

	// DUT instantiation
	instruction_decode #(.XLEN(32)) _instruction_decode(
	.instruction(virt_instruction_decode_if.instruction),
	.rs1(virt_instruction_decode_if.rs1),
	.rs2(virt_instruction_decode_if.rs2),
	.rd(virt_instruction_decode_if.rd),
	.immediate(virt_instruction_decode_if.immediate),
	.op1_src(virt_instruction_decode_if.op1_src),
	.op2_src(virt_instruction_decode_if.op2_src),
	.rd_select(virt_instruction_decode_if.rd_select),
	.alu_op(virt_instruction_decode_if.alu_op),
	.sign(virt_instruction_decode_if.sign),
	.branch(virt_instruction_decode_if.branch),
	.branch_if_zero(virt_instruction_decode_if.branch_if_zero),
	.jump(virt_instruction_decode_if.jump),
	.branch_base(virt_instruction_decode_if.branch_base),
	.rf_write_en(virt_instruction_decode_if.rf_write_en),
	.mem_write_en(virt_instruction_decode_if.mem_write_en)
	);

	initial begin
		// provide the virtual interface to the driver via uvm_config_db
		uvm_config_db#(virtual instruction_decode_if)::set(null, "*", "virt_instruction_decode_if", virt_instruction_decode_if);
		run_test("instruction_decode_test");
	end
endmodule
