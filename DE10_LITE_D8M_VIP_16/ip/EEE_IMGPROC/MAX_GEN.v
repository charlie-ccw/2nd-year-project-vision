module MAX_GEN
(
  clk,
  rst_n,
  in_valid,
  in_ready,
  in_data,
  out_valid,
  out_ready,
  matrix_11,
  matrix_12,
  matrix_13,
  matrix_21,
  matrix_22,
  matrix_23,
  matrix_31,
  matrix_32,
  matrix_33
);

input clk;
input rst_n;
input in_valid;
input in_ready;
input [7:0] in_data;
output out_valid;
output out_ready;
output [7:0] matrix_11;
output [7:0] matrix_12;
output [7:0] matrix_13;
output [7:0] matrix_21;
output [7:0] matrix_22;
output [7:0] matrix_23;
output [7:0] matrix_31;
output [7:0] matrix_32;
output [7:0] matrix_33;
reg    [10:0] pixel_counter;
wire    [7:0]    row1_data;    
wire    [7:0]    row2_data;   
wire    [7:0]    row3_data;
reg [7:0] matrix_11;
reg [7:0] matrix_12;
reg [7:0] matrix_13;
reg [7:0] matrix_21;
reg [7:0] matrix_22;
reg [7:0] matrix_23;
reg [7:0] matrix_31;
reg [7:0] matrix_32;
reg [7:0] matrix_33;    

assign row3_data = in_data;
assign out_ready = in_ready;
assign out_valid = in_valid;

always @(*)
begin
   matrix_13 <= row1_data;
	matrix_23 <= row2_data;
   matrix_33 <= row3_data;
end

always @(posedge clk)
begin
   if(!rst_n | (pixel_counter == 639))
	   pixel_counter <= 0;
	else
	begin
	   if(in_valid)
		   pixel_counter <= pixel_counter + 1;
		else
		   pixel_counter <= pixel_counter;
	end
end

shiftram	shiftram_matgen (
	.clken ( in_valid ),
	.clock ( clk ),
	.shiftin ( row3_data ),
	.shiftout (),
	.taps0x ( row2_data ),
	.taps1x ( row1_data )
	);

always @(posedge clk)
begin
   if(!rst_n | (pixel_counter == 639))
	begin
	    {matrix_11, matrix_12} <= {24'd0, 24'd0};
		 {matrix_21, matrix_22} <= {24'd0, 24'd0};
		 {matrix_31, matrix_32} <= {24'd0, 24'd0};
	end
	else
	begin
	   if(in_valid)
		begin
		  {matrix_11, matrix_12} <= {matrix_12, matrix_13};
		  {matrix_21, matrix_22} <= {matrix_22, matrix_23};
		  {matrix_31, matrix_32} <= {matrix_32, matrix_33};
		end
		else
		begin
		  {matrix_11, matrix_12} <= {matrix_11, matrix_12};
		  {matrix_21, matrix_22} <= {matrix_21, matrix_22};
		  {matrix_31, matrix_32} <= {matrix_31, matrix_32};
		end
	end
		 
end

endmodule
