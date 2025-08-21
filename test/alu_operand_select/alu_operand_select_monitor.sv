`include "uvm_macros.svh"
import uvm_pkg::*;

import alu_operand_select_pkg::*;

class alu_operand_select_monitor extends uvm_monitor;
	`uvm_component_utils(alu_operand_select_monitor)
	uvm_analysis_port #(alu_operand_select_transaction) analysis_port;
	virtual alu_operand_select_if virt_alu_operand_select_if;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		analysis_port = new("analysis_port", this);

		if (!uvm_config_db#(virtual alu_operand_select_if)::get(this, "", "virt_alu_operand_select_if", virt_alu_operand_select_if))
			`uvm_fatal("NOVIF", "No virtual interface set for monitor")
	endfunction

	task run_phase(uvm_phase phase);
		forever begin
			alu_operand_select_transaction tx = alu_operand_select_transaction#(.XLEN(32))::type_id::create("tx");;
			// no clock to sync with here

			#1

			// read the valu_operand_selectes from the virtual interface
			tx.rs1 = virt_alu_operand_select_if.rs1;
			tx.rs2 = virt_alu_operand_select_if.rs2;
			tx.immediate = virt_alu_operand_select_if.immediate;
			tx.pc = virt_alu_operand_select_if.pc;
			tx.alu_op1_src = virt_alu_operand_select_if.alu_op1_src;
			tx.alu_op2_src = virt_alu_operand_select_if.alu_op2_src;
			tx.alu_op1 = virt_alu_operand_select_if.alu_op1;
			tx.alu_op2 = virt_alu_operand_select_if.alu_op2;

			// write to analysis port
			analysis_port.write(tx);
		end
	endtask
endclass
