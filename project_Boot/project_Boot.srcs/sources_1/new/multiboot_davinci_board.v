`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/07 14:53:39
// Design Name: 
// Module Name: multiboot_davinci_board
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


module VHF_BOOT_V1(
    input               sys_clk     ,
//    input               sys_rst_n   ,
    //模拟仿真接口,后续删除
//    output              flash_sclk  ,

    /****************************************************************/
    //Uart
    input               uart_rx     ,
    output              uart_tx     ,
    output              test_rx     ,
    output              test_tx     ,
    output              en_485      ,//485使能
//    output              uart_tx_r1  ,
    //Flash SPI
    input               flash_miso  ,
    output              flash_mosi  ,
    output              flash_cs_n  ,
    //LED
//    output              led1        ,
//    output              led2        ,
    output              erase_led   ,
    output              program_led         
    );

reg [23:00] clk_cnt = 8'd0;

always@(posedge sys_clk)begin
  if(clk_cnt == 24'd2_499/*_999*/)
    clk_cnt <= clk_cnt ;
  else
    clk_cnt <= clk_cnt + 1'b1 ;
end

reg sys_rst_n = 1'b0 ;
always@(posedge sys_clk)begin
  if(clk_cnt == 24'd2_499/*_999*/)
    sys_rst_n <= 1'b1 ;
  else
    sys_rst_n <= 1'b0 ;
end

assign test_rx = uart_rx;
assign test_tx = uart_tx;
//用户接口
//flash_ctrl与update_uart模块交互
wire            erase_req           ;
wire            erase_completed     ;
wire            program_completed   ;
wire    [31:00] total_byte          ;
wire    [15:00] total_seq           ;
wire    [15:00] current_seq         ;
//flash_ctrl与fifo_512x8交互
wire    [09:00] data_count          ;
wire    [07:00] read_fifo_data      ;
wire            read_fifo           ;
wire            fifo_empty          ;
//fifo_512x8与ram_256x8交互
wire    [07:00] fifo_din            ;
wire            fifo_write          ;     
wire            one_page_done       ;

//flash_ctrl与icap_ctrl交互
wire            erasing             ;
wire            programing          ;

wire            icap_en             ;

update_uart
#(.BAUD(25_000_000/230_400))
u_update_uart(
.sys_clk             (sys_clk           ),
.sys_rst_n           (sys_rst_n         ),
//Uart
.uart_rx             (uart_rx           ),
.uart_tx             (uart_tx           ),
.en_485              (en_485            ),
.icap_en             (icap_en           ),
//flash_ctrl
.erase_req           (erase_req         ),//擦除请求
.erasing             (erasing           ),//擦除中
.erase_completed     (erase_completed   ),//擦除完成
.program_completed   (program_completed ),//页写完成
.total_byte          (total_byte        ),//文件总字节大小
.total_seq           (total_seq         ),//总序列号 = total_byte/128   
.current_seq         (current_seq       ),//当前数据帧序列号
.one_page_done       (one_page_done     ),//一页写完
//fifo
.fifo_din            (fifo_din          ),//FIFO写入数据
.fifo_write          (fifo_write        ) //FIFO写使能  
);


flash_ctrl
u_flash_ctrl(
.sys_clk             (sys_clk           ),
.sys_rst_n           (sys_rst_n         ),

//Flash操作
.erase_req           (erase_req         ),//擦除请求
    // input               program_req         ,//页写请求
.erase_completed     (erase_completed   ),//擦除完成
.program_completed   (program_completed ),//页写完成
.one_page_done       (one_page_done     ),//一页写完
.erasing             (erasing           ),//擦除中
.programing          (programing        ),//编程中
//File Info
.total_byte          (total_byte        ),//文件总字节大小
// .total_seq           (total_seq         ),//总序列号 = total_byte/128   
.current_seq         (current_seq       ),//当前数据帧序列号
//FIFO
.data_count          (data_count        ),//FIFO内数据深度计数
.read_fifo_data      (read_fifo_data    ),//从FIFO中读取需要写入Flash中的数据
.read_fifo           (read_fifo         ),//读取FIFO请求
.fifo_empty          (fifo_empty        ),//FIFO空
//SPI接口
.flash_miso          (flash_miso        ),
.flash_mosi          (flash_mosi        ),
.flash_cs_n          (flash_cs_n        ),
.flash_clk           (flash_sclk        )   
    );

fifo_512x8 
u_fifo_512x8(
  .clk              (sys_clk        ),                  // input wire clk
  .rst              (~sys_rst_n     ),                  // input wire rst
  .din              (fifo_din       ),                  // input wire [7 : 0] din
  .wr_en            (fifo_write     ),              // input wire wr_en
  .rd_en            (read_fifo      ),              // input wire rd_en
  .dout             (read_fifo_data ),                // output wire [7 : 0] dout
  .full             (               ),                // output wire full
  .empty            (fifo_empty     ),              // output wire empty
  .data_count       (data_count     )    // output wire [8 : 0] data_count
);

   STARTUPE2 #(
      .PROG_USR("FALSE"),  // Activate program event security feature. Requires encrypted bitstreams.
      .SIM_CCLK_FREQ(0.0)  // Set the Configuration Clock Frequency(ns) for simulation.
   )
   STARTUPE2_inst (
      .CFGCLK(),       // 1-bit output: Configuration main clock output
      .CFGMCLK(),     // 1-bit output: Configuration internal oscillator clock output
      .EOS(   ),             // 1-bit output: Active high output signal indicating the End Of Startup.
      .PREQ(),           // 1-bit output: PROGRAM request to fabric output
      .CLK(0),             // 1-bit input: User start-up clock input
      .GSR(0),             // 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
      .GTS(0),             // 1-bit input: Global 3-state input (GTS cannot be used for the port name)
      .KEYCLEARB(1), // 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
      .PACK(1),           // 1-bit input: PROGRAM acknowledge input
      .USRCCLKO(flash_sclk),   // 1-bit input: User CCLK input
                             // For Zynq-7000 devices, this input must be tied to GND
      .USRCCLKTS(0), // 1-bit input: User CCLK 3-state enable input
                             // For Zynq-7000 devices, this input must be tied to VCC
      .USRDONEO(1),   // 1-bit input: User DONE pin output control
      .USRDONETS(1)  // 1-bit input: User DONE 3-state enable output
   );

   // End of STARTUPE2_inst instantiation

icap_ctrl
u_icap_ctrl(
.sys_clk             (sys_clk   ),
.sys_rst_n           (sys_rst_n ),
    //flash
.icap_en             (icap_en   ),
.erasing             (erasing   ),//擦除中
.programing          (programing),//编程中
.uart_rx             (uart_rx   )
    );

led
u_led(
.sys_clk             (sys_clk    ),
.sys_rst_n           (sys_rst_n  ),

.erasing             (erasing   ),//擦除中
.programing          (programing),//编程中

//.led1                (led1       ),
//.led2                (led2       ),
.erase_led           (erase_led  ),
.program_led         (program_led)
);

//assign uart_tx_r1 = uart_tx;

endmodule
