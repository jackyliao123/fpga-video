module inp_shift_reg(
	input rst,
	input clk,
	input enable,
	input set_unlatch,
	input unlatch_val,
	input [7:0] inp,
	output out
);

reg unlatch;
reg [7:0] latch_val;

assign out = latch_val[0];

always @(posedge clk, posedge unlatch) begin
	if(unlatch)
		latch_val <= inp;
	else if(enable)
		latch_val <= {1'b1, latch_val[7:1]};
end

always @(posedge clk, posedge rst) begin
	if(rst)
		unlatch <= 1;
	else if(enable) begin
		if(set_unlatch)
			unlatch <= unlatch_val;
	end
end

endmodule

module RP2A03(
	input res_n,
	input clk,
	input enable,
	input IRQ_n,
	input NMI_n,
	output reg R_W_n,
	output reg [15:0] A,
	input [7:0] DI,
	output reg [7:0] DO,
	input [7:0] joy_a,
	input [7:0] joy_b,
	output [15:0] audio_sample
);

localparam DMA_STOP = 0;
localparam DMA_WAIT1 = 1;
localparam DMA_WAIT2 = 2;
localparam DMA_READ = 3;
localparam DMA_WRITE = 4;

reg [15:0] dma_addr;
reg [2:0] dma_state = DMA_STOP;

reg [7:0] dma_data;
reg [7:0] dma_DO;

wire [7:0] apu_DI;

reg [15:0] cpu_A;
reg [7:0] cpu_DO, cpu_DI;
reg cpu_R_W_n;

reg cpu_enable;

wire cpu_addr_is_apu = (16'h4000 <= cpu_A) & (cpu_A < 16'h4020) & ~(cpu_A == 16'h4014);

reg joy_set_unlatch, joy_unlatch_val;
wire joy_a_val;
reg joy_a_en;

inp_shift_reg joy_a_reg(
	.rst(~res_n),
	.clk(clk),
	.enable(enable & joy_a_en),
	.set_unlatch(joy_set_unlatch),
	.unlatch_val(joy_unlatch_val),
	.inp(joy_a),
	.out(joy_a_val)
);

always @(*) begin
	if(dma_state != DMA_STOP) begin
		cpu_DI <= DI;
		DO <= dma_DO;
		R_W_n <= dma_state != DMA_WRITE;
		A <= dma_state == DMA_READ ? dma_addr : (dma_state == DMA_WRITE ? 16'h2004 : 16'h0);
		cpu_enable <= 1'b0;
	end
	else if(cpu_A == 16'h4016) begin
		if(cpu_R_W_n) begin
			cpu_DI <= {7'b0, joy_a_val};
		end
		else begin
			cpu_DI <= cpu_DO;
		end
		DO <= cpu_DO;
		R_W_n <= 1'b1;
		A <= cpu_A;
		cpu_enable <= 1'b1;
	end
	else if(cpu_addr_is_apu) begin
		cpu_DI <= apu_DI;
		DO <= 0;
		R_W_n <= 1'b1;
		A <= cpu_A;
		cpu_enable <= 1'b1;
	end
	else begin
		cpu_DI <= DI;
		DO <= cpu_DO;
		R_W_n <= cpu_R_W_n | ((16'h4000 < cpu_A) & (cpu_A < 16'h4020));
		A <= cpu_A;
		cpu_enable <= 1'b1;
	end

	joy_a_en = 0;
	joy_set_unlatch = 0;
	joy_unlatch_val = 0;

	if(cpu_A == 16'h4016) begin
		joy_a_en <= 1;
		if(~cpu_R_W_n) begin
			joy_set_unlatch = 1;
			joy_unlatch_val = cpu_DO[0];
		end
	end
end

wire irq;

reg cycle_parity;

T65 cpu(
	.mode(0),
	.BCD_en(0),

	.res_n(res_n),
	.clk(clk),
	.enable(enable & cpu_enable),
	.rdy(1'b1),
	
	.IRQ_n(~irq),
	.NMI_n(NMI_n),
	.R_W_n(cpu_R_W_n),

	.A(cpu_A),
	.DI(cpu_DI),
	.DO(cpu_DO)
);

APU apu(
	.clk(clk),
	.ce(enable),
	.reset(~res_n),
	.PAL(0),
	.ADDR(cpu_A),
	.DIN(cpu_DO),
	.DOUT(apu_DI),
	.MW(~cpu_R_W_n & cpu_addr_is_apu),
	.MR(cpu_R_W_n & cpu_addr_is_apu),
	.audio_channels(5'b11111),
	.Sample(audio_sample),
	.DmaReq(),
	.DmaAck(1'b0),
	.DmaAddr(),
	.DmaData(8'b0),
	.odd_or_even(1'b0),
	.IRQ(irq)
);

always @(posedge clk, negedge res_n) begin
	if(!res_n) begin
		dma_state <= DMA_STOP;
		cycle_parity <= 0;
	end
	else if(enable) begin
		cycle_parity <= ~cycle_parity;
		if(dma_state == DMA_STOP) begin
			if(~cpu_R_W_n & cpu_A == 16'h4014) begin
				dma_state <= DMA_WAIT1;
				dma_addr <= {cpu_DO, 8'h0};
			end
		end
		else if(dma_state == DMA_WAIT1) begin
			dma_state <= cycle_parity ? DMA_WAIT1 : DMA_WAIT2;
		end
		else if(dma_state == DMA_WAIT2) begin
			dma_state <= DMA_READ;
		end
		else if(dma_state == DMA_READ) begin
			dma_state <= DMA_WRITE;
			dma_DO <= DI;
		end
		else if(dma_state == DMA_WRITE) begin
			if(dma_addr[7:0] == 8'hFF)
				dma_state <= DMA_STOP;
			else begin
				dma_state <= DMA_READ;
				dma_addr[7:0] <= dma_addr[7:0] + 8'd1;
			end
		end
	end
end

endmodule
