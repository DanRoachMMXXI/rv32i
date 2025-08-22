`include "uvm_macros.svh"
import uvm_pkg::*;

import branch_evaluator_pkg::*;

module branch_evaluator_tb_top;
	branch_evaluator_if #(.XLEN(32)) virt_branch_evaluator_if();

	// DUT instantiation
	branch_evaluator #(.XLEN(32)) _branch_evaluator(
	.instruction(virt_branch_evaluator_if.instruction),
	.rs1(virt_branch_evaluator_if.rs1),
	.rs2(virt_branch_evaluator_if.rs2),
	.rd(virt_branch_evaluator_if.rd),
	.immediate(virt_branch_evaluator_if.immediate),
	.op1_src(virt_branch_evaluator_if.op1_src),
	.op2_src(virt_branch_evaluator_if.op2_src),
	.rd_select(virt_branch_evaluator_if.rd_select),
	.alu_op(virt_branch_evaluator_if.alu_op),
	.sign(virt_branch_evaluator_if.sign),
	.branch(virt_branch_evaluator_if.branch),
	.branch_if_zero(virt_branch_evaluator_if.branch_if_zero),
	.jump(virt_branch_evaluator_if.jump),
	.branch_base(virt_branch_evaluator_if.branch_base),
	.rf_write_en(virt_branch_evaluator_if.rf_write_en),
	.mem_write_en(virt_branch_evaluator_if.mem_write_en)
	);

	initial begin
		// provide the virtual interface to the driver via uvm_config_db
		uvm_config_db#(virtual branch_evaluator_if)::set(null, "*", "virt_branch_evaluator_if", virt_branch_evaluator_if);
		run_test("branch_evaluator_test");
	end
endmodule
