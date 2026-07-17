`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/10 13:26:01
// Design Name: 
// Module Name: icap_ctrl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module icap_ctrl(
    input               sys_clk             ,
    input               sys_rst_n           ,
    //flash
    input               icap_en             ,
    input               erasing             ,//擦除中
    input               programing          ,//编程中
    input               uart_rx             
    );


//parameter TIME_5S = 250_000_000;//周期20ns
// parameter TIME_5S = 50000;//周期20ns 仿真测试用
parameter TIME_5S = 250_000_000;//周期40ns
parameter TIME_2S = 125_000_000;


// parameter DUMMY_WORD        = 32'hFFFF_FFFF;
// parameter SYNC_WORD         = 32'hAA99_5566;
// parameter TYPE1_NOOP        = 32'h2000_0000;
// parameter WBSTAR            = 32'h3002_0001;
// parameter DESIRED_ADDRESS   = 32'h003F_FC00;
// parameter CMD               = 32'h3000_8001;
// parameter IPROG_COMMAND     = 32'h0000_000F;
//bit swaping
parameter DUMMY_WORD        = 32'hFFFF_FFFF;
parameter SYNC_WORD         = 32'h5599_AA66;
parameter TYPE1_NOOP        = 32'h0400_0000;
parameter WBSTAR            = 32'h0C40_0080;
parameter DESIRED_ADDRESS   = 32'h00FC_3F00; //Timer1.bin地址
parameter CMD               = 32'h0C00_0180;
parameter IPROG_COMMAND     = 32'h0000_00F0;


//超时5S跳转到multiboot image
reg  [31:00]    cnt_5s;


reg             uart_rx_r1;
reg             uart_rx_r2;
wire            rx_negedge;

reg             icap_flag;

reg  [03:00]    icap_cnt;
wire            icap_add;
wire            icap_end;


always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        uart_rx_r1 <= 1'b1;
        uart_rx_r2 <= 1'b1;
    end 
    else begin 
        uart_rx_r1 <= uart_rx;
        uart_rx_r2 <= uart_rx_r1;
    end 
end

assign rx_negedge = (!uart_rx_r1) && uart_rx_r2;

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        cnt_5s <= {28{1'b0}};
    end 
    else if(rx_negedge || erasing || programing)begin 
        cnt_5s <= {28{1'b0}};
    end 
    else begin 
        cnt_5s <= cnt_5s + 1'b1;
    end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        icap_flag <= 'd0;
    end 
    else if((cnt_5s == TIME_5S - 1'b1) || icap_en)begin 
        icap_flag <= 1'b1;
    end 
    else if(icap_end)begin
        icap_flag <= 'd0;
    end 
    else begin 
        icap_flag <= icap_flag;
    end 
end


always @(posedge sys_clk or negedge sys_rst_n)begin 
   if(!sys_rst_n)begin
        icap_cnt <= 'd0;
    end 
    else if(icap_add)begin 
        if(icap_end)begin 
            icap_cnt <= 'd0;
        end
        else begin 
            icap_cnt <= icap_cnt + 1'b1;
        end 
    end
end 

assign icap_add = icap_flag;
assign icap_end = icap_add && icap_cnt == 4'd8 - 1'b1;


reg             csib;
reg  [31:00]    icap_data;

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        csib <= 1'b1;
        icap_data <= 'd0;
    end 
    else if(icap_flag)begin 
        csib <= 1'b0;
        case(icap_cnt)
            1'd0    :icap_data <= DUMMY_WORD     ;       
            1'd1    :icap_data <= SYNC_WORD      ;       
            2'd2    :icap_data <= TYPE1_NOOP     ;       
            2'd3    :icap_data <= WBSTAR         ;       
            3'd4    :icap_data <= DESIRED_ADDRESS;       
            3'd5    :icap_data <= CMD            ;       
            3'd6    :icap_data <= IPROG_COMMAND  ;       
            3'd7    :icap_data <= TYPE1_NOOP     ;   
            default :icap_data <= 'd0;
        endcase
    end 
    else begin 
        csib <= 1'b1;
        icap_data <= 'd0;
    end 
end

//   ICAPE2    : In order to incorporate this function into the design,
//   Verilog   : the following instance declaration needs to be placed
//  instance   : in the body of the design code.  The instance name
// declaration : (ICAPE2_inst) and/or the port declarations within the
//    code     : parenthesis may be changed to properly reference and
//             : connect this function to the design.  All inputs
//             : and outputs must be connected.

//  <-----Cut code below this line---->

   // ICAPE2: Internal Configuration Access Port
   //         Artix-7
   // Xilinx HDL Language Template, version 2019.2

   ICAPE2 #(
      .DEVICE_ID(28'h362C093),     // Specifies the pre-programmed Device ID value to be used for simulation
                                  // purposes.
      .ICAP_WIDTH("X32"),         // Specifies the input and output data width.
      .SIM_CFG_FILE_NAME("NONE")  // Specifies the Raw Bitstream (RBT) file to be parsed by the simulation
                                  // model.
   )
   ICAPE2_inst (
      .O( ),         // 32-bit output: Configuration data output bus
      .CLK(sys_clk),     // 1-bit input: Clock Input
      .CSIB(csib),   // 1-bit input: Active-Low ICAP Enable
      .I(icap_data),         // 32-bit input: Configuration data input bus
      .RDWRB(1'b0)  // 1-bit input: Read/Write Select input
   );

   // End of ICAPE2_inst instantiation
				
endmodule
