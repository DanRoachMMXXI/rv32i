`include "uvm_macros.svh"
import uvm_pkg::*;

class branch_predictor_sequence extends uvm_sequence #(branch_predictor_transaction);
	`uvm_object_utils(branch_predictor_sequence)

	// needs a default name
	function new (string name = "branch_predictor_sequence");
		super.new(name);
	endfunction

	task body;
		forever begin
			branch_predictor_transaction tx;
			tx = branch_predictor_transaction#(.XLEN(32))::type_id::create("tx");
			start_item(tx);		// handshake to communicate with driver
			
			// no sim license workaround
            tx.pc_plus_four = $urandom_range(0, (1<<31)-1);	// TODO: parameterize by XLEN
            tx.branch_target = $urandom_range(0, (1<<31)-1);
            tx.jump = $urandom_range(0, 1);
			if (tx.jump)	// if unconditional jump,
				tx.branch = 0;	// not a branch
			else	// else maybe a branch
				tx.branch = $urandom_range(0, 1);

			finish_item(tx);	// send transaction to driver
			#1;
		end
	endtask
endclass
