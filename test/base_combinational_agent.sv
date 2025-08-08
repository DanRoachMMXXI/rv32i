`include "uvm_macros.svh"
import uvm_pkg::*;

class base_combinational_agent #(
	type driver_t = uvm_driver,
	type monitor_t = uvm_monitor,
	type transaction_t = uvm_sequence_item) extends uvm_agent;
	`uvm_component_utils(base_combinational_agent)

	driver_t driver;
	monitor_t monitor;
	uvm_sequencer #(transaction_t) sequencer;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		sequencer = uvm_sequencer#(transaction_t)::type_id::create("sequencer", this);
		driver = driver_t::type_id::create("driver", this);
		monitor = monitor_t::type_id::create("monitor", this);
	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		driver.seq_item_port.connect(sequencer.seq_item_export);
	endfunction
endclass
