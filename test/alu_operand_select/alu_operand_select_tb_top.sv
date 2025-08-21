`include "uvm_macros.svh"
import uvm_pkg::*;

import alu_operand_select_pkg::*;

module alu_operand_select_tb_top;
	alu_operand_select_if #(.XLEN(32)) virt_alu_operand_select_if();

	// DUT instantiation
	alu_operand_select #(.XLEN(32)) _alu_operand_select(
		.rs1(virt_alu_operand_select_if.rs1),
		.rs2(virt_alu_operand_select_if.rs2),
		.immediate(virt_alu_operand_select_if.immediate),
		.pc(virt_alu_operand_select_if.pc),
		.alu_op1_src(virt_alu_operand_select_if.alu_op1_src),
		.alu_op2_src(virt_alu_operand_select_if.alu_op2_src),
		.alu_op1(virt_alu_operand_select_if.alu_op1),
		.alu_op2(virt_alu_operand_select_if.alu_op2)
	);

	initial begin
		// provide the virtual interface to the driver via uvm_config_db
		uvm_config_db#(virtual alu_operand_select_if)::set(null, "*", "virt_alu_operand_select_if", virt_alu_operand_select_if);
		run_test("alu_operand_select_test");
	end
endmodule
