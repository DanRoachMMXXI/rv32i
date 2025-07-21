`include "uvm_macros.svh"
import uvm_pkg::*;

class alu_driver extends uvm_driver;
	`uvm_component_utils(alu_driver)
	virtual alu_if virt_alu_if;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		// from chatgpt example:
		// if (!uvm_config_db#(virtual alu_if)::get(this, "", "virt_alu_if", virt_alu_if))
		//	`uvm_fatal("NOVIF", "No virtual interface specified for driver")
	endfunction

	task run_phase(uvm_phase phase);
		phase.raise_objection(this);
		// test logic
		#10 phase.drop_objection(this);
	endtask
endclass
