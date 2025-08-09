`include "uvm_macros.svh"
import uvm_pkg::*;

import instruction_decode_pkg::*;

class instruction_decode_driver extends uvm_driver #(instruction_decode_transaction);
	`uvm_component_utils(instruction_decode_driver)
	virtual instruction_decode_if virt_instruction_decode_if;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// get the virtual interface from top level testbench
		if (!uvm_config_db#(virtual instruction_decode_if)::get(this, "", "virt_instruction_decode_if", virt_instruction_decode_if))
			`uvm_fatal("NOVIF", "No virtual interface specified for driver")
	endfunction

	task run_phase(uvm_phase phase);
		instruction_decode_transaction tx;
		
		// begin chatgpt format of driver
		forever begin
			seq_item_port.get_next_item(tx);

			// set the inputs of the interface from the
			// transaction
			// TODO change from alu
			virt_instruction_decode_if.a <= tx.a;
			virt_instruction_decode_if.b <= tx.b;
			virt_instruction_decode_if.op <= tx.op;
			virt_instruction_decode_if.sign <= tx.sign;

			# 1

			seq_item_port.item_done();
		end
	endtask
endclass
