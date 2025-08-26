`include "uvm_macros.svh"
import uvm_pkg::*;

class branch_evaluator_sequence extends uvm_sequence #(branch_evaluator_transaction);
	`uvm_object_utils(branch_evaluator_sequence)

	// needs a default name
	function new (string name = "branch_evaluator_sequence");
		super.new(name);
	endfunction

	task body;
		forever begin
			branch_evaluator_transaction tx;
			tx = branch_evaluator_transaction#(.XLEN(32))::type_id::create("tx");
			start_item(tx);		// handshake to communicate with driver
			
			// no sim license workaround

			tx.pc_plus_four = $random();
			// TODO: make predicted_next_instruction sometimes
			// pc_plus_four, sometimes evaluated_branch_target,
			// and sometimes something completely different
			tx.predicted_next_instruction = $random();
			tx.evaluated_branch_target = $random();

			tx.jump = $urandom_range(0, 1);
			if (tx.jump)	// if unconditional jump,
				tx.branch = 0;	// not a branch
			else	// else maybe a branch
				tx.branch = $urandom_range(0, 1);

			tx.branch_if_zero = $urandom_range(0, 1);
			tx.zero = $urandom_range(0, 1);
			tx.branch_prediction = $urandom_range(0, 1);

			finish_item(tx);	// send transaction to driver
			#1;
		end
	endtask
endclass
