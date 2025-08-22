`include "uvm_macros.svh"
import uvm_pkg::*;

import branch_predictor_pkg::*;

class branch_predictor_agent extends uvm_agent;
	`uvm_component_utils(branch_predictor_agent)
	branch_predictor_driver driver;
	branch_predictor_monitor monitor;
	uvm_sequencer #(branch_predictor_transaction) sequencer;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		sequencer = uvm_sequencer#(branch_predictor_transaction)::type_id::create("sequencer", this);
		driver = branch_predictor_driver::type_id::create("driver", this);
		monitor = branch_predictor_monitor::type_id::create("monitor", this);
	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		driver.seq_item_port.connect(sequencer.seq_item_export);
	endfunction
endclass
