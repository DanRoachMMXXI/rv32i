`ifndef BRANCH_PREDICTOR_PKG_SV
`define BRANCH_PREDICTOR_PKG_SV

package branch_predictor_pkg;
	`include "branch_predictor_transaction.sv"
	`include "branch_predictor_sequence.sv"

	`include "branch_predictor_driver.sv"
	`include "branch_predictor_monitor.sv"
	`include "branch_predictor_agent.sv"
	`include "branch_predictor_scoreboard.sv"
	`include "branch_predictor_env.sv"
	`include "branch_predictor_test.sv"
endpackage

`endif
