`include "uvm_macros.svh"
import uvm_pkg::*;

import branch_evaluator_pkg::*;

class branch_evaluator_monitor extends uvm_monitor;
	`uvm_component_utils(branch_evaluator_monitor)
	uvm_analysis_port #(branch_evaluator_transaction) analysis_port;
	virtual branch_evaluator_if virt_branch_evaluator_if;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		analysis_port = new("analysis_port", this);

		if (!uvm_config_db#(virtual branch_evaluator_if)::get(this, "", "virt_branch_evaluator_if", virt_branch_evaluator_if))
			`uvm_fatal("NOVIF", "No virtual interface set for monitor")
	endfunction

	task run_phase(uvm_phase phase);
		forever begin
			branch_evaluator_transaction tx = branch_evaluator_transaction#(.XLEN(32))::type_id::create("tx");;
			// no clock to sync with here

			#1

			// read the vbranch_evaluatores from the virtual interface
			tx.instruction = virt_branch_evaluator_if.instruction;
			tx.rs1 = virt_branch_evaluator_if.rs1;
			tx.rs2 = virt_branch_evaluator_if.rs2;
			tx.rd = virt_branch_evaluator_if.rd;
			tx.immediate = virt_branch_evaluator_if.immediate;
			tx.op1_src = virt_branch_evaluator_if.op1_src;
			tx.op2_src = virt_branch_evaluator_if.op2_src;
			tx.rd_select = virt_branch_evaluator_if.rd_select;
			tx.alu_op = virt_branch_evaluator_if.alu_op;
			tx.sign = virt_branch_evaluator_if.sign;
			tx.branch = virt_branch_evaluator_if.branch;
			tx.branch_if_zero = virt_branch_evaluator_if.branch_if_zero;
			tx.jump = virt_branch_evaluator_if.jump;
			tx.branch_base = virt_branch_evaluator_if.branch_base;
			tx.rf_write_en = virt_branch_evaluator_if.rf_write_en;
			tx.mem_write_en = virt_branch_evaluator_if.mem_write_en;

			// write to analysis port
			analysis_port.write(tx);
		end
	endtask
endclass
