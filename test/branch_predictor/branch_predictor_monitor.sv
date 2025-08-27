`include "uvm_macros.svh"
import uvm_pkg::*;

import branch_predictor_pkg::*;

class branch_predictor_monitor extends uvm_monitor;
	`uvm_component_utils(branch_predictor_monitor)
	uvm_analysis_port #(branch_predictor_transaction) analysis_port;
	virtual branch_predictor_if virt_branch_predictor_if;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		analysis_port = new("analysis_port", this);

		if (!uvm_config_db#(virtual branch_predictor_if)::get(this, "", "virt_branch_predictor_if", virt_branch_predictor_if))
			`uvm_fatal("NOVIF", "No virtual interface set for monitor")
	endfunction

	task run_phase(uvm_phase phase);
		forever begin
			branch_predictor_transaction tx = branch_predictor_transaction#(.XLEN(32))::type_id::create("tx");
			// no clock to sync with here

			#1

			// read the vbranch_predictores from the virtual interface
            tx.pc_plus_four = virt_branch_predictor_if.pc_plus_four;
            tx.branch_target = virt_branch_predictor_if.branch_target;
            tx.jump = virt_branch_predictor_if.jump;
            tx.branch = virt_branch_predictor_if.branch;
            tx.branch_predicted_taken = virt_branch_predictor_if.branch_predicted_taken;

			// write to analysis port
			analysis_port.write(tx);
		end
	endtask
endclass
