`include "uvm_macros.svh"
import uvm_pkg::*;

import rf_wb_select_pkg::*;

module rf_wb_select_tb_top;
	rf_wb_select_if #(.XLEN(32)) virt_rf_wb_select_if();

	// DUT instantiation
	rf_wb_select #(.XLEN(32)) _rf_wb_select(
	.instruction(virt_rf_wb_select_if.instruction),
	.rs1(virt_rf_wb_select_if.rs1),
	.rs2(virt_rf_wb_select_if.rs2),
	.rd(virt_rf_wb_select_if.rd),
	.immediate(virt_rf_wb_select_if.immediate),
	.op1_src(virt_rf_wb_select_if.op1_src),
	.op2_src(virt_rf_wb_select_if.op2_src),
	.rd_select(virt_rf_wb_select_if.rd_select),
	.alu_op(virt_rf_wb_select_if.alu_op),
	.sign(virt_rf_wb_select_if.sign),
	.branch(virt_rf_wb_select_if.branch),
	.branch_if_zero(virt_rf_wb_select_if.branch_if_zero),
	.jump(virt_rf_wb_select_if.jump),
	.branch_base(virt_rf_wb_select_if.branch_base),
	.rf_write_en(virt_rf_wb_select_if.rf_write_en),
	.mem_write_en(virt_rf_wb_select_if.mem_write_en)
	);

	initial begin
		// provide the virtual interface to the driver via uvm_config_db
		uvm_config_db#(virtual rf_wb_select_if)::set(null, "*", "virt_rf_wb_select_if", virt_rf_wb_select_if);
		run_test("rf_wb_select_test");
	end
endmodule
