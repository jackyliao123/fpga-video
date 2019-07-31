module i2c_write16(
	input clk2,
	input enable,
	output done,
	input [6:0] addr,
	input [15:0] data,
	output [2:0] nack,
	inout sda,
	inout scl
);

reg clk_enable;
wire clk_internal = clk_enable & clk2;

reg scl_wr, sda_wr;

assign scl = scl_wr ? 1'bz : 1'b0;
assign sda = sda_wr ? 1'bz : 1'b0;

localparam STATE_START = 0;
localparam STATE_WRITE = 1;
localparam STATE_READ = 2;
localparam STATE_STOP = 3;
localparam STATE_DONE = 4;

wire [26:0] buf_w = {addr, 1'b0, 1'b1, data[15:8], 1'b1, data[7:0], 1'b1};
reg [26:0] buf_r;

reg [2:0] state;
reg [4:0] offset;

assign done = state == STATE_DONE;
assign nack = {buf_r[0], buf_r[9], buf_r[18]};

always @(posedge clk2)
	clk_enable <= enable;

always @(posedge clk_internal, negedge enable)
	if(!enable) begin
		sda_wr <= 1;
		offset <= 0;
		state <= STATE_START;
		buf_r <= 0;
	end
	else if(state == STATE_START) begin
		state <= STATE_WRITE;
		sda_wr <= 0;
	end
	else if(state == STATE_WRITE) begin
		if(offset == 27) begin
			state <= STATE_STOP;
			sda_wr <= 0;
		end
		else begin
			state <= STATE_READ;
			sda_wr <= buf_w[26 - offset];
		end
	end
	else if(state == STATE_READ) begin
		state <= STATE_WRITE;
		buf_r[26 - offset] <= sda;
		offset <= offset + 5'd1;
	end
	else if(state == STATE_STOP) begin
		sda_wr <= 1;
		state = STATE_DONE;
	end

always @(negedge clk_internal, negedge enable)
	if(!enable) begin
		scl_wr <= 1;
	end
	else if(state != STATE_DONE) begin
		scl_wr <= ~scl_wr;
	end

endmodule
