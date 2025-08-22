`include "uvm_macros.svh"
import uvm_pkg::*;

import pc_select_pkg::*;

class pc_select_agent extends uvm_agent;
	`uvm_component_utils(pc_select_agent)
	pc_select_driver driver;
	pc_select_monitor monitor;
	uvm_sequencer #(pc_select_transaction) sequencer;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		sequencer = uvm_sequencer#(pc_select_transaction)::type_id::create("sequencer", this);
		driver = pc_select_driver::type_id::create("driver", this);
		monitor = pc_select_monitor::type_id::create("monitor", this);
	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		driver.seq_item_port.connect(sequencer.seq_item_export);
	endfunction
endclass
