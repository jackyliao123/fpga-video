module nes(
	input rst,
	input clk,
	input enable,

	output [15:0] prg_addr,
	output prg_r,
	output prg_w,
	input [7:0] prg_r_data,
	output [7:0] prg_w_data,

	output [13:0] chr_addr,
	output chr_r,
	output chr_w,
	input [7:0] chr_r_data,
	output [7:0] chr_w_data,

	input [7:0] joy_a,
	input [7:0] joy_b,

	output [5:0] pix_color,
	output [2:0] pix_emphasis,
	output [8:0] pix_x,
	output [8:0] pix_y,

	output [15:0] audio_sample
);

wire nmi;

wire [15:0] cpu_addr;
reg [7:0] cpu_r_data;
wire [7:0] cpu_w_data;
wire cpu_r;
wire cpu_w = ~cpu_r;

wire [13:0] ppu_addr;
reg [7:0] ppu_r_data;
wire [7:0] ppu_w_data;
wire ppu_r;
wire ppu_w;

wire [7:0] ram_cpu_r_data;
wire [7:0] ppu_cpu_r_data;

wire [7:0] ram_ppu_r_data;

wire cpu_addr_is_ram = (16'h0000 <= cpu_addr) & (cpu_addr < 16'h2000);
wire cpu_addr_is_ppu = (16'h2000 <= cpu_addr) & (cpu_addr < 16'h4000);
wire cpu_addr_is_prg = (16'h4020 <= cpu_addr);

wire ppu_addr_is_chr = (16'h0000 <= ppu_addr) & (ppu_addr < 16'h2000);
wire ppu_addr_is_ram = (16'h2000 <= ppu_addr) & (ppu_addr < 16'h3F00);

assign prg_addr = cpu_addr;
assign prg_r = cpu_r & cpu_addr_is_prg;
assign prg_w = 0; 

assign chr_addr = ppu_addr;
assign chr_r = ppu_r & ppu_addr_is_chr;
assign chr_w = 0;

reg [3:0] clk_cnt;

wire sys_type = 0;

ram_cpu rcpu(
	.clock(~clk),
	.address(cpu_addr),
	.data(cpu_w_data),
	.wren(cpu_w & cpu_addr_is_ram & enable),
	.q(ram_cpu_r_data)
);
ram_ppu rppu(
	.clock(~clk),
	.address({ppu_addr[13:12], 1'b0, ppu_addr[10:0]}),
	.data(ppu_w_data),
	.wren(ppu_w & ppu_addr_is_ram & enable),
	.q(ram_ppu_r_data)
);

always @(posedge clk, posedge rst) begin
	if(rst) begin
		clk_cnt <= 0;
	end
	else if(enable) begin
		clk_cnt <= clk_cnt == 2 ? 0 : clk_cnt + 1;
	end
end

wire cpu_en = clk_cnt == 0;
wire cpu_preread = clk_cnt == 1;
wire cpu_ppu_transfer = clk_cnt == 2;

always @(*) begin
	if(cpu_addr_is_ram)
		cpu_r_data = ram_cpu_r_data;
	else if(cpu_addr_is_ppu)
		cpu_r_data = ppu_cpu_r_data;
	else if(cpu_addr_is_prg)
		cpu_r_data = prg_r_data;
	else
		cpu_r_data = 0;

	if(ppu_addr_is_chr)
		ppu_r_data = chr_r_data;
	else if(ppu_addr_is_ram)
		ppu_r_data = ram_ppu_r_data;
	else
		ppu_r_data = 0;
end

RP2A03 cpu(
	.res_n(~rst),
	.clk(clk),
	.enable(cpu_en & enable),
	
	.IRQ_n(1'b1),
	.NMI_n(~nmi),
	.R_W_n(cpu_r),

	.A(cpu_addr),
	.DI(cpu_r ? cpu_r_data : cpu_w_data),
	.DO(cpu_w_data),

	.joy_a(joy_a),
	.joy_b(joy_b),

	.audio_sample(audio_sample)
);

PPU ppu(
	.clk(clk),
	.ce(enable),
	.reset(rst),
	.sys_type(sys_type),

	.din(cpu_w_data),
	.dout(ppu_cpu_r_data),
	.ain(cpu_addr[2:0]),
	.read(cpu_r & cpu_addr_is_ppu & cpu_ppu_transfer),
	.write(cpu_w & cpu_addr_is_ppu & cpu_ppu_transfer),

	.nmi(nmi),

	.pre_read(cpu_r & cpu_addr_is_ppu & cpu_preread),
	.pre_write(cpu_w & cpu_addr_is_ppu & cpu_preread),

	.vram_r(ppu_r),
	.vram_w(ppu_w),
	.vram_a(ppu_addr),
	.vram_din(ppu_w ? ppu_w_data : ppu_r_data),
	.vram_dout(ppu_w_data),

	.color(pix_color),
	.cycle(pix_x),
	.scanline(pix_y),
	.emphasis(pix_emphasis),

	.mapper_ppu_flags(),
	.short_frame()
);

endmodule
