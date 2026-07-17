`timescale 1ns/1ns
    
module always_send_tb();

//激励信号定义 
    reg				sys_clk  	;
    reg				sys_rst_n	;


//时钟周期参数定义	
    parameter		CLOCK_CYCLE = 40;   

//模块例化
VHF_BOOT_V1
u_VHF_BOOT_V1(
.sys_clk     (sys_clk       ),
//    input               sys_rst_n   ,
    //模拟仿真接口,后续删除
//    output              flash_sclk  ,

    /****************************************************************/
    //Uart
.uart_rx     (),
.uart_tx     (),
.test_rx     (),
.test_tx     (),
.en_485      (),//485使能
//    output              uart_tx_r1  ,
    //Flash SPI
.flash_miso  (),
.flash_mosi  (),
.flash_cs_n  (),
    //LED
//    output              led1        ,
//    output              led2        ,
.erase_led   (),
.program_led ()        
    );

//产生时钟
    initial 		sys_clk = 1'b0;
    always #(CLOCK_CYCLE/2) sys_clk = ~sys_clk;

//产生激励
    initial  begin 
        sys_rst_n = 1'b1;
        #(CLOCK_CYCLE*2);
        sys_rst_n = 1'b0;
        #(CLOCK_CYCLE*20);
        sys_rst_n = 1'b1;



    end

endmodule 