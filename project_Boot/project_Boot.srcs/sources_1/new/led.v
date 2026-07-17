`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/10 16:22:42
// Design Name: 
// Module Name: led
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


module led(
    input               sys_clk             ,
    input               sys_rst_n           ,

    //flash
    input               erasing             ,//擦除中
    input               programing          ,//编程中

    output reg          led1                ,
    output reg          led2                ,


    output reg          erase_led           ,
    output reg          program_led         
);

//parameter TIME_500MS = 25_000_000;//周期20ns
parameter TIME_500MS = 12_500_000;//周期40ns

reg  [25:00]    led_cnt;
wire            led_add;
wire            led_end;

always @(posedge sys_clk or negedge sys_rst_n)begin 
   if(!sys_rst_n)begin
        led_cnt <= 'd0;
    end 
    else if(led_add)begin 
        if(led_end)begin 
            led_cnt <= 'd0;
        end
        else begin 
            led_cnt <= led_cnt + 1'b1;
        end 
    end
end 

assign led_add = 1'b1;
assign led_end = led_add && led_cnt == TIME_500MS - 1'b1;


always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        erase_led <= 'd0;
    end 
    else if(erasing)begin 
        if(led_end)
            erase_led <= ~erase_led;
        else 
            erase_led <= erase_led;
    end 
    else begin 
        erase_led <= 'd0;
    end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        program_led <= 'd0;
    end 
    else if(programing)begin 
        if(led_end)
            program_led <= ~program_led;
        else 
            program_led <= program_led;
    end 
    else begin 
        program_led <= 'd0;
    end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        led1 <= 'd0;
        led2 <= 1'b1;
    end 
    else if(led_end)begin 
        led1 <= ~led1;
        led2 <= ~led2;
    end 
    else begin 
        led1 <= led1;
        led2 <= led2;
    end 
end

endmodule
