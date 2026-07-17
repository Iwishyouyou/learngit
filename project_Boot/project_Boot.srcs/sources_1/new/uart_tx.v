`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/08 14:04:46
// Design Name: 
// Module Name: uart_tx
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


module uart_tx(
    input               sys_clk             ,
    input               sys_rst_n           ,
    //Uart
    output  reg         uart_tx             ,
    input       [07:00] tx_data             ,//一字节待发送数据
    input               tx_en               ,//一字节发送使能
    output              tx_completed        ,//一字节发送完成 
    output  reg         tx_ing               //处于发送中
    );

parameter BAUD = 50_000_000/115_200;

reg  [09:00]    tx_data_r;//拼接起始位和停止位

//bit计数器
reg  [03:00]    bit_cnt             ;
wire            bit_add             ;
wire            bit_end             ;

//BAUD计数器
reg  [$clog2(BAUD) - 1:00]  baud_cnt;
wire            baud_add            ;
wire            baud_end            ;

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        tx_data_r <= 'd0;
    end 
    else if(tx_en)begin 
        tx_data_r <= {1'b1,tx_data,1'b0};
    end 
    else begin 
        tx_data_r <= tx_data_r;
    end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        tx_ing <= 'd0;
    end 
    else if(tx_en)begin 
        tx_ing <= 1'b1;
    end 
    else if(bit_end)begin
        tx_ing <= 1'b0;
    end 
    else begin 
        tx_ing <= tx_ing;
    end 
end

assign tx_completed = bit_end;

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

assign bit_add = baud_end;
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

assign baud_add = tx_ing;
assign baud_end = baud_add && baud_cnt == BAUD - 1'b1;


always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin//初始、空闲状态为高
        uart_tx <= 1'b1;
    end 
    else if(tx_ing)begin 
        uart_tx <= tx_data_r[bit_cnt];
    end 
    else begin 
        uart_tx <= 1'b1;
    end 
end
endmodule
