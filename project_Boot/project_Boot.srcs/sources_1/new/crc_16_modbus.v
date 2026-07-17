/**************************************功能介绍***********************************
Date     :				
Author   :			
Description:		CRC-16/MODBUS
多项式              x16 + x15 + x2 + 1
Change history:    
*********************************************************************************/
    
module crc_16_modbus( 
    input						    sys_clk		,
    input						    sys_rst_n	,
    input                           crc_en      ,//使能，计算CRC
    input           [07:00]         crc_data    ,
    input                           crc_clr     ,//清除，恢复初始值
    output          [15:00]         crc_value    //计算得到的CRC值           
);								 

parameter   WIDTH = 16          ;//宽度，即CRC比特数
parameter   INIT = 16'hFFFF     ;//这是算法开始时寄存器（crc）的初始化预置值，十六进制表示
parameter   XOROUT = 16'h0000   ;//计算结果与此参数异或后得到最终的CRC值。

//触发器
reg  [WIDTH - 1:00]    d        ;
reg                    feed_back;
integer                 i       ;

//输入反转
wire    [07:00]         refin   ;

//输出反转
wire    [15:00]         refout  ;

assign refin = {crc_data[0],crc_data[1],crc_data[2],crc_data[3],crc_data[4],
crc_data[5],crc_data[6],crc_data[7]};

assign refout = {d[0],d[1],d[2],d[3],d[4],d[5],d[6],d[7],d[8],d[9],d[10],d[11],d[12],d[13],d[14],d[15]};

assign crc_value = refout ^ XOROUT;

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        d = INIT;
    end 
    else if(crc_en)begin 
        for(i = 7; i >= 0; i = i - 1)begin
            feed_back = d[15] ^ refin[i];
            d[15] = d[14] ^ feed_back;
            d[14] = d[13];
            d[13] = d[12];
            d[12] = d[11];
            d[11] = d[10];
            d[10] = d[09];
            d[09] = d[08];
            d[08] = d[07];
            d[07] = d[06];
            d[06] = d[05];
            d[05] = d[04];
            d[04] = d[03];
            d[03] = d[02];
            d[02] = d[01] ^ feed_back;
            d[01] = d[00];
            d[00] = feed_back;
        end 
    end 
    else if(crc_clr)begin
        d = INIT;
    end 
    else begin 
        d = d;
    end 
end
    
endmodule