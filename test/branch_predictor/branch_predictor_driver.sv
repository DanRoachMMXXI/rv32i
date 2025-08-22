`include "uvm_macros.svh"
import uvm_pkg::*;

import branch_predictor_pkg::*;

class branch_predictor_driver extends uvm_driver #(branch_predictor_transaction);
	`uvm_component_utils(branch_predictor_driver)
	virtual branch_predictor_if virt_branch_predictor_if;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// get the virtual interface from top level testbench
		if (!uvm_config_db#(virtual branch_predictor_if)::get(this, "", "virt_branch_predictor_if", virt_branch_predictor_if))
			`uvm_fatal("NOVIF", "No virtual interface specified for driver")
	endfunction

	task run_phase(uvm_phase phase);
		branch_predictor_transaction tx;
		
		// begin chatgpt format of driver
		forever begin
			seq_item_port.get_next_item(tx);

			// set the inputs of the interface from the
			// transaction
			virt_branch_predictor_if.instruction = tx.instruction;
			# 1

			seq_item_port.item_done();
		end
	endtask
endclass
