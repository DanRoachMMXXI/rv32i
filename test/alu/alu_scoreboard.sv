class alu_scoreboard extends uvm_component;	// see if it should be component or scoreboard
	`uvm_component_utils(alu_scoreboard)

	uvm_analysis_imp #(alu_transaction, alu_scoreboard) analysis_export;
	// no need for the expected state here, it's a combinational component
	
	function new(string name, uvm_component parent);
		super.new(name, parent);
		analysis_export = new("analysis_export", this);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction

	function void write(alu_transaction tx);
		// TODO: validation logic
	endfunction
endclass
