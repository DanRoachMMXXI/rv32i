/*
 * one-hot signal granting access to the common data bus.
 * the most significant bit of the input value is granted
 * access to the bus.  if anything is being granted access
 * to the bus, cdb_active is set.  consumers of data on
 * the cdb will refer to cdb_active to know if the data is
 * valid.
 *
 * I am currently too stupid to make one of these myself,
 * logic taken from https://www.edaplayground.com/x/k75i
 */
module cdb_arbiter #(parameter N=4) (
	input logic [N-1:0] request,
	output logic [N-1:0] grant,
	output logic cdb_active
	);

	wire [N-1:0] mask;
	assign mask[N-1] = 1'b0;
	assign mask[N-2:0] = mask[N-1:1] | request[N-1:1];
	assign grant = request & ~mask;

	assign cdb_active = |grant;
endmodule
