`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/08 11:04:04
// Design Name: 
// Module Name: uart_rx
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


module uart_rx(
    input               sys_clk             ,
    input               sys_rst_n           ,
    //Uart
    input               uart_rx             ,
    output reg  [07:00] uart_rx_data        ,//Uart接受数据
    output reg          uart_rx_data_vld     //Uart接受数据有效
    );

parameter BAUD = 50_000_000/115_200 ;

//寄存打拍
reg             uart_rx_r1          ;
reg             uart_rx_r2          ;
wire            uart_rx_start       ;

//bit计数器
reg  [03:00]    bit_cnt             ;
wire            bit_add             ;
wire            bit_end             ;

//BAUD计数器
reg  [$clog2(BAUD) - 1:00]  baud_cnt;
wire            baud_add            ;
wire            baud_end            ;

//BAUD计数标志
reg             rx_flag             ;
//对uart_rx打拍
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

assign uart_rx_start = (!uart_rx_r1) && uart_rx_r2 && (bit_cnt == 1'b0);

always @(posedge sys_clk or negedge sys_rst_n)begin 
   if(!sys_rst_n)begin
        bit_cnt <= 'd0;
    end 
    else if(bit_add)begin 
        if(bit_end)begin 
            bit_cnt <= 'd0;
        end
        else begin 
            bit_cnt <= bit_cnt + 1'b1;
        end 
    end
end 

//最后停止位只需计数到一半BAUD
assign bit_add = (baud_end || ((bit_cnt == 4'd9) && (baud_cnt == (BAUD >> 1))));
assign bit_end = bit_add && bit_cnt == 4'd10 - 1'b1;//起始位1 + 数据位8 + 停止位1

always @(posedge sys_clk or negedge sys_rst_n)begin 
   if(!sys_rst_n)begin
        baud_cnt <= 'd0;
    end 
    else if(baud_add)begin 
        if(baud_end)begin 
            baud_cnt <= 'd0;
        end
        else begin 
            baud_cnt <= baud_cnt + 1'b1;
        end 
    end
    else begin
        baud_cnt <= 'd0;
    end 
end 

assign baud_add = rx_flag;
assign baud_end = baud_add && baud_cnt == BAUD - 1'b1;

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        rx_flag <= 'd0;
    end 
    else if(uart_rx_start)begin 
        rx_flag <=1'b1;
    end 
    else if(bit_end)begin
        rx_flag <= 1'b0;
    end 
    else begin 
        rx_flag <= rx_flag;
    end 
end

//串行数据转并行
    reg  [09:00]    rx_data;
always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        rx_data <= 'd0;
    end 
    else if(rx_flag)begin 
        rx_data[bit_cnt] <= (baud_cnt == (BAUD >> 1))?uart_rx:rx_data[bit_cnt];
    end 
    else begin 
        rx_data <= rx_data;
    end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        uart_rx_data_vld <= 'd0;
    end 
    else begin 
        uart_rx_data_vld <= bit_end;
    end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        uart_rx_data <= 'd0;
    end 
    else if(bit_end)begin 
        uart_rx_data <= rx_data[08:01];
    end 
    else begin 
        uart_rx_data <= uart_rx_data;
    end 
end

endmodule
