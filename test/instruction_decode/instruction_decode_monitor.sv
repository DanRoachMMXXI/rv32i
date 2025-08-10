`include "uvm_macros.svh"
import uvm_pkg::*;

import instruction_decode_pkg::*;

class instruction_decode_monitor extends uvm_monitor;
	`uvm_component_utils(instruction_decode_monitor)
	uvm_analysis_port #(instruction_decode_transaction) analysis_port;
	virtual instruction_decode_if virt_instruction_decode_if;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		analysis_port = new("analysis_port", this);

		if (!uvm_config_db#(virtual instruction_decode_if)::get(this, "", "virt_instruction_decode_if", virt_instruction_decode_if))
			`uvm_fatal("NOVIF", "No virtual interface set for monitor")
	endfunction

	task run_phase(uvm_phase phase);
		forever begin
			instruction_decode_transaction tx = instruction_decode_transaction#(.XLEN(32))::type_id::create("tx");;
			// no clock to sync with here

			#1

			// read the vinstruction_decodees from the virtual interface
			tx.instruction <= virt_instruction_decode_if.instruction;
			tx.rs1 <= virt_instruction_decode_if.rs1;
			tx.rs2 <= virt_instruction_decode_if.rs2;
			tx.rd <= virt_instruction_decode_if.rd;
			tx.immediate <= virt_instruction_decode_if.immediate;
			tx.op1_src <= virt_instruction_decode_if.op1_src;
			tx.op2_src <= virt_instruction_decode_if.op2_src;
			tx.rd_select <= virt_instruction_decode_if.rd_select;
			tx.alu_op <= virt_instruction_decode_if.alu_op;
			tx.sign <= virt_instruction_decode_if.sign;
			tx.branch <= virt_instruction_decode_if.branch;
			tx.branch_if_zero <= virt_instruction_decode_if.branch_if_zero;
			tx.jump <= virt_instruction_decode_if.jump;
			tx.branch_base <= virt_instruction_decode_if.branch_base;
			tx.rf_write_en <= virt_instruction_decode_if.rf_write_en;
			tx.mem_write_en <= virt_instruction_decode_if.mem_write_en;

			// write to analysis port
			analysis_port.write(tx);
		end
	endtask
endclass
