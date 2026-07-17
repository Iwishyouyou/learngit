`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/07 09:12:19
// Design Name: 
// Module Name: flash_ctrl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//              适用Flash   N25Q128   S25FL256
//              擦除范围    0x00_40_00_00——0x00_7F_00_00,共计4MB空间
//              编程范围    由total_byte决定,共 (total_byte/256)+1 页
//              适配指令    
//              读状态寄存器    RDSR 0x05
//              写使能         WREN 0x06
//              扇区擦除       SSE 0x20(仿真用,只能擦除部分部分扇区) SE 0xD8(实际使用)
//              页写           PP 0x02 
//
//
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module flash_ctrl(
    input               sys_clk             ,
    input               sys_rst_n           ,

//Flash操作
    input               erase_req           ,//擦除请求
    // input               program_req         ,//页写请求
    output  reg         erase_completed     ,//擦除完成
    output  reg         program_completed   ,//页写完成
    output  reg         one_page_done       ,//一页写完
    output              erasing             ,//擦除中
    output              programing          ,//编程中
//File Info
    input       [31:00] total_byte          ,//文件总字节大小
    // input       [15:00] total_seq           ,//总序列号 = total_byte/128   
    input       [15:00] current_seq         ,//当前数据帧序列号
//FIFO
    input       [09:00] data_count          ,//FIFO内数据深度计数
    input       [07:00] read_fifo_data      ,//从FIFO中读取需要写入Flash中的数据
    output  reg         read_fifo           ,//读取FIFO请求
    input               fifo_empty          ,//FIFO空
//SPI接口
    input               flash_miso          ,
    output              flash_mosi          ,
    output              flash_cs_n          ,
    output              flash_clk 
    );


//Flash Instructions
parameter RDSR = 8'h05          ;
parameter WREN = 8'h06          ;
//parameter SSE  = 8'h20          ;//仿真用
parameter SE   = 8'hD8          ;//实际用
parameter PP   = 8'h02          ;

//Flash
parameter SECTOR_SIZE   = 8'h40 ;//擦除扇区大小
// parameter SECTOR_SIZE   = 8'h03 ;//模拟仿真


//状态机参数
parameter IDLE          = 8'h01 ;
parameter WRITE_ENABLE  = 8'h02 ;
parameter WEL_CHECK     = 8'h04 ;
parameter ERASE         = 8'h08 ;
parameter PROGRAM       = 8'h10 ;
parameter WIP_CHECK     = 8'h20 ;
parameter WIP_WAIT      = 8'h40 ;
parameter STOP          = 8'h80 ;

//定时参数
//parameter TIME_1MS      = 50_000;//周期20ns
parameter TIME_1MS      = 25_000;//周期40ns
// parameter TIME_1MS      = 1000;//周期20ns

//变量声明
reg  [07:00]    state_c         ;
reg  [07:00]    state_n         ;

//状态机跳转条件
wire idle2write_enable          ;
wire write_enable2wel_check     ;
wire wel_check2erase            ;
wire wel_check2program          ;
wire wel_check2write_enable     ;
wire erase2wip_check            ;
wire wip_check2wip_wait         ;
wire program2wip_check          ;
wire wip_wait2stop              ;
wire wip_wait2write_enable      ;
wire wip_wait2wip_check         ;
wire stop2idle                  ;

//standard spi模块接口
reg  [03:00]    spi_cmd         ;
reg  [07:00]    writedata       ;
//in
wire [07:00]    readdata        ;
wire            read_vld        ;
wire            cmd_update      ;
wire            spi_trans_done  ;

//擦除标志
reg             erase_flag      ;
//编程标志
reg             program_flag    ;
//WEL位
reg             wel             ;
//WIP位
reg             wip             ;
//等待Flash进程计数器 1ms
reg  [15:00]    wip_wait_cnt    ;
wire            wip_wait_add    ;
wire            wip_wait_end    ;
//擦除扇区计数器
reg  [07:00]    erase_cnt       ;
wire            erase_add       ;
wire            erase_end       ;
//编程页计数器
reg  [15:00]    program_cnt     ;
wire            program_add     ;
wire            program_end     ;
reg  [15:00]    PROGRAM_MAX     ;
//SPI传输字节计数器
reg  [09:00]    byte_cnt        ;
wire            byte_add        ;
wire            byte_end        ;
reg  [09:00]    byte_max        ;


//ila_0 ila_0_sys (
//	.clk(sys_clk), // input wire clk


//	.probe0(erase_req), // input wire [0:0]  probe0  
//	.probe1(erase_completed  ), // input wire [0:0]  probe1 
//	.probe2(program_completed), // input wire [0:0]  probe2 
//	.probe3(one_page_done    ), // input wire [0:0]  probe3 
//	.probe4(erasing          ), // input wire [0:0]  probe4 
//	.probe5(programing       ), // input wire [0:0]  probe5 
//	.probe6(total_byte), // input wire [31:0]  probe6 
//	.probe7(current_seq), // input wire [15:0]  probe7 
//	.probe8(data_count    ), // input wire [9:0]  probe8 
//	.probe9(read_fifo_data), // input wire [7:0]  probe9 
//	.probe10(read_fifo ), // input wire [0:0]  probe10 
//	.probe11(fifo_empty), // input wire [0:0]  probe11 
//	.probe12(state_c), // input wire [7:0]  probe12 
//	.probe13(state_n), // input wire [7:0]  probe13 
//	.probe14(spi_cmd  ), // input wire [3:0]  probe14 
//	.probe15(writedata), // input wire [7:0]  probe15 
//	.probe16(readdata      ), // input wire [7:0]  probe16 
//	.probe17(read_vld      ), // input wire [0:0]  probe17 
//	.probe18(cmd_update    ), // input wire [0:0]  probe18 
//	.probe19(spi_trans_done), // input wire [0:0]  probe19 
//	.probe20(erase_flag), // input wire [0:0]  probe20 
//	.probe21(program_flag), // input wire [0:0]  probe21 
//	.probe22(wel), // input wire [0:0]  probe22 
//	.probe23(wip), // input wire [0:0]  probe23 
//	.probe24(wip_wait_cnt), // input wire [15:0]  probe24 
//	.probe25(wip_wait_add), // input wire [0:0]  probe25 
//	.probe26(wip_wait_end), // input wire [0:0]  probe26 
//	.probe27(erase_cnt), // input wire [7:0]  probe27 
//	.probe28(erase_add), // input wire [0:0]  probe28 
//	.probe29(erase_end), // input wire [0:0]  probe29 
//	.probe30(program_cnt), // input wire [15:0]  probe30 
//	.probe31(program_add), // input wire [0:0]  probe31 
//	.probe32(program_end), // input wire [0:0]  probe32 
//	.probe33(PROGRAM_MAX), // input wire [15:0]  probe33 
//	.probe34(byte_cnt), // input wire [9:0]  probe34 
//	.probe35(byte_add), // input wire [0:0]  probe35 
//	.probe36(byte_end), // input wire [0:0]  probe36 
//	.probe37(byte_max) // input wire [9:0]  probe37
//);

//-----------赋值段-----------
always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        erase_flag <= 'd0;
    end 
    else if(erase_req && idle2write_enable)begin//收到擦除请求置为擦除标志
        erase_flag <= 1'b1;
    end 
    else if(erase_flag && stop2idle)begin//指定扇区擦除完成
        erase_flag <= 1'b0;
    end 
    else begin 
        erase_flag <= erase_flag;
    end 
end

assign erasing = erase_flag;

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        program_flag <= 'd0;
    end 
    else if(idle2write_enable && (data_count >= 9'd256))begin//开始页写进程置为页写标志
        program_flag <= 1'b1;
    end 
    else if(program_flag && stop2idle)begin
        program_flag <= 1'b0;
    end 
    else begin 
        program_flag <= program_flag;
    end 
end

assign programing = program_flag;

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        wel <= 'd0;
    end 
    else if((state_c == WEL_CHECK) && read_vld)begin 
        wel <= readdata[1];
    end 
    else if(wel_check2erase || wel_check2program)begin
        wel <= 'd0;
    end 
    else begin 
        wel <= wel;
    end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        wip <= 1'b1;
    end 
    else if((state_c == WIP_CHECK) && read_vld)begin 
        wip <= readdata[0];
    end 
    else if(wip_wait2stop || wip_wait2write_enable)begin
        wip <= 1'b1;
    end 
    else begin 
        wip <= wip;
    end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
   if(!sys_rst_n)begin
        wip_wait_cnt <= 'd0;
    end 
    else if(state_c != WIP_WAIT)begin
        wip_wait_cnt <= 'd0;
    end 
    else if(wip_wait_add)begin 
        if(wip_wait_end)begin 
            wip_wait_cnt <= 'd0;
        end
        else begin 
            wip_wait_cnt <= wip_wait_cnt + 1'b1;
        end 
    end
end 

assign wip_wait_add = (state_c == WIP_WAIT);
assign wip_wait_end = wip_wait_add && wip_wait_cnt == TIME_1MS - 1'b1;

always @(posedge sys_clk or negedge sys_rst_n)begin 
   if(!sys_rst_n)begin
        erase_cnt <= 'd0;
    end 
    else if(erase_add)begin 
        if(erase_end)begin 
            erase_cnt <= 'd0;
        end
        else begin 
            erase_cnt <= erase_cnt + 1'b1;
        end 
    end
end 

assign erase_add = erase_flag && (wip_wait2stop || wip_wait2write_enable);
assign erase_end = erase_add && erase_cnt == SECTOR_SIZE - 1'b1;

always @(posedge sys_clk or negedge sys_rst_n)begin 
   if(!sys_rst_n)begin
        program_cnt <= 'd0;
    end 
    else if(program_add)begin 
        if(program_end)begin 
            program_cnt <= 'd0;
        end
        else begin 
            program_cnt <= program_cnt + 1'b1;
        end 
    end
end 

assign program_add = program_flag && (wip_wait2stop || wip_wait2write_enable);
assign program_end = program_add && program_cnt == PROGRAM_MAX - 1'b1;

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        PROGRAM_MAX <= 16'd16384;
    end 
    else if(idle2write_enable && (data_count >= 9'd256))begin//若total正好是8的整数倍,那么多写一页的FF。如不是,剩余空间填充FF。
        PROGRAM_MAX <= (total_byte >> 8) + 1;
    end 
    else begin 
        PROGRAM_MAX <= PROGRAM_MAX;
    end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        erase_completed <= 'd0;
    end 
    else if(erase_flag && stop2idle)begin 
        erase_completed <= 1'b1;
    end 
    else begin 
        erase_completed <= 'd0;  
    end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        program_completed <= 'd0;
    end 
    else if(program_flag && stop2idle)begin 
        program_completed <= 1'b1;
    end 
    else begin 
        program_completed <= 'd0;
    end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        spi_cmd <= {4{1'b0}};
        writedata <= {8{1'b0}};
    end 
    else if(state_c == WRITE_ENABLE)begin 
        if(byte_cnt == 1'd0)begin
            //写使能
            spi_cmd <= 4'h8; 
            writedata <= WREN;
        end 
        else begin
            //SPI结束释放
            spi_cmd <= 4'h1;
            writedata <= 8'h00;
        end 
    end 
    else if((state_c == WEL_CHECK) || (state_c == WIP_CHECK))begin
        if(byte_cnt == 1'd0)begin
            //读状态寄存器
            spi_cmd <= 4'h8; 
            writedata <= RDSR;
        end 
        else if(byte_cnt == 1'd1)begin
            //读数据
            spi_cmd <= 4'h2;
            writedata <= 8'h00;
        end 
        else begin
            //SPI结束释放
            spi_cmd <= 4'h1;
            writedata <= 8'h00;
        end 
    end 
    else if(state_c == ERASE)begin
        case(byte_cnt)
            1'd0:begin
                //擦除指令
                spi_cmd <= 4'h8;
                //  writedata <= SSE;//仿真用
               writedata <= SE;//实际用
            end     
            1'd1:begin
                //扇区地址
                spi_cmd <= 4'h4;
                writedata <= 8'h40 + erase_cnt;//8'h40:扇区地址偏移
            end 
            3'd4:begin
                //SPI结束释放
                spi_cmd <= 4'h1;
                writedata <= 8'h00;  
            end 
            default:begin
                //其余地址字节
                spi_cmd <= 4'h4;
                writedata <= 8'h00;
            end 
        endcase 
    end 
    else if(state_c == PROGRAM)begin
        case(byte_cnt)  
            1'd0:begin  
                //页编程指令
                spi_cmd <= 4'h8;
                writedata <= PP;
            end 
            1'd1:begin
                //扇区地址
                spi_cmd <= 4'h4;
                writedata <= 8'h40 + program_cnt[15:08];//8'h40:扇区地址偏移
            end 
            2'd2:begin
                //页地址
                spi_cmd <= 4'h4;
                writedata <= program_cnt[07:00];
            end 
            2'd3:begin
                //每页起始地址
                spi_cmd <= 4'h4;
                writedata <= 8'h00;
            end 
            9'd260:begin
                //SPI结束释放
                spi_cmd <= 4'h1;
                writedata <= 8'h00; 
            end 
            default:begin
                //写入数据字节
                spi_cmd <= 4'h4;
                writedata <= fifo_empty?8'hFF:read_fifo_data;
            end 
        endcase 
    end 
    else begin 
        spi_cmd <= {4{1'b0}};
        writedata <= {8{1'b0}};
    end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        read_fifo <= 'd0;
    end 
    else if(state_c == PROGRAM)begin 
        if((byte_cnt > 2'd3) && (fifo_empty == 1'b0))
            read_fifo <= cmd_update;
        else 
            read_fifo <= 'd0;
    end 
    else begin 
        read_fifo <= 'd0;
    end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        byte_max <= 2'd1;
    end 
    else if(state_n == WRITE_ENABLE)begin 
        byte_max <= 2'd1;//指令1字节
    end 
    else if((state_n == WEL_CHECK) || (state_n == WIP_CHECK))begin
        byte_max <= 2'd2;//指令1字节 + 读取1字节
    end 
    else if(state_n == ERASE)begin
        byte_max <= 3'd4;//指令1字节 + 地址3字节
    end 
    else if(state_n == PROGRAM)begin
        byte_max <= 9'd260;//指令1字节 + 地址3字节 + 256数据字节
    end 
    else begin 
        byte_max <= 2'd1;
    end 
end

//传输字节计数器
always @(posedge sys_clk or negedge sys_rst_n)begin 
   if(!sys_rst_n)begin
        byte_cnt <= 'd0;
    end 
    else if(byte_add)begin 
        if(byte_end)begin 
            byte_cnt <= 'd0;
        end
        else begin 
            byte_cnt <= byte_cnt + 1'b1;
        end 
    end
end 

assign byte_add = cmd_update || spi_trans_done;
assign byte_end = byte_add && byte_cnt == byte_max;//SPI结束算一字节

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        one_page_done <= 'd0;
    end 
    else if(wip_wait2write_enable && program_flag && ((program_cnt != (PROGRAM_MAX - 1'b1))))begin 
        one_page_done <= 1'b1;
    end 
    else begin 
        one_page_done <= 'd0;
    end 
end
//收到擦除请求或是FIFO中数据量达到256个(满足一页的容量),需要发送写使能指令
assign idle2write_enable      = (state_c == IDLE) && (erase_req || (data_count >= 9'd256));
//写使能指令发送完成,需要查询WEL位
assign write_enable2wel_check = (state_c == WRITE_ENABLE) && spi_trans_done;
//WEL查询完成,write enable latch位置1,Flash操作为擦除
assign wel_check2erase        = (state_c == WEL_CHECK) && erase_flag && (wel == 1'b1) && spi_trans_done;
//WEL查询完成,write enable latch位置1,Flash操作为编程,且数据量有256个或当前为最后一页且最后一页的数据传完
assign wel_check2program      = (state_c == WEL_CHECK) && program_flag && (wel == 1'b1) && spi_trans_done && ((data_count >= 9'd256) || ((program_cnt == PROGRAM_MAX - 1'b1) && (data_count == (total_byte % 256))));
//WEL查询完成,write enable latch位为0,重写WREN
assign wel_check2write_enable = (state_c == WEL_CHECK) && (wel == 1'b0) && spi_trans_done;
//擦除指令发送完成,需要查询WIP位
assign erase2wip_check        = (state_c == ERASE ) && spi_trans_done;
assign wip_check2wip_wait     = (state_c == WIP_CHECK) && spi_trans_done;
//编程指令完成,需要查询WIP位
assign program2wip_check      = (state_c == PROGRAM) && spi_trans_done;
//等待时间结束(1ms) 无操作处于进程中 所有指定扇区擦除完成或规定大小数据字节全部编程完成
assign wip_wait2stop          = (state_c == WIP_WAIT) && wip_wait_end && (wip == 1'b0) && ((erase_cnt == SECTOR_SIZE - 1'b1) || (program_cnt == PROGRAM_MAX - 1'b1));
//优先级比wip_wait2stop低
assign wip_wait2write_enable  = (state_c == WIP_WAIT) && wip_wait_end && (wip == 1'b0);
assign wip_wait2wip_check     = (state_c == WIP_WAIT) && wip_wait_end && (wip == 1'b1);
assign stop2idle              = (state_c == STOP) && 1'b1; 

//状态机
always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        state_c <= IDLE;//初始状态一般为IDLE
    end 
    else begin 
        state_c <= state_n;
    end 
end

always @(*) begin
    case(state_c)
        IDLE        :begin
            if(idle2write_enable)
                state_n = WRITE_ENABLE;
            else 
                state_n = state_c;
        end 
        WRITE_ENABLE:begin
            if(write_enable2wel_check)
                state_n = WEL_CHECK;
            else 
                state_n = state_c;
        end 
        WEL_CHECK   :begin
            if(wel_check2write_enable)
                state_n = WRITE_ENABLE;
            else if(wel_check2erase)
                state_n = ERASE;
            else if(wel_check2program)
                state_n = PROGRAM;
            else 
                state_n = state_c;
        end 
        ERASE       :begin
            if(erase2wip_check)
                state_n = WIP_CHECK;
            else 
                state_n = state_c;
        end 
        PROGRAM     :begin
            if(program2wip_check)
                state_n = WIP_CHECK;
            else 
                state_n = state_c;
        end 
        WIP_CHECK   :begin
            if(wip_check2wip_wait)
                state_n = WIP_WAIT;
            else 
                state_n = state_c;
        end 
        WIP_WAIT    :begin
            if(wip_wait2wip_check)
                state_n = WIP_CHECK;
            else if(wip_wait2stop)
                state_n = STOP;
            else if(wip_wait2write_enable)
                state_n = WRITE_ENABLE;
            else 
                state_n = state_c;
        end 
        STOP        :begin
            if(stop2idle)
                state_n = IDLE;
            else 
                state_n = state_c;
        end 
        default : state_n = IDLE;
    endcase
end

//Standard SPI例化
standard_spi
#(.SPI_FREQ(25_000_000/5_000_000))
u_standard_spi ( 
.sys_clk        (sys_clk        ),
.sys_rst_n	    (sys_rst_n      ),
    //Control
.spi_cmd        (spi_cmd        ),//{start,write,read,stop}
.writedata      (writedata      ),
.readdata       (readdata       ),
.read_vld       (read_vld       ),
.cmd_update     (cmd_update     ),
.spi_trans_done (spi_trans_done ), 
    //SPI intf
.miso           (flash_miso     ),
.mosi           (flash_mosi     ),
.cs_n           (flash_cs_n     ),
.sclk           (flash_clk      )
);
endmodule
