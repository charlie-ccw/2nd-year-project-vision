module EEE_IMGPROC(
	// global clock & reset
	clk,
	reset_n,
	
	// mm slave
	s_chipselect,
	s_read,
	s_write,
	s_readdata,
	s_writedata,
	s_address,

	// stream sink
	sink_data,
	sink_valid,
	sink_ready,
	sink_sop,
	sink_eop,
	
	// streaming source
	source_data,
	source_valid,
	source_ready,
	source_sop,
	source_eop,
	
	// conduit
	mode
	
);


// global clock & reset
input	clk;
input	reset_n;

// mm slave
input							s_chipselect;
input							s_read;
input							s_write;
output	reg	[31:0]				s_readdata;
input	[31:0]					s_writedata;
input	[2:0]					s_address;


// streaming sink
input	[23:0]            		sink_data;
input							sink_valid;
output							sink_ready;
input							sink_sop;
input							sink_eop;

// streaming source
output	[23:0]			  	   	source_data;
output							source_valid;
input							source_ready;
output							source_sop;
output							source_eop;

// conduit export
input                         	mode;

////////////////////////////////////////////////////////////////////////
//
parameter IMAGE_W = 11'd640;
parameter IMAGE_H = 11'd480;
parameter MESSAGE_BUF_MAX = 256;
parameter MSG_INTERVAL = 6;
parameter BB_COL_DEFAULT = 24'h00ff00;


wire [7:0]   red, green, blue, grey;
wire [7:0]   red_out, green_out, blue_out;


/* ------------------------------------------------------------------------------------     Convert RGB to HSV     -----------------------------------------------------------------------------------*/

wire [8:0] hsv_h,hsv_s;
wire [7:0] hsv_v;
wire [7:0] rgb_r,rgb_g,rgb_b;

reg [7:0]max;
reg	[7:0]min;
reg	[13:0]rgb_r_r;
reg	[13:0]rgb_g_r;
reg	[13:0]rgb_b_r;

reg [13:0]rgb_r_r2;
reg	[13:0]rgb_g_r2;
reg	[13:0]rgb_b_r2;
reg	[7:0]max_r;

wire [7:0]max_min;
assign	max_min=max-min;
reg  [7:0]max_min_r;
wire [13:0]max60;
assign max60=max*60;

wire [13:0] g_b;
wire [13:0] b_r;
wire [13:0] r_g;
assign	g_b=(rgb_g_r>=rgb_b_r)?(rgb_g_r-rgb_b_r):(rgb_b_r-rgb_g_r);
assign  b_r=(rgb_b_r>=rgb_r_r)?(rgb_b_r-rgb_r_r):(rgb_r_r-rgb_b_r);
assign  r_g=(rgb_r_r>=rgb_g_r)?(rgb_r_r-rgb_g_r):(rgb_g_r-rgb_r_r);


reg [13:0]temp;
reg	[13:0]hsv_h_r;
reg	[15:0]hsv_s_r;
reg	[7:0]hsv_v_r;

assign rgb_r = red;
assign rgb_g = green;
assign rgb_b = blue;
always@(posedge clk)begin
	rgb_r_r=60*rgb_r;
	rgb_g_r=60*rgb_g;
	rgb_b_r=60*rgb_b;

end
always@(posedge clk)begin
	rgb_r_r2=rgb_r_r;
 	rgb_g_r2=rgb_g_r;
	rgb_b_r2=rgb_b_r;
end


	
always@(posedge clk)begin
	if((rgb_r>=rgb_b)&&(rgb_r>=rgb_g))
		max<=rgb_r;
	else if((rgb_g>=rgb_b)&&(rgb_g>=rgb_r))
		max<=rgb_g;
	else if((rgb_b>=rgb_r)&&(rgb_b>=rgb_g))
		max<=rgb_b;
end

always@(posedge clk)begin
	if((rgb_r<=rgb_b)&&(rgb_r<=rgb_g))
		min<=rgb_r;
	else if((rgb_g<=rgb_b)&&(rgb_g<=rgb_r))
		min<=rgb_g;
	else if((rgb_b<=rgb_r)&&(rgb_b<=rgb_g))
		min<=rgb_b;
end

always@(posedge clk)begin
	max_min_r = max_min;
end

always@(posedge clk)begin
	if(max_min!=0)begin
		if(rgb_r_r==max60)
			temp<=g_b/{6'b0,max_min};
		else if(rgb_g_r==max60)
			temp<=b_r/{6'b0,max_min};
		else if(rgb_b_r==max60)
			temp<=r_g/{6'b0,max_min};
	end
	else if(max_min==0)
		temp<=0;
end

always@(posedge clk)begin
	max_r = max;
end



always@(posedge clk)begin
	if(max_r==0)
		hsv_h_r<=0;
	else if(rgb_r_r2==60*max_r)
		hsv_h_r<=(rgb_g_r2>=rgb_b_r2)?temp:(14'd360-temp);
	else if(rgb_g_r2==60*max_r)
		hsv_h_r<=(rgb_b_r2>=rgb_r_r2)?(temp+120):(14'd120-temp);
	else if(rgb_b_r2==60*max_r)
		hsv_h_r<=(rgb_r_r2>=rgb_g_r2)?(temp+240):(14'd240-temp);
end

always@(posedge clk)begin
	if(max_r==0)
		hsv_s_r<=0;
	else
		hsv_s_r<={max_min_r,8'b0}/{8'b0,max_r};
end

always@(posedge clk)begin
	hsv_v_r = max_r;
end

assign hsv_h=hsv_h_r[8:0];
assign hsv_s=hsv_s_r[8:0];
assign hsv_v=hsv_v_r;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

wire         sop, eop, in_valid, out_ready;



/* ---------------------------------------------------------------------------------	 Detect Color Areas		--------------------------------------------------------------------------------------------- */
wire pink_detect, yellow_detect, blue_detect, red_detect, lightGreen_detect, darkGreen_detect, white_detect;

// assign pink_detect = 	(9'd0 <= hsv_h) && (hsv_h < 9'd60);// && (9'd0 < hsv_s) && (hsv_s < 9'd360) && (8'd0 < hsv_v) && (hsv_v < 8'd255);
// assign yellow_detect = 	(9'd60 <= hsv_h) && (hsv_h < 9'd120);// && (9'd0 < hsv_s) && (hsv_s < 9'd360) && (8'd0 < hsv_v) && (hsv_v < 8'd255);
// assign blue_detect = 	(9'd120 <= hsv_h) && (hsv_h < 9'd180);// && (9'd0 < hsv_s) && (hsv_s < 9'd360) && (8'd0 < hsv_v) && (hsv_v < 8'd255);
// assign red_detect = 	(9'd180 <= hsv_h) && (hsv_h < 9'd240);// && (9'd0 < hsv_s) && (hsv_s < 9'd360) && (8'd0 < hsv_v) && (hsv_v < 8'd255);
// assign lightGreen_detect = 	(9'd240 <= hsv_h) && (hsv_h < 9'd300);// && (9'd0 < hsv_s) && (hsv_s < 9'd360) && (8'd0 < hsv_v) && (hsv_v < 8'd255);
// assign darkGreen_detect = 	(9'd300 <= hsv_h) && (hsv_h < 9'd360);// && (9'd0 < hsv_s) && (hsv_s < 9'd360) && (8'd0 < hsv_v) && (hsv_v < 8'd255);
// assign black_detect = (9'd0 <= hsv_h) && (hsv_h < 9'd40);// && (9'd0 < hsv_s) && (hsv_s < 9'd360) && (8'd0 < hsv_v) && (hsv_v < 8'd255);
// assign white_detect = (9'd50 <= hsv_h) && (hsv_h < 9'd70);// && (9'd0 < hsv_s) && (hsv_s < 9'd360) && (8'd0 < hsv_v) && (hsv_v < 8'd255);
//50-70

// assign pink_detect = 	(9'd120 <= hsv_h) && (hsv_h <= 9'd300) && (9'd0 <= hsv_s) && (hsv_s < 9'd40); //&& (8'd0 < hsv_v) && (hsv_v < 8'd255);
// assign yellow_detect = 	(9'd120 <= hsv_h) && (hsv_h <= 9'd300) && (9'd40 <= hsv_s) && (hsv_s < 9'd80); //&& (8'd0 < hsv_v) && (hsv_v < 8'd255);
// assign blue_detect = 	(9'd120 <= hsv_h) && (hsv_h <= 9'd300) && (9'd80 <= hsv_s) && (hsv_s < 9'd120); //&& (8'd0 < hsv_v) && (hsv_v < 8'd255);
// assign red_detect = 	(9'd120 <= hsv_h) && (hsv_h <= 9'd300) && (9'd120 <= hsv_s) && (hsv_s < 9'd160); //&& (8'd0 < hsv_v) && (hsv_v < 8'd255);
// assign lightGreen_detect = 	(9'd120 <= hsv_h) && (hsv_h <= 9'd300) && (9'd160 <= hsv_s) && (hsv_s < 9'd200); //&& (8'd0 < hsv_v) && (hsv_v < 8'd255);
// assign darkGreen_detect = 	(9'd120 <= hsv_h) && (hsv_h <= 9'd300) && (9'd200 <= hsv_s) && (hsv_s <= 9'd255); //&& (8'd0 < hsv_v) && (hsv_v < 8'd255);
// // // assign black_detect = (9'd0 <= hsv_h) && (hsv_h <= 9'd50) && (9'd150 <= hsv_s) && (hsv_s < 9'd160); //&& (8'd0 < hsv_v) && (hsv_v < 8'd255);
// // // assign white_detect = (9'd0 <= hsv_h) && (hsv_h <= 9'd50) && (9'd150 <= hsv_s) && (hsv_s < 9'd160); //&& (8'd0 < hsv_v) && (hsv_v < 8'd255);


assign pink_detect = 	(9'd10<= hsv_h) && (hsv_h < 9'd40) && (9'd70 <= hsv_s) && (hsv_s < 9'd140) && (8'd255 <= hsv_v) && (hsv_v <= 8'd255);
assign yellow_detect = 	(9'd60 <= hsv_h) && (hsv_h <= 9'd70) && (9'd120 <= hsv_s) && (hsv_s <= 9'd180) && (8'd210 <= hsv_v) && (hsv_v <= 8'd255);
//assign yellow_detect = 	(9'd60 <= hsv_h) && (hsv_h <= 9'd90) && (9'd80 <= hsv_s) && (hsv_s <= 9'd160) && (8'd0 <= hsv_v) && (hsv_v < 8'd200);
assign blue_detect = 	(9'd190 <= hsv_h) && (hsv_h <= 9'd230) && (9'd50 <= hsv_s) && (hsv_s <= 9'd120) && (8'd40 <= hsv_v) && (hsv_v <= 8'd120);
assign red_detect = 	(9'd10 <= hsv_h) && (hsv_h <= 9'd30) && (9'd160 <= hsv_s) && (hsv_s < 9'd200) && ((8'd120 <= hsv_v) && (hsv_v < 8'd150) || (8'd161 <= hsv_v) && (hsv_v < 8'd210) || (8'd221 <= hsv_v) && (hsv_v < 8'd255));
//assign red_detect = 	(9'd0 <= hsv_h) && (hsv_h <= 9'd30) && (9'd80 <= hsv_s) && (hsv_s < 9'd200) && (8'd40 <= hsv_v) && (hsv_v < 8'd120);
assign lightGreen_detect = 	(9'd90 <= hsv_h) && (hsv_h <= 9'd120) && (9'd110 <= hsv_s) && (hsv_s <= 9'd160) && (8'd80 <= hsv_v) && (hsv_v <= 8'd255);
// assign pink_detect = 	(9'd20 <= hsv_h) && (hsv_h <= 9'd60) && (9'd120 <= hsv_s) && (hsv_s <= 9'd200) && (8'd40 <= hsv_v) && (hsv_v <= 8'd200);
assign darkGreen_detect = 	(9'd120 <= hsv_h) && (hsv_h <= 9'd160) && (9'd70 <= hsv_s) && (hsv_s <= 9'd120) && (8'd60 <= hsv_v) && (hsv_v <= 8'd170);
//assign black_detect = (9'd10 <= hsv_h) && (hsv_h <= 9'd40) && (9'd40 <= hsv_s) && (hsv_s < 9'd90) && (8'd31 <= hsv_v) && (hsv_v < 8'd40);
//assign white_detect = (9'd50 <= hsv_h) && (hsv_h <= 9'd70) && (9'd50 <= hsv_s) && (hsv_s < 9'd80) && (8'd255 <= hsv_v) && (hsv_v <= 8'd255);

// assign pink_detect = 	(9'd120 <= hsv_h) && (hsv_h <= 9'd300) && (9'd0 <= hsv_s) && (hsv_s < 9'd80) && (8'd0 <= hsv_v) && (hsv_v <= 8'd40);
// assign yellow_detect = 	(9'd120 <= hsv_h) && (hsv_h <= 9'd300) && (9'd0 <= hsv_s) && (hsv_s < 9'd80) && (8'd40 <= hsv_v) && (hsv_v <= 8'd80);
// assign blue_detect = 	(9'd120 <= hsv_h) && (hsv_h <= 9'd300) && (9'd0 <= hsv_s) && (hsv_s < 9'd80) && (8'd80 <= hsv_v) && (hsv_v <= 8'd120);
// assign red_detect =  (9'd120 <= hsv_h) && (hsv_h <= 9'd300) && (9'd0 <= hsv_s) && (hsv_s < 9'd80) && (8'd120 <= hsv_v) && (hsv_v <= 8'd160);
// assign lightGreen_detect = 	(9'd120 <= hsv_h) && (hsv_h <= 9'd300) && (9'd0 <= hsv_s) && (hsv_s < 9'd80) &&  (8'd160 <= hsv_v) && (hsv_v <= 8'd200);
// assign darkGreen_detect = 	(9'd120 <= hsv_h) && (hsv_h <= 9'd300) && (9'd0 <= hsv_s) && (hsv_s < 9'd80) && (8'd200 <= hsv_v) && (hsv_v <= 8'd255);
// //50-70 0-80 255
//

// Highlight detected areas
wire [23:0] red_high, pink_high;
assign grey = green[7:1] + red[7:2] + blue[7:2]; //Grey = green/2 + red/4 + blue/4
assign red_high  = (y > 200) ? (pink_detect ? {8'd255, 8'd192, 8'd203} : 
									yellow_detect ? {8'd255, 8'd255, 8'd0} :
													blue_detect ? {8'd0, 8'd0, 8'd255} :
																red_detect ? {8'd255, 8'd0, 8'd0} :
																			lightGreen_detect ? {8'd0, 8'd255, 8'd0} :
																								darkGreen_detect ? {8'd0, 8'd128, 8'd0} :
																												white_detect ? {8'd128, 8'd0, 8'd128} :
																															{grey, grey, grey}) : {grey, grey, grey};

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

reg [23:0] new_image;
wire pink_active, yellow_active, blue_active, red_active, lightGreen_active, darkGreen_active;
assign pink_active = ((x == pink_left) || (x == pink_right)) && (11'd28 <= pink_width) && (pink_width <= 11'd280);
assign yellow_active = ((x == yellow_left) || (x == yellow_right)) && (11'd28 <= yellow_width) && (yellow_width <= 11'd280);
assign blue_active = ((x == blue_left) || (x == blue_right)) && (11'd28 <= blue_width) && (blue_width <= 11'd280);
assign red_active = ((x == red_left) || (x == red_right)) && (11'd28 <= red_width) && (red_width <= 11'd280);
assign lightGreen_active = ((x == lightGreen_left) || (x == lightGreen_right)) && (11'd28 <= lightGreen_width) && (lightGreen_width <= 11'd280);
assign darkGreen_active = ((x == darkGreen_left) || (x == darkGreen_right)) && (11'd28 <= darkGreen_width) && (darkGreen_width <= 11'd280);




/*------------------------------------------------------------------------------------------          Filter         ------------------------------------------------------------------------------------*/

reg [7:0] image_to_filter;
reg [23:0] filtered_image;
wire EROTION_ready;
wire EROTION_valid;
reg [7:0] EROTION_data;
wire out_reg_inready;
wire out_reg_invalid;
reg [7:0] EXPAND_data;
wire EXPAND_ready;
wire EXPAND_valid;

always @(*)
begin
   if((pink_detect | yellow_detect | blue_detect | red_detect | lightGreen_detect | darkGreen_detect | white_detect) && (y > 200))
      image_to_filter = 8'd255;
   else 
      image_to_filter = 8'd0;
end

filtering EROTION(
	.clk(clk),
	.rst_n(reset_n),
	.in_data_valid(in_valid),
	.in_data(image_to_filter),
	.out_data_ready(EROTION_ready),
	.out_data_valid(EROTION_valid),
	.out_data(EROTION_data),
	.in_data_ready(out_ready),
	.Threshold(5)
);
//
//filtering_EXPAND expand(
//	.clk(clk),
//	.rst_n(reset_n),
//	.in_data_valid(EROTION_valid),
//	.in_data(EROTION_data),
//	.out_data_ready(EXPAND_ready),
//	.out_data_valid(EXPAND_valid),
//	.out_data(EXPAND_data),
//	.in_data_ready(EROTION_ready)
//);
assign EXPAND_valid = EROTION_valid;
assign EXPAND_ready = EROTION_ready;
always @(*)
begin
   EXPAND_data = EROTION_data;
end

always @(*)
begin
	if(EXPAND_data == 8'd255)
		if(pink_detect)
		  filtered_image = {8'd255, 8'd192, 8'd203};
		else if(yellow_detect)
		  filtered_image = {8'd255, 8'd255, 8'd0};
		else if(blue_detect)
		  filtered_image = {8'd0, 8'd0, 8'd255};
		else if(red_detect)
		  filtered_image = {8'd255, 8'd0, 8'd0};
		else if(lightGreen_detect)
		  filtered_image = {8'd0, 8'd255, 8'd0};
		else if(darkGreen_detect)
		  filtered_image = {8'd0, 8'd128, 8'd0};
		else
//		  filtered_image = {8'd128, 8'd0, 8'd128};
        filtered_image = {grey, grey, grey};
	else
		filtered_image = {grey, grey, grey};
end

always @(*)
begin
	if(mode)
	    new_image = filtered_image;
	else 
	    new_image = red_high;
end

assign out_reg_inready = (mode) ? EXPAND_ready : out_ready;
assign out_reg_invalid = (mode) ? EXPAND_valid : in_valid;


// reg [23:0] reg1,reg2,reg3,reg4,reg5,reg6,reg7,reg8,reg9;
// reg [3:0] dark_num;
// always@(posedge clk) begin
// 	dark_num = 0;
	
// 	reg9 = reg8;
// 	if ((reg9 != {8'd255, 8'd192, 8'd203}) && (reg9 != {8'd255,8'd255,8'd0}) && (reg9 != {8'd0, 8'd0, 8'd255}) && (reg9 != {8'd255, 8'd0, 8'd0}) && (reg9 != {8'd0,8'd255,8'd0}) && (reg9 != {8'd0, 8'd128, 8'd0}))
// 		dark_num = dark_num + 1;
		
// 	reg8 = reg7;
// 	if ((reg8 != {8'd255, 8'd192, 8'd203}) && (reg8 != {8'd255,8'd255,8'd0}) && (reg8 != {8'd0, 8'd0, 8'd255}) && (reg8 != {8'd255, 8'd0, 8'd0}) && (reg8 != {8'd0,8'd255,8'd0}) && (reg8 != {8'd0, 8'd128, 8'd0}))
// 		dark_num = dark_num + 1;
		
// 	reg7 = reg6;
// 	if ((reg7 != {8'd255, 8'd192, 8'd203}) && (reg7 != {8'd255,8'd255,8'd0}) && (reg7 != {8'd0, 8'd0, 8'd255}) && (reg7 != {8'd255, 8'd0, 8'd0}) && (reg7 != {8'd0,8'd255,8'd0}) && (reg7 != {8'd0, 8'd128, 8'd0}))
// 		dark_num = dark_num + 1;
		
// 	reg6 = reg5;
// 	if ((reg6 != {8'd255, 8'd192, 8'd203}) && (reg6 != {8'd255,8'd255,8'd0}) && (reg6 != {8'd0, 8'd0, 8'd255}) && (reg6 != {8'd255, 8'd0, 8'd0}) && (reg6 != {8'd0,8'd255,8'd0}) && (reg6 != {8'd0, 8'd128, 8'd0}))
// 		dark_num = dark_num + 1;
		
// 	reg5 = reg4;
// 	if ((reg5 != {8'd255, 8'd192, 8'd203}) && (reg5 != {8'd255,8'd255,8'd0}) && (reg5 != {8'd0, 8'd0, 8'd255}) && (reg5 != {8'd255, 8'd0, 8'd0}) && (reg5 != {8'd0,8'd255,8'd0}) && (reg5 != {8'd0, 8'd128, 8'd0}))
// 		dark_num = dark_num + 1;
		
// 	reg4 = reg3;
// 	if ((reg4 != {8'd255, 8'd192, 8'd203}) && (reg4 != {8'd255,8'd255,8'd0}) && (reg4 != {8'd0, 8'd0, 8'd255}) && (reg4 != {8'd255, 8'd0, 8'd0}) && (reg4 != {8'd0,8'd255,8'd0}) && (reg4 != {8'd0, 8'd128, 8'd0}))
// 		dark_num = dark_num + 1;
		
// 	reg3 = reg2;
// 	if ((reg3 != {8'd255, 8'd192, 8'd203}) && (reg3 != {8'd255,8'd255,8'd0}) && (reg3 != {8'd0, 8'd0, 8'd255}) && (reg3 != {8'd255, 8'd0, 8'd0}) && (reg3 != {8'd0,8'd255,8'd0}) && (reg3 != {8'd0, 8'd128, 8'd0}))
// 		dark_num = dark_num + 1;
		
// 	reg2 = reg1;
// 	if ((reg2 != {8'd255, 8'd192, 8'd203}) && (reg2 != {8'd255,8'd255,8'd0}) && (reg2 != {8'd0, 8'd0, 8'd255}) && (reg2 != {8'd255, 8'd0, 8'd0}) && (reg2 != {8'd0,8'd255,8'd0}) && (reg2 != {8'd0, 8'd128, 8'd0}))
// 		dark_num = dark_num + 1;
		
// 	reg1 = red_high;
// 	if ((reg1 != {8'd255, 8'd192, 8'd203}) && (reg1 != {8'd255,8'd255,8'd0}) && (reg1 != {8'd0, 8'd0, 8'd255}) && (reg1 != {8'd255, 8'd0, 8'd0}) && (reg1 != {8'd0,8'd255,8'd0}) && (reg1 != {8'd0, 8'd128, 8'd0}))
// 		dark_num = dark_num + 1;
		
// 	// if (dark_num > 4'd2)
// 	// 	new_image = {grey,grey,grey};
// 	// else
// 	new_image = red_high;
// 	//new_image = bb_active ? {8'd0, 8'd0, 8'd0} : red_high;
	
// end



//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// Switch output pixels depending on mode switch
// Don't modify the start-of-packet word - it's a packet discriptor
// Don't modify data in non-video packets


assign {red_out, green_out, blue_out} = (~sop & packet_video) ? (pink_active ? {8'd255, 8'd192, 8'd203} : 
																			yellow_active ? {8'd255, 8'd255, 8'd0} :
																						blue_active ? {8'd0, 8'd0, 8'd255} : 
																									red_active ? {8'd255, 8'd0, 8'd0} :
																												lightGreen_active ? {8'd0, 8'd255, 8'd0} :
																																darkGreen_active ? {8'd0, 8'd128, 8'd0} :
																																			new_image) : {red,green,blue};

//Count valid pixels to tget the image coordinates. Reset and detect packet type on Start of Packet.
reg [10:0] x, y;
reg packet_video;
always@(posedge clk) begin
	if (sop) begin
		x <= 11'h0;
		y <= 11'h0;
		packet_video <= (blue[3:0] == 3'h0);
	end
	else if (in_valid) begin
		if (x == IMAGE_W-1) begin
			x <= 11'h0;
			y <= y + 11'h1;
		end
		else begin
			x <= x + 11'h1;
		end
	end
end

/*------------------------------------------------------------------------------------------	Box	   --------------------------------------------------------------------------------------------*/
reg [10:0] pink_min, pink_max, yellow_min, yellow_max, blue_min, blue_max, red_min, red_max, lightGreen_min, lightGreen_max,darkGreen_min, darkGreen_max;
reg [23:0] color1, color2, color3, color4, color5, color6, color7, color8, color9, color10;
reg [10:0] pink_1, pink_2, yellow_1, yellow_2, blue_1, blue_2, red_1, red_2, lightGreen_1, lightGreen_2,darkGreen_1, darkGreen_2;

always@(posedge clk) begin
	if (in_valid) begin
		color10 = color9;
		color9 = color8;
		color8 = color7;
		color7 = color6;
		color6 = color5;
		color5 = color4;
		color4 = color3;
		color3 = color2;
		color2 = color1;
		color1 = new_image;
		if(color1 == {8'd255, 8'd192, 8'd203} && color2 == {8'd255, 8'd192, 8'd203} && color3 == {8'd255, 8'd192, 8'd203} && color4 == {8'd255, 8'd192, 8'd203} && color5 == {8'd255, 8'd192, 8'd203} && color6 == {8'd255, 8'd192, 8'd203} && color7 == {8'd255, 8'd192, 8'd203} && color8 == {8'd255, 8'd192, 8'd203} && color9 == {8'd255, 8'd192, 8'd203} && color10 == {8'd255, 8'd192, 8'd203}) 
		begin
			// find the x of the first and the last color reg;
			pink_2 = x;
			if( (x - 11'd9) > 11'd0 )
				pink_1 = x - 11'd9;
			else
				pink_1 = x + 11'd631;

			//change the min and max value
			if(pink_1 < pink_min)
				pink_min = pink_1;
			if(pink_2 > pink_max)
				pink_max = pink_2;
		end
		else if(color1 == {8'd255, 8'd255, 8'd0} && color2 == {8'd255, 8'd255, 8'd0} && color3 == {8'd255, 8'd255, 8'd0} && color4 == {8'd255, 8'd255, 8'd0} && color5 == {8'd255, 8'd255, 8'd0} && color6 == {8'd255, 8'd255, 8'd0} && color7 == {8'd255, 8'd255, 8'd0} && color8 == {8'd255, 8'd255, 8'd0} && color9 == {8'd255, 8'd255, 8'd0} && color10 == {8'd255, 8'd255, 8'd0}) 
		begin
			// find the x of the first and the last color reg;
			yellow_2 = x;
			if( (x - 11'd9) > 11'd0 )
				yellow_1 = x - 11'd9;
			else
				yellow_1 = x + 11'd631;

			//change the min and max value
			if(yellow_1 < yellow_min)
				yellow_min = yellow_1;
			if(yellow_2 > yellow_max)
				yellow_max = yellow_2;
		end
		else if(color1 == {8'd0, 8'd0, 8'd255} && color2 == {8'd0, 8'd0, 8'd255} && color3 == {8'd0, 8'd0, 8'd255} && color4 == {8'd0, 8'd0, 8'd255} && color5 == {8'd0, 8'd0, 8'd255} && color6 == {8'd0, 8'd0, 8'd255} && color7 == {8'd0, 8'd0, 8'd255} && color8 == {8'd0, 8'd0, 8'd255} && color9 == {8'd0, 8'd0, 8'd255} && color10 == {8'd0, 8'd0, 8'd255}) 
		begin
			// find the x of the first and the last color reg;
			blue_2 = x;
			if( (x - 11'd9) > 11'd0 )
				blue_1 = x - 11'd9;
			else
				blue_1 = x + 11'd631;

			//change the min and max value
			if(blue_1 < blue_min)
				blue_min = blue_1;
			if(blue_2 > blue_max)
				blue_max = blue_2;
		end
		else if(color1 == {8'd255, 8'd0, 8'd0} && color2 == {8'd255, 8'd0, 8'd0} && color3 == {8'd255, 8'd0, 8'd0} && color4 == {8'd255, 8'd0, 8'd0} && color5 == {8'd255, 8'd0, 8'd0} && color6 == {8'd255, 8'd0, 8'd0} && color7 == {8'd255, 8'd0, 8'd0} && color8 == {8'd255, 8'd0, 8'd0} && color9 == {8'd255, 8'd0, 8'd0} && color10 == {8'd255, 8'd0, 8'd0}) 
		begin
			// find the x of the first and the last color reg;
			red_2 = x;
			if( (x - 11'd9) > 11'd0 )
				red_1 = x - 11'd9;
			else
				red_1 = x + 11'd631;

			//change the min and max value
			if(red_1 < red_min)
				red_min = red_1;
			if(red_2 > red_max)
				red_max = red_2;
		end
		else if(color1 == {8'd0, 8'd255, 8'd0} && color2 == {8'd0, 8'd255, 8'd0} && color3 == {8'd0, 8'd255, 8'd0} && color4 == {8'd0, 8'd255, 8'd0} && color5 == {8'd0, 8'd255, 8'd0} && color6 == {8'd0, 8'd255, 8'd0} && color7 == {8'd0, 8'd255, 8'd0} && color8 == {8'd0, 8'd255, 8'd0} && color9 == {8'd0, 8'd255, 8'd0} && color10 == {8'd0, 8'd255, 8'd0}) 
		begin
			// find the x of the first and the last color reg;
			lightGreen_2 = x;
			if( (x - 11'd9) > 11'd0 )
				lightGreen_1 = x - 11'd9;
			else
				lightGreen_1 = x + 11'd631;

			//change the min and max value
			if(lightGreen_1 < lightGreen_min)
				lightGreen_min = lightGreen_1;
			if(lightGreen_2 > lightGreen_max)
				lightGreen_max = lightGreen_2;
		end
		else if(color1 == {8'd0, 8'd128, 8'd0} && color2 == {8'd0, 8'd128, 8'd0} && color3 == {8'd0, 8'd128, 8'd0} && color4 == {8'd0, 8'd128, 8'd0} && color5 == {8'd0, 8'd128, 8'd0} && color6 == {8'd0, 8'd128, 8'd0} && color7 == {8'd0, 8'd128, 8'd0} && color8 == {8'd0, 8'd128, 8'd0} && color9 == {8'd0, 8'd128, 8'd0} && color10 == {8'd0, 8'd128, 8'd0}) 
		begin
			// find the x of the first and the last color reg;
			darkGreen_2 = x;
			if( (x - 11'd9) > 11'd0 )
				darkGreen_1 = x - 11'd9;
			else
				darkGreen_1 = x + 11'd631;

			//change the min and max value
			if(darkGreen_1 < darkGreen_min)
				darkGreen_min = darkGreen_1;
			if(darkGreen_2 > darkGreen_max)
				darkGreen_max = darkGreen_2;
		end

	end
	if (sop & in_valid) begin	//Reset bounds on start of packet
		pink_min <= IMAGE_W-11'h1;
		pink_max <= 0;
		yellow_min <= IMAGE_W-11'h1;
		yellow_max <= 0;
		blue_min <= IMAGE_W-11'h1;
		blue_max <= 0;
		red_min <= IMAGE_W-11'h1;
		red_max <= 0;
		lightGreen_min <= IMAGE_W-11'h1;
		lightGreen_max <= 0;
		darkGreen_min <= IMAGE_W-11'h1;
		darkGreen_max <= 0;
		color10 <= 24'd0;
		color9 <= 24'd0;
		color8 <= 24'd0;
		color7 <= 24'd0;
		color6 <= 24'd0;
		color5 <= 24'd0;
		color4 <= 24'd0;
		color3 <= 24'd0;
		color2 <= 24'd0;
		color1 <= 24'd0;
	end
end

//Process bounding box at the end of the frame.
reg [1:0] msg_state;
reg [10:0] pink_left, pink_right, yellow_left, yellow_right, blue_left, blue_right, red_left, red_right, lightGreen_left, lightGreen_right, darkGreen_left, darkGreen_right;
reg [7:0] frame_count;
reg [10:0] pink_width, yellow_width, blue_width, red_width, lightGreen_width, darkGreen_width;
reg [10:0] pink_central, yellow_central, blue_central, red_central, lightGreen_central, darkGreen_central;
always@(posedge clk) begin
	if (eop & in_valid & packet_video) begin  //Ignore non-video packets
		
		//Latch edges for display overlay on next frame
		pink_width <= pink_right - pink_left;
		yellow_width <= yellow_right - yellow_left;
		blue_width <= blue_right - blue_left;
		red_width <= red_right - red_left;
		lightGreen_width <= lightGreen_right - lightGreen_left;
		darkGreen_width <= darkGreen_right - darkGreen_left;

		pink_central <= (pink_right + pink_left)/2;
		yellow_central <= (yellow_right + yellow_left)/2;
		blue_central <= (blue_right + blue_left)/2;
		red_central <= (red_right + red_left)/2;
		lightGreen_central <= (lightGreen_right + lightGreen_left)/2;
		darkGreen_central <= (darkGreen_right + darkGreen_left)/2;

		pink_left <= pink_min;
		pink_right <= pink_max;
		yellow_left <= yellow_min;
		yellow_right <= yellow_max;
		blue_left <= blue_min;
		blue_right <= blue_max;
		red_left <= red_min;
		red_right <= red_max;
		lightGreen_left <= lightGreen_min;
		lightGreen_right <= lightGreen_max;
		darkGreen_left <= darkGreen_min;
		darkGreen_right <= darkGreen_max;
		
		//Start message writer FSM once every MSG_INTERVAL frames, if there is room in the FIFO
		frame_count <= frame_count - 1;
		
		if (frame_count == 0 && msg_buf_size < MESSAGE_BUF_MAX - 3) begin
			msg_state <= 2'b01;
			frame_count <= MSG_INTERVAL-1;
		end
	end
	
	//Cycle through message writer states once started
	if (msg_state != 2'b00) msg_state <= msg_state + 2'b01;

end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	
/* ---------------------------------------------------------------------------------------		UART		----------------------------------------------------------------------------------------------- */
//Generate output messages for CPU
reg [31:0] msg_buf_in; 
wire [31:0] msg_buf_out;
reg msg_buf_wr;
wire msg_buf_rd, msg_buf_flush;
wire [7:0] msg_buf_size;
wire msg_buf_empty;
reg [7:0] pink_distance, yellow_distance, blue_distance, red_distance, lightGreen_distance, darkGreen_distance;
reg [1:0] pink_angle, yellow_angle, blue_angle, red_angle, lightGreen_angle, darkGreen_angle;

`define RED_BOX_MSG_ID "RBB"


reg [3:0] c1,c2,c3;
reg [3:0] angle1, angle2, angle3;
reg [3:0] distance1, distance2, distance3;
always@(*) begin	//Write words to FIFO as state machine advances
	case(msg_state)
		2'b00: begin
			msg_buf_in = 32'b0;
			msg_buf_wr = 1'b0;
		end
		2'b01: begin
			//msg_buf_in = `RED_BOX_MSG_ID;	//Message ID
			//pink
			if(11'd124 < pink_width && pink_width <= 160)
				pink_distance = 8'd1;
			else if(11'd101 < pink_width && pink_width <= 124)
				pink_distance = 8'd2;
			else if(11'd86 < pink_width && pink_width <= 101)
				pink_distance = 8'd3;
			else if(11'd74 < pink_width && pink_width <= 86)
				pink_distance = 8'd4;
			else if(11'd65 < pink_width && pink_width <= 74)
				pink_distance = 8'd5;
			else if(11'd58 < pink_width && pink_width <= 65)
				pink_distance = 8'd6;
			else if(11'd53 < pink_width && pink_width <= 58)
				pink_distance = 8'd7;
			else if(11'd48 < pink_width && pink_width <= 53)
				pink_distance = 8'd8;
			else if(11'd44 < pink_width && pink_width <= 48)
				pink_distance = 8'd9;
			else if(11'd41 < pink_width && pink_width <= 44)
				pink_distance = 8'd10;
			else if(11'd38 < pink_width && pink_width <= 41)
				pink_distance = 8'd11;
			else if(11'd36 < pink_width && pink_width <= 38)
				pink_distance = 8'd12;
			else if(11'd34 < pink_width && pink_width <= 36)
				pink_distance = 8'd13;
			else if(11'd32 < pink_width && pink_width <= 34)
				pink_distance = 8'd14;
			else if(11'd30 < pink_width && pink_width <= 32)
				pink_distance = 8'd15;
			else
				pink_distance = 8'd0;

			if((pink_central < 11'd290) && (pink_distance != 0))
				pink_angle = 2'd0;
			else if((11'd350 < pink_central) && (pink_distance != 0)) 
				pink_angle = 2'd1;
			else
				pink_angle = 2'd2;

			//yellow
			if(11'd124 < yellow_width && yellow_width <= 160)
				yellow_distance = 8'd1;
			else if(11'd101 < yellow_width && yellow_width <= 124)
				yellow_distance = 8'd2;
			else if(11'd86 < yellow_width && yellow_width <= 101)
				yellow_distance = 8'd3;
			else if(11'd74 < yellow_width && yellow_width <= 86)
				yellow_distance = 8'd4;
			else if(11'd65 < yellow_width && yellow_width <= 74)
				yellow_distance = 8'd5;
			else if(11'd58 < yellow_width && yellow_width <= 65)
				yellow_distance = 8'd6;
			else if(11'd53 < yellow_width && yellow_width <= 58)
				yellow_distance = 8'd7;
			else if(11'd48 < yellow_width && yellow_width <= 53)
				yellow_distance = 8'd8;
			else if(11'd44 < yellow_width && yellow_width <= 48)
				yellow_distance = 8'd9;
			else if(11'd41 < yellow_width && yellow_width <= 44)
				yellow_distance = 8'd10;
			else if(11'd38 < yellow_width && yellow_width <= 41)
				yellow_distance = 8'd11;
			else if(11'd36 < yellow_width && yellow_width <= 38)
				yellow_distance = 8'd12;
			else if(11'd34 < yellow_width && yellow_width <= 36)
				yellow_distance = 8'd13;
			else if(11'd32 < yellow_width && yellow_width <= 34)
				yellow_distance = 8'd14;
			else if(11'd30 < yellow_width && yellow_width <= 32)
				yellow_distance = 8'd15;
			else
				yellow_distance = 8'd0;
			
			if((yellow_central < 11'd290) && (yellow_distance != 0))
				yellow_angle = 2'd0;
			else if((11'd350 < yellow_central) && (yellow_distance != 0)) 
				yellow_angle = 2'd1;
			else
				yellow_angle = 2'd2;

			//blue
			if(11'd124 < blue_width && blue_width <= 160)
				blue_distance = 8'd1;
			else if(11'd101 < blue_width && blue_width <= 124)
				blue_distance = 8'd2;
			else if(11'd86 < blue_width && blue_width <= 101)
				blue_distance = 8'd3;
			else if(11'd74 < blue_width && blue_width <= 86)
				blue_distance = 8'd4;
			else if(11'd65 < blue_width && blue_width <= 74)
				blue_distance = 8'd5;
			else if(11'd58 < blue_width && blue_width <= 65)
				blue_distance = 8'd6;
			else if(11'd53 < blue_width && blue_width <= 58)
				blue_distance = 8'd7;
			else if(11'd48 < blue_width && blue_width <= 53)
				blue_distance = 8'd8;
			else if(11'd44 < blue_width && blue_width <= 48)
				blue_distance = 8'd9;
			else if(11'd41 < blue_width && blue_width <= 44)
				blue_distance = 8'd10;
			else if(11'd38 < blue_width && blue_width <= 41)
				blue_distance = 8'd11;
			else if(11'd36 < blue_width && blue_width <= 38)
				blue_distance = 8'd12;
			else if(11'd34 < blue_width && blue_width <= 36)
				blue_distance = 8'd13;
			else if(11'd32 < blue_width && blue_width <= 34)
				blue_distance = 8'd14;
			else if(11'd30 < blue_width && blue_width <= 32)
				blue_distance = 8'd15;
			else
				blue_distance = 8'd0;

			if((blue_central < 11'd290) && (blue_distance != 0))
				blue_angle = 2'd0;
			else if((11'd350 < blue_central) && (blue_distance != 0)) 
				blue_angle = 2'd1;
			else
				blue_angle = 2'd2;

			//red
			if(11'd124 < red_width && red_width <= 160)
				red_distance = 8'd1;
			else if(11'd101 < red_width && red_width <= 124)
				red_distance = 8'd2;
			else if(11'd86 < red_width && red_width <= 101)
				red_distance = 8'd3;
			else if(11'd74 < red_width && red_width <= 86)
				red_distance = 8'd4;
			else if(11'd65 < red_width && red_width <= 74)
				red_distance = 8'd5;
			else if(11'd58 < red_width && red_width <= 65)
				red_distance = 8'd6;
			else if(11'd53 < red_width && red_width <= 58)
				red_distance = 8'd7;
			else if(11'd48 < red_width && red_width <= 53)
				red_distance = 8'd8;
			else if(11'd44 < red_width && red_width <= 48)
				red_distance = 8'd9;
			else if(11'd41 < red_width && red_width <= 44)
				red_distance = 8'd10;
			else if(11'd38 < red_width && red_width <= 41)
				red_distance = 8'd11;
			else if(11'd36 < red_width && red_width <= 38)
				red_distance = 8'd12;
			else if(11'd34 < red_width && red_width <= 36)
				red_distance = 8'd13;
			else if(11'd32 < red_width && red_width <= 34)
				red_distance = 8'd14;
			else if(11'd30 < red_width && red_width <= 32)
				red_distance = 8'd15;
			else
				red_distance = 8'd0;

			if((red_central < 11'd290) && (red_distance != 0))
				red_angle = 2'd0;
			else if((11'd350 < red_central) && (red_distance != 0)) 
				red_angle = 2'd1;
			else
				red_angle = 2'd2;

			//lightGreen
			if(11'd124 < lightGreen_width && lightGreen_width <= 160)
				lightGreen_distance = 8'd1;
			else if(11'd101 < lightGreen_width && lightGreen_width <= 124)
				lightGreen_distance = 8'd2;
			else if(11'd86 < lightGreen_width && lightGreen_width <= 101)
				lightGreen_distance = 8'd3;
			else if(11'd74 < lightGreen_width && lightGreen_width <= 86)
				lightGreen_distance = 8'd4;
			else if(11'd65 < lightGreen_width && lightGreen_width <= 74)
				lightGreen_distance = 8'd5;
			else if(11'd58 < lightGreen_width && lightGreen_width <= 65)
				lightGreen_distance = 8'd6;
			else if(11'd53 < lightGreen_width && lightGreen_width <= 58)
				lightGreen_distance = 8'd7;
			else if(11'd48 < lightGreen_width && lightGreen_width <= 53)
				lightGreen_distance = 8'd8;
			else if(11'd44 < lightGreen_width && lightGreen_width <= 48)
				lightGreen_distance = 8'd9;
			else if(11'd41 < lightGreen_width && lightGreen_width <= 44)
				lightGreen_distance = 8'd10;
			else if(11'd38 < lightGreen_width && lightGreen_width <= 41)
				lightGreen_distance = 8'd11;
			else if(11'd36 < lightGreen_width && lightGreen_width <= 38)
				lightGreen_distance = 8'd12;
			else if(11'd34 < lightGreen_width && lightGreen_width <= 36)
				lightGreen_distance = 8'd13;
			else if(11'd32 < lightGreen_width && lightGreen_width <= 34)
				lightGreen_distance = 8'd14;
			else if(11'd30 < lightGreen_width && lightGreen_width <= 32)
				lightGreen_distance = 8'd15;
			else
				lightGreen_distance = 8'd0;

			if((lightGreen_central < 11'd290) && (lightGreen_distance != 0))
				lightGreen_angle = 2'd0;
			else if((11'd350 < lightGreen_central) && (lightGreen_distance != 0)) 
				lightGreen_angle = 2'd1;
			else
				lightGreen_angle = 2'd2;

			//darkGreen
			if(11'd124 < darkGreen_width && darkGreen_width <= 160)
				darkGreen_distance = 8'd1;
			else if(11'd101 < darkGreen_width && darkGreen_width <= 124)
				darkGreen_distance = 8'd2;
			else if(11'd86 < darkGreen_width && darkGreen_width <= 101)
				darkGreen_distance = 8'd3;
			else if(11'd74 < darkGreen_width && darkGreen_width <= 86)
				darkGreen_distance = 8'd4;
			else if(11'd65 < darkGreen_width && darkGreen_width <= 74)
				darkGreen_distance = 8'd5;
			else if(11'd58 < darkGreen_width && darkGreen_width <= 65)
				darkGreen_distance = 8'd6;
			else if(11'd53 < darkGreen_width && darkGreen_width <= 58)
				darkGreen_distance = 8'd7;
			else if(11'd48 < darkGreen_width && darkGreen_width <= 53)
				darkGreen_distance = 8'd8;
			else if(11'd44 < darkGreen_width && darkGreen_width <= 48)
				darkGreen_distance = 8'd9;
			else if(11'd41 < darkGreen_width && darkGreen_width <= 44)
				darkGreen_distance = 8'd10;
			else if(11'd38 < darkGreen_width && darkGreen_width <= 41)
				darkGreen_distance = 8'd11;
			else if(11'd36 < darkGreen_width && darkGreen_width <= 38)
				darkGreen_distance = 8'd12;
			else if(11'd34 < darkGreen_width && darkGreen_width <= 36)
				darkGreen_distance = 8'd13;
			else if(11'd32 < darkGreen_width && darkGreen_width <= 34)
				darkGreen_distance = 8'd14;
			else if(11'd30 < darkGreen_width && darkGreen_width <= 32)
				darkGreen_distance = 8'd15;
			else
				darkGreen_distance = 8'd0;

			if((darkGreen_central < 11'd290) && (darkGreen_distance != 0))
				darkGreen_angle = 2'd0;
			else if((11'd350 < darkGreen_central) && (darkGreen_distance != 0)) 
				darkGreen_angle = 2'd1;
			else
				darkGreen_angle = 2'd2;

			c1 = 4'b0;
			c2 = 4'b0;
			c3 = 4'b0;
			angle1 = 4'b0;
			angle2 = 4'b0;
			angle3 = 4'b0;
			distance1 = 4'b0;
			distance2 = 4'b0;
			distance3 = 4'b0;

		end
		2'b10: begin
			// set c1;
			if(pink_angle != 2'd2 || (pink_angle == 2'd2 && pink_distance != 8'd0)) begin
				c1 = 4'd1;
				angle1 = {2'b0, pink_angle};
				distance1 = pink_distance[3:0];
			end
			else if(yellow_angle != 2'd2 || (yellow_angle == 2'd2 && yellow_distance != 8'd0)) begin
				c1 = 4'd2;
				angle1 = {2'b0, yellow_angle};
				distance1 = yellow_distance[3:0];
			end
			else if(blue_angle != 2'd2 || (blue_angle == 2'd2 && blue_distance != 8'd0)) begin
				c1 = 4'd3;
				angle1 = {2'b0, blue_angle};
				distance1 = blue_distance[3:0];
			end
			else if(red_angle != 2'd2 || (red_angle == 2'd2 && red_distance != 8'd0)) begin
				c1 = 4'd4;
				angle1 = {2'b0, red_angle};
				distance1 = red_distance[3:0];
			end
			else if(lightGreen_angle != 2'd2 || (lightGreen_angle == 2'd2 && lightGreen_distance != 8'd0)) begin
				c1 = 4'd5;
				angle1 = {2'b0, lightGreen_angle};
				distance1 = lightGreen_distance[3:0];
			end
			else if(darkGreen_angle != 2'd2 || (darkGreen_angle == 2'd2 && darkGreen_distance != 8'd0)) begin
				c1 = 4'd6;
				angle1 = {2'b0, darkGreen_angle};
				distance1 = darkGreen_distance[3:0];
			end

			// set c2;
			if(c1 != 4'd0) begin
				if(yellow_angle != 2'd2 || (yellow_angle == 2'd2 && yellow_distance != 8'd0)) begin
					c2 = 4'd2;
					angle2 = {2'b0, yellow_angle};
					distance2 = yellow_distance[3:0];
				end
				else if(blue_angle != 2'd2 || (blue_angle == 2'd2 && blue_distance != 8'd0)) begin
					c2 = 4'd3;
					angle2 = {2'b0, blue_angle};
					distance2 = blue_distance[3:0];
				end
				else if(red_angle != 2'd2 || (red_angle == 2'd2 && red_distance != 8'd0)) begin
					c2 = 4'd4;
					angle2 = {2'b0, red_angle};
					distance2 = red_distance[3:0];
				end
				else if(lightGreen_angle != 2'd2 || (lightGreen_angle == 2'd2 && lightGreen_distance != 8'd0)) begin
					c2 = 4'd5;
					angle2 = {2'b0, lightGreen_angle};
					distance2 = lightGreen_distance[3:0];
				end
				else if(darkGreen_angle != 2'd2 || (darkGreen_angle == 2'd2 && darkGreen_distance != 8'd0)) begin
					c2 = 4'd6;
					angle2 = {2'b0, darkGreen_angle};
					distance2 = darkGreen_distance[3:0];
				end
			end

			//set c3;
			if(c2 != 4'd0) begin
				if(blue_angle != 2'd2 || (blue_angle == 2'd2 && blue_distance != 8'd0)) begin
					c3 = 4'd3;
					angle3 = {2'b0, blue_angle};
					distance3 = blue_distance[3:0];
				end
				else if(red_angle != 2'd2 || (red_angle == 2'd2 && red_distance != 8'd0)) begin
					c3 = 4'd4;
					angle3 = {2'b0, red_angle};
					distance3 = red_distance[3:0];
				end
				else if(lightGreen_angle != 2'd2 || (lightGreen_angle == 2'd2 && lightGreen_distance != 8'd0)) begin
					c3 = 4'd5;
					angle3 = {2'b0, lightGreen_angle};
					distance3 = lightGreen_distance[3:0];
				end
				else if(darkGreen_angle != 2'd2 || (darkGreen_angle == 2'd2 && darkGreen_distance != 8'd0)) begin
					c3 = 4'd6;
					angle3 = {2'b0, darkGreen_angle};
					distance3 = darkGreen_distance[3:0];
				end
			end
			//msg_buf_in = {5'b0, x_min, 5'b0, y_min};	//Top left coordinate
			//msg_buf_in = {1'b0, c1[2:0], angle1, 1'b1, c1[2:0], distance1, 1'b0, c2[2:0], angle2, 1'b1, c2[2:0], distance2};
			msg_buf_in = {2'b0, blue_angle, blue_distance[3:0], 2'b0, yellow_angle, yellow_distance[3:0], 2'b0, pink_angle, pink_distance[3:0], 8'b0};
			msg_buf_wr = 1'b1;
		end
		2'b11: begin
			//msg_buf_in = {5'b0, x_max, 5'b0, y_max}; //Bottom right coordinate
			//msg_buf_in = {8'b10000000, 8'b10000000, 1'b0, c3[2:0], angle3, 1'b1, c3[2:0], distance3};
			msg_buf_in = {8'b11111111, 2'b0, darkGreen_angle, darkGreen_distance[3:0], 2'b0, lightGreen_angle, lightGreen_distance[3:0], 2'b0, red_angle, red_distance[3:0]};
			msg_buf_wr = 1'b1;
		end
	endcase
end
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//Output message FIFO
MSG_FIFO	MSG_FIFO_inst (
	.clock (clk),
	.data (msg_buf_in),
	.rdreq (msg_buf_rd),
	.sclr (~reset_n | msg_buf_flush),
	.wrreq (msg_buf_wr),
	.q (msg_buf_out),
	.usedw (msg_buf_size),
	.empty (msg_buf_empty)
	);


//Streaming registers to buffer video signal
STREAM_REG #(.DATA_WIDTH(26)) in_reg (
	.clk(clk),
	.rst_n(reset_n),
	.ready_out(sink_ready),
	.valid_out(in_valid),
	.data_out({red,green,blue,sop,eop}),
	.ready_in(out_reg_inready),
	.valid_in(sink_valid),
	.data_in({sink_data,sink_sop,sink_eop})
);

STREAM_REG #(.DATA_WIDTH(26)) out_reg (
	.clk(clk),
	.rst_n(reset_n),
	.ready_out(out_ready),
	.valid_out(source_valid),
	.data_out({source_data,source_sop,source_eop}),
	.ready_in(source_ready),
	.valid_in(out_reg_invalid),
	.data_in({red_out, green_out, blue_out, sop, eop})
);


/////////////////////////////////
/// Memory-mapped port		 /////
/////////////////////////////////

// Addresses
`define REG_STATUS    			0
`define READ_MSG    				1
`define READ_ID    				2
`define REG_BBCOL					3

//Status register bits
// 31:16 - unimplemented
// 15:8 - number of words in message buffer (read only)
// 7:5 - unused
// 4 - flush message buffer (write only - read as 0)
// 3:0 - unused


// Process write

reg  [7:0]   reg_status;
reg	[23:0]	bb_col;

always @ (posedge clk)
begin
	if (~reset_n)
	begin
		reg_status <= 8'b0;
		bb_col <= BB_COL_DEFAULT;
	end
	else begin
		if(s_chipselect & s_write) begin
		   if      (s_address == `REG_STATUS)	reg_status <= s_writedata[7:0];
		   if      (s_address == `REG_BBCOL)	bb_col <= s_writedata[23:0];
		end
	end
end


//Flush the message buffer if 1 is written to status register bit 4
assign msg_buf_flush = (s_chipselect & s_write & (s_address == `REG_STATUS) & s_writedata[4]);


// Process reads
reg read_d; //Store the read signal for correct updating of the message buffer

// Copy the requested word to the output port when there is a read.
always @ (posedge clk)
begin
   if (~reset_n) begin
	   s_readdata <= {32'b0};
		read_d <= 1'b0;
	end
	
	else if (s_chipselect & s_read) begin
		if   (s_address == `REG_STATUS) s_readdata <= {16'b0,msg_buf_size,reg_status};
		if   (s_address == `READ_MSG) s_readdata <= {msg_buf_out};
		if   (s_address == `READ_ID) s_readdata <= 32'h1234EEE2;
		if   (s_address == `REG_BBCOL) s_readdata <= {8'h0, bb_col};
	end
	
	read_d <= s_read;
end

//Fetch next word from message buffer after read from READ_MSG
assign msg_buf_rd = s_chipselect & s_read & ~read_d & ~msg_buf_empty & (s_address == `READ_MSG);
						


endmodule