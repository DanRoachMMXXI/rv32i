`include "uvm_macros.svh"
import uvm_pkg::*;

import alu_pkg::*;

class alu_driver extends uvm_driver #(alu_transaction);
	`uvm_component_utils(alu_driver)
	virtual alu_if virt_alu_if;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// get the virtual interface from top level testbench
		if (!uvm_config_db#(virtual alu_if)::get(this, "", "virt_alu_if", virt_alu_if))
			`uvm_fatal("NOVIF", "No virtual interface specified for driver")
	endfunction

	task run_phase(uvm_phase phase);
		alu_transaction tx;
		
		// begin chatgpt format of driver
		forever begin
			seq_item_port.get_next_item(tx);

			// set the inputs of the interface from the
			// transaction
			virt_alu_if.a <= tx.a;
			virt_alu_if.b <= tx.b;
			virt_alu_if.op <= tx.op;
			virt_alu_if.sign <= tx.sign;

			// wait some amount of time so the inputs are applied.
			// chatgpt example was for a sequential item, so it
			// waited for @(posedge vif.clk)
			# 10

			seq_item_port.item_done();
		end
	endtask
endclass
