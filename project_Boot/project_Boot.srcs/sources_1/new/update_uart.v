`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/08 10:11:31
// Design Name: 
// Module Name: update_uart
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


module update_uart(
    input               sys_clk             ,
    input               sys_rst_n           ,
    //Uart
    input               uart_rx             ,
    output              uart_tx             ,
    output  reg         en_485              ,

    output              icap_en             ,
    //flash_ctrl
    output              erase_req           ,//擦除请求
    input               erasing             ,//擦除中
    input               erase_completed     ,//擦除完成
    input               program_completed   ,//页写完成
    output      [31:00] total_byte          ,//文件总字节大小
    output      [15:00] total_seq           ,//总序列号 = total_byte/128  
    output      [15:00] current_seq         ,//当前数据帧序列号
    input               one_page_done       ,//一页写完
    //fifo
    output      [07:00] fifo_din            ,//FIFO写入数据
    output              fifo_write           //FIFO写使能  
    );

parameter BAUD = 434;//波率


wire        boot_req                    ;//直接回复
wire        upd_confirm                 ;//直接回复
wire        file_head_info              ;//直接回复，并且执行擦除操作
wire        rdy_status_query            ;//直接回复，根据擦除状态回复
wire        write_successed             ;
wire        write_faild                 ;
wire        crc_status_query            ;//直接回复
wire        icap_req                    ;//直接回复

wire        receive_done;
wire        send_done   ;

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        en_485 <= 'd0;
    end 
    else if(receive_done)begin 
        en_485 <= 'd1;
    end 
    else if(send_done)begin
        en_485 <= 'd0;
    end 
    else begin 
        en_485 <= en_485;
    end 
end

uart_receive
#(.BAUD(BAUD))
u_uart_receive(
.sys_clk             (sys_clk           ),
.sys_rst_n           (sys_rst_n         ),
//Uart
.uart_rx             (uart_rx           ),
.receive_done        (receive_done      ),
//Fifo
.fifo_din            (fifo_din          ),
.fifo_write          (fifo_write        ),
//flash_ctrl
.erase_req           (erase_req         ),//擦除请求
.icap_req            (icap_req          ),//boot跳转app请求

.total_byte          (total_byte        ),//文件总字节大小
.total_seq           (total_seq         ),//总序列号 = total_byte/128   
.current_seq         (current_seq       ),//当前数据帧序列号
//uart_send
//通信请求
.boot_req            (boot_req          ),
.upd_confirm         (upd_confirm       ),
.rdy_status_query    (rdy_status_query  ),
.crc_status_query    (crc_status_query  ),
.file_head_info      (file_head_info    ),

.firmware_version    (                  ),
.pack_nums           (                  ),
.bin_place           (                  ),
.filehead_size       (                  ),
.file_crc            (                  ),

.write_successed     (write_successed   ),//写入成功
.write_faild         (write_faild       ) //写入失败
);

uart_send
#(.BAUD(BAUD))
u_uart_send
(
.sys_clk             (sys_clk           ),
.sys_rst_n           (sys_rst_n         ),
//Uart
.uart_tx             (uart_tx           ),
.send_done           (send_done         ),

.boot_req            (boot_req          ),
.upd_confirm         (upd_confirm       ),
.file_head_info      (file_head_info    ),
.rdy_status_query    (rdy_status_query  ),

.crc_status_query    (crc_status_query  ),
.icap_req            (icap_req          ),
.icap_en             (icap_en           ),

.erasing             (erasing           ),
.erase_completed     (erase_completed   ),//擦除完成 E1
.program_completed   (program_completed ),//最后一帧写入Flash完毕 E4
.fpga_e2             ('d0           ),//E2
.write_successed     (write_successed   ),//写入成功E3
.write_faild         (write_faild       ),//写入失败E3
.current_seq         (current_seq       ),//当前数据帧序列号
//flash 
.one_page_done       (one_page_done     ) //写入成功E3

);



endmodule
