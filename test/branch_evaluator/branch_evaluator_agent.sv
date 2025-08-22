`include "uvm_macros.svh"
import uvm_pkg::*;

import branch_evaluator_pkg::*;

class branch_evaluator_agent extends uvm_agent;
	`uvm_component_utils(branch_evaluator_agent)
	branch_evaluator_driver driver;
	branch_evaluator_monitor monitor;
	uvm_sequencer #(branch_evaluator_transaction) sequencer;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		sequencer = uvm_sequencer#(branch_evaluator_transaction)::type_id::create("sequencer", this);
		driver = branch_evaluator_driver::type_id::create("driver", this);
		monitor = branch_evaluator_monitor::type_id::create("monitor", this);
	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		driver.seq_item_port.connect(sequencer.seq_item_export);
	endfunction
endclass
