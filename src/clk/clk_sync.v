module clk_sync
#(parameter WIDTH)
(
	input clk_i,
	input [WIDTH - 1:0] dat_i,
	input clk_o,
	output reg [WIDTH - 1:0] dat_o
);

reg [WIDTH - 1:0] tmp;

always @(posedge clk_i) begin
	tmp <= dat_i;
end

always @(posedge clk_o) begin
	dat_o <= tmp;
end

endmodule
