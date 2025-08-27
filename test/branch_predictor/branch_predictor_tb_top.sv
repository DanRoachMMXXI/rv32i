`include "uvm_macros.svh"
import uvm_pkg::*;

import branch_predictor_pkg::*;

module branch_predictor_tb_top;
	branch_predictor_if #(.XLEN(32)) virt_branch_predictor_if();

	// DUT instantiation
	branch_predictor #(.XLEN(32)) _branch_predictor(
        .pc_plus_four(virt_branch_predictor_if.pc_plus_four),
        .branch_target(virt_branch_predictor_if.branch_target),
        .jump(virt_branch_predictor_if.jump),
        .branch(virt_branch_predictor_if.branch),
        .branch_predicted_taken(virt_branch_predictor_if.branch_predicted_taken)
	);

	initial begin
		// provide the virtual interface to the driver via uvm_config_db
		uvm_config_db#(virtual branch_predictor_if)::set(null, "*", "virt_branch_predictor_if", virt_branch_predictor_if);
		run_test("branch_predictor_test");
	end
endmodule
