`include "uvm_macros.svh"
import uvm_pkg::*;

import pc_select_pkg::*;

class pc_select_driver extends uvm_driver #(pc_select_transaction);
	`uvm_component_utils(pc_select_driver)
	virtual pc_select_if virt_pc_select_if;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// get the virtual interface from top level testbench
		if (!uvm_config_db#(virtual pc_select_if)::get(this, "", "virt_pc_select_if", virt_pc_select_if))
			`uvm_fatal("NOVIF", "No virtual interface specified for driver")
	endfunction

	task run_phase(uvm_phase phase);
		pc_select_transaction tx;
		
		// begin chatgpt format of driver
		forever begin
			seq_item_port.get_next_item(tx);

			// set the inputs of the interface from the
			// transaction
			virt_pc_select_if.instruction = tx.instruction;
			# 1

			seq_item_port.item_done();
		end
	endtask
endclass
