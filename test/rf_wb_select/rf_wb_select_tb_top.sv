`include "uvm_macros.svh"
import uvm_pkg::*;

import rf_wb_select_pkg::*;

module rf_wb_select_tb_top;
	rf_wb_select_if #(.XLEN(32)) virt_rf_wb_select_if();

	// DUT instantiation
	rf_wb_select #(.XLEN(32)) _rf_wb_select(
        .alu_result(virt_rf_wb_select_if.alu_result),
        .memory_data_out(virt_rf_wb_select_if.memory_data_out),
        .pc_plus_four(virt_rf_wb_select_if.pc_plus_four),
        .select(virt_rf_wb_select_if.select),
        .rd(virt_rf_wb_select_if.rd)
	);

	initial begin
		// provide the virtual interface to the driver via uvm_config_db
		uvm_config_db#(virtual rf_wb_select_if)::set(null, "*", "virt_rf_wb_select_if", virt_rf_wb_select_if);
		run_test("rf_wb_select_test");
	end
endmodule
