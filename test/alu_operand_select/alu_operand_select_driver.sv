`include "uvm_macros.svh"
import uvm_pkg::*;

import alu_operand_select_pkg::*;

class alu_operand_select_driver extends uvm_driver #(alu_operand_select_transaction);
	`uvm_component_utils(alu_operand_select_driver)
	virtual alu_operand_select_if virt_alu_operand_select_if;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// get the virtual interface from top level testbench
		if (!uvm_config_db#(virtual alu_operand_select_if)::get(this, "", "virt_alu_operand_select_if", virt_alu_operand_select_if))
			`uvm_fatal("NOVIF", "No virtual interface specified for driver")
	endfunction

	task run_phase(uvm_phase phase);
		alu_operand_select_transaction tx;
		
		// begin chatgpt format of driver
		forever begin
			seq_item_port.get_next_item(tx);

			// set the inputs of the interface from the
			// transaction
			virt_alu_operand_select_if.rs1 = tx.rs1;
			virt_alu_operand_select_if.rs2 = tx.rs2;
			virt_alu_operand_select_if.immediate = tx.immediate;
			virt_alu_operand_select_if.pc = tx.pc;
			virt_alu_operand_select_if.alu_op1_src = tx.alu_op1_src;
			virt_alu_operand_select_if.alu_op2_src = tx.alu_op2_src;
			# 1

			seq_item_port.item_done();
		end
	endtask
endclass
