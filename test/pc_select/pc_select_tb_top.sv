`include "uvm_macros.svh"
import uvm_pkg::*;

import pc_select_pkg::*;

module pc_select_tb_top;
	pc_select_if #(.XLEN(32)) virt_pc_select_if();

	// DUT instantiation
	pc_select #(.XLEN(32)) _pc_select(
	.instruction(virt_pc_select_if.instruction),
	.rs1(virt_pc_select_if.rs1),
	.rs2(virt_pc_select_if.rs2),
	.rd(virt_pc_select_if.rd),
	.immediate(virt_pc_select_if.immediate),
	.op1_src(virt_pc_select_if.op1_src),
	.op2_src(virt_pc_select_if.op2_src),
	.rd_select(virt_pc_select_if.rd_select),
	.alu_op(virt_pc_select_if.alu_op),
	.sign(virt_pc_select_if.sign),
	.branch(virt_pc_select_if.branch),
	.branch_if_zero(virt_pc_select_if.branch_if_zero),
	.jump(virt_pc_select_if.jump),
	.branch_base(virt_pc_select_if.branch_base),
	.rf_write_en(virt_pc_select_if.rf_write_en),
	.mem_write_en(virt_pc_select_if.mem_write_en)
	);

	initial begin
		// provide the virtual interface to the driver via uvm_config_db
		uvm_config_db#(virtual pc_select_if)::set(null, "*", "virt_pc_select_if", virt_pc_select_if);
		run_test("pc_select_test");
	end
endmodule
