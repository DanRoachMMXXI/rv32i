`include "uvm_macros.svh"
import uvm_pkg::*;

import instruction_decode_pkg::*;

class instruction_decode_agent extends uvm_agent;
	`uvm_component_utils(instruction_decode_agent)
	instruction_decode_driver driver;
	instruction_decode_monitor monitor;
	uvm_sequencer #(instruction_decode_transaction) sequencer;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		sequencer = uvm_sequencer#(instruction_decode_transaction)::type_id::create("sequencer", this);
		driver = instruction_decode_driver::type_id::create("driver", this);
		monitor = instruction_decode_monitor::type_id::create("monitor", this);
	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		driver.seq_item_port.connect(sequencer.seq_item_export);
	endfunction
endclass
