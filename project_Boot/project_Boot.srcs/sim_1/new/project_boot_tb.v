`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 1025/05/20 15:03:40
// Design Name: 
// Module Name: project_update_tb
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

`timescale 1ns/1ns
    
module project_boot_tb();

//激励信号定义 
    reg				sys_clk  	;
    reg				sys_rst_n	;

    reg  [07:0]     tx_data     ;
    reg             tx_en       ;
//时钟周期参数定义	
    parameter		CLOCK_CYCLE = 40;   

//模块例化
wire    sim_tx;

wire    tx_completed;
wire    tx_ing      ;

update_uart
#(.BAUD(25_000_000/115_200))
u_update_uart(
.sys_clk             (sys_clk           ),
.sys_rst_n           (sys_rst_n         ),
//Uart
.uart_rx             (sim_tx           ),
.uart_tx             (           ),
//flash_ctrl
.icap_en             (),
.erase_req           (erase_req         ),//擦除请求
.erasing             ('d0),
.erase_completed     (erase_completed   ),//擦除完成
.program_completed   (program_completed ),//页写完成
.total_byte          (total_byte        ),//文件总字节大小
.total_seq           (total_seq         ),//总序列号 = total_byte/128   
.current_seq         (current_seq       ),//当前数据帧序列号
.one_page_done       ('d0/*one_page_done*/     ),//一页写完
//fifo
.fifo_din            (fifo_din          ),//FIFO写入数据
.fifo_write          (fifo_write        ) //FIFO写使能  
);

uart_tx
#(.BAUD(25_000_000/115_200))
uart_tx_sim(
.sys_clk    (sys_clk        ),
.sys_rst_n  (sys_rst_n      ),
    //Uart
.uart_tx    (sim_tx         ),
.tx_data    (tx_data        ),//一字节待发送数据
.tx_en      (tx_en          ),//一字节发送使能
.tx_completed (tx_completed ),//一字节发送完成 
.tx_ing       (tx_ing       ) //处于发送中
    );


//产生时钟
    initial 		sys_clk = 1'b0;
    always #(CLOCK_CYCLE/2) sys_clk = ~sys_clk;
integer i;
//产生激励
    initial  begin 
        sys_rst_n = 1'b1;
        #(CLOCK_CYCLE*2);
        sys_rst_n = 1'b0;
        tx_data   = 'd0 ;
        tx_en     = 'd0 ;
        i = 127;
        #(CLOCK_CYCLE*20);
        sys_rst_n = 1'b1;
        #(CLOCK_CYCLE*2000);

        // //Boot运行指令
        // tx_task(8'h82);
        // tx_task(8'h66);
        // tx_task(8'h01);
        // tx_task(8'h00);
        // //CRC校验
        // tx_task(8'hC9);
        // tx_task(8'hD3);

        // wait(u_update_uart.u_uart_send.crc2idle);
        // #(CLOCK_CYCLE*2000);

        //确认更新固件指令
        tx_task(8'h82);
        tx_task(8'h66);
        tx_task(8'h02);
        tx_task(8'h00);
        //CRC校验
        tx_task(8'hC9);
        tx_task(8'h23);

        wait(u_update_uart.u_uart_send.crc2idle);
        #(CLOCK_CYCLE*1000);

        //更新固件头信息指令
        tx_task(8'h82);
        tx_task(8'h66);
        tx_task(8'h03);
        tx_task(8'h20);
        //更新固件版本号
        tx_task(8'h62);
        tx_task(8'h5C);
        tx_task(8'h05);
        tx_task(8'h00);
        //固件大小
        tx_task(8'hA8);
        tx_task(8'h48);
        tx_task(8'h18);
        tx_task(8'h00);
        //分包数
        tx_task(8'h92);
        tx_task(8'h30);
        //单包字节数128
        tx_task(8'h80);
        tx_task(8'h00);
        //更新存储位置
        tx_task(8'h00);
        tx_task(8'h00);
        tx_task(8'h00);
        tx_task(8'h00);
        //文件头大小
        tx_task(8'h20);
        tx_task(8'h00);
        //文件内容CRC校验
        tx_task(8'h5A);
        tx_task(8'h4A);
        //保留字段
        tx_task(8'h00);
        tx_task(8'h00);
        tx_task(8'h00);
        tx_task(8'h00);
        tx_task(8'h00);
        tx_task(8'h00);
        tx_task(8'h00);
        tx_task(8'h00);
        tx_task(8'h00);
        tx_task(8'h00);
        tx_task(8'h00);
        tx_task(8'h00);
        //CRC
        tx_task(8'hA8);
        tx_task(8'hD1);
        wait(u_update_uart.u_uart_send.crc2idle);
        #(CLOCK_CYCLE*1000);

        // //更新文件准备状态查询指令
        // tx_task(8'h82);
        // tx_task(8'h66);
        // tx_task(8'h85);
        // tx_task(8'h00);
        // //CRC校验
        // tx_task(8'hAA);
        // tx_task(8'hD3);
        // wait(u_update_uart.u_uart_send.crc2idle);
        // #(CLOCK_CYCLE*1000);  

        //分包更新固件内容指令
        tx_task(8'h82);
        tx_task(8'h66);
        tx_task(8'h04);
        tx_task(8'h2A);
        //分包编号
        tx_task(8'h91);
        tx_task(8'h30);
        //分包内容
        repeat(128)begin
            tx_task(i);
            i = i-1;
        end 
        tx_task(8'hB6);
        tx_task(8'h7B);
        
        wait(u_update_uart.u_uart_send.crc2idle);
        #(CLOCK_CYCLE*1000);  

         i = 127;
        //重复偶序列帧
        //分包更新固件内容指令
        tx_task(8'h82);
        tx_task(8'h66);
        tx_task(8'h04);
        tx_task(8'h82);
        //分包编号
        tx_task(8'h00);
        tx_task(8'h00);
        //分包内容
        repeat(128)begin
            tx_task(i);
            i = i-1;
        end 
        tx_task(8'hB6);
        tx_task(8'h7B);
        
   
        wait(u_update_uart.u_uart_send.crc2idle);
        #(CLOCK_CYCLE*1000);  

         i = 127;
        //重复偶序列帧
        //分包更新固件内容指令
        tx_task(8'h82);
        tx_task(8'h66);
        tx_task(8'h04);
        tx_task(8'h82);
        //分包编号
        tx_task(8'h02);
        tx_task(8'h00);
        //分包内容
        repeat(128)begin
            tx_task(i);
            i = i-1;
        end 
        tx_task(8'hB7);
        tx_task(8'hC9);
        
   
        wait(u_update_uart.u_uart_send.crc2idle);
        #(CLOCK_CYCLE*1000);  


         i = 127;
        //重复偶序列帧
        //分包更新固件内容指令
        tx_task(8'h82);
        tx_task(8'h66);
        tx_task(8'h04);
        tx_task(8'h82);
        //分包编号
        tx_task(8'h00);
        tx_task(8'h00);
        //分包内容
        repeat(128)begin
            tx_task(i);
            i = i-1;
        end 
        tx_task(8'hB6);
        tx_task(8'h7B);
        
   
        wait(u_update_uart.u_uart_send.crc2idle);
        #(CLOCK_CYCLE*1000);  
        // i = 127;
        // //分包更新固件内容指令
        // tx_task(8'h82);
        // tx_task(8'h66);
        // tx_task(8'h04);
        // tx_task(8'h82);
        // //分包编号
        // tx_task(8'h01);
        // tx_task(8'h00);
        // //分包内容
        // repeat(128)begin
        //     tx_task(i);
        //     i = i-1;
        // end 
        // tx_task(8'hB7);
        // tx_task(8'h82);

        // i = 127;
        // //分包更新固件内容指令
        // tx_task(8'h82);
        // tx_task(8'h66);
        // tx_task(8'h04);
        // tx_task(8'h82);
        // //分包编号
        // tx_task(8'h01);
        // tx_task(8'h00);
        // //分包内容
        // repeat(128)begin
        //     tx_task(i);
        //     i = i-1;
        // end 
        // tx_task(8'hB7);
        // tx_task(8'h82);
   
        // wait(u_update_uart.u_uart_send.crc2idle);
        // #(CLOCK_CYCLE*1000); 

        
        //检验校验状态指令
        tx_task(8'h82);
        tx_task(8'h66);
        tx_task(8'h86);
        tx_task(8'h00);
        //CRC校验
        tx_task(8'hAA);
        tx_task(8'h23);
        wait(u_update_uart.u_uart_send.crc2idle);
        #(CLOCK_CYCLE*1000);  


        //APP
        tx_task(8'h82);
        tx_task(8'h66);
        tx_task(8'h05);
        tx_task(8'h00);
        //CRC校验
        tx_task(8'hCB);
        tx_task(8'h13);
        #(CLOCK_CYCLE*1000);  
        wait(u_update_uart.u_uart_send.crc2idle);
    end

    task tx_task(
        input [07:00]   tx_data_in
    );
    begin
        tx_data = tx_data_in;
        tx_en   = 1'b1  ;
        #(CLOCK_CYCLE);
        tx_en = 1'b0;
        tx_data = 'd0;
        wait(tx_completed);
        #(CLOCK_CYCLE);
    end 
    endtask
endmodule 

