interface rf_wb_select_if #(parameter XLEN=32) ();
	logic [XLEN-1:0] alu_result;
	logic [XLEN-1:0] memory_data_out;
	logic [XLEN-1:0] pc_plus_four;
	logic [1:0] select;
	logic [XLEN-1:0] rd;
endinterface
