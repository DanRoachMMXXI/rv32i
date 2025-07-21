interface reservation_station_if #(parameter XLEN=32, parameter TAG_WIDTH=32) (
	input logic clk);
	// inputs
	logic reset;
	logic enable;

	logic [TAG_WIDTH-1:0] reorder_buffer_tag_in;
	logic [2:0] alu_op_in;
	logic [TAG_WIDTH-1:0] op1_tag_in;
	logic [XLEN-1:0] op1_data_in;
	logic [TAG_WIDTH-1:0] op2_tag_in;
	logic [XLEN-1:0] op2_data_in;

	logic cdb_enable;
	logic [TAG_WIDTH-1:0] cdb_tag;
	logic [XLEN-1:0] cdb_data;

	// outputs
	logic busy_out;
	logic ready;
	logic [TAG_WIDTH-1:0] reorder_buffer_tag_out;
	logic [2:0] alu_op_out;
	logic [XLEN-1:0] op1_data_out;
	logic [XLEN-1:0] op2_data_out;
endinterface
