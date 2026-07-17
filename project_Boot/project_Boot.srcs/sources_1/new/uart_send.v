`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/10 09:30:51
// Design Name: 
// Module Name: uart_send
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


module uart_send(
    input               sys_clk             ,
    input               sys_rst_n           ,
//Uart
    output              uart_tx             ,
    output              send_done           ,

    input               boot_req            ,
    input               upd_confirm         ,
    input               file_head_info      ,
    input               rdy_status_query    ,

    input               crc_status_query    ,
    input               icap_req            ,
    output              icap_en             ,

    input               erasing             ,
    input               erase_completed     ,//擦除完成 E1
    input               program_completed   ,//最后一帧写入Flash完毕 E4
    input               fpga_e2             ,//E2
    input               write_successed     ,//写入成功E3
    input               write_faild         ,//写入失败E3
    input       [15:00] current_seq         ,//当前数据帧序列号
//flash 
    input               one_page_done        //写入成功E3
    );

parameter BAUD = 434;

//状态机参数
parameter IDLE = 9'h001; 
parameter E1   = 9'h002;
parameter E2   = 9'h004;   
parameter E3   = 9'h008;   
parameter E4   = 9'h010;  
parameter E5   = 9'h040;
parameter E6   = 9'h080;
parameter E7   = 9'h100;
parameter CRC  = 9'h020; 

wire idle2e1;
wire idle2e2;
wire idle2e3;
wire idle2e4;
wire idle2e5;
wire idle2e6;
wire idle2e7;
wire e12crc;
wire e22crc;
wire e32crc;
wire e42crc;
wire e52crc;
wire e62crc;
wire e72crc;
wire crc2idle;


reg     [08:00] state_c;
reg     [08:00] state_n;

//串口发送
reg     [07:00] tx_data                 ;//一字节待发送数据
reg             tx_en                   ;//一字节发送使能
wire            tx_completed            ;//一字节发送完成 
wire            tx_ing                  ;//处于发送中

//CRC校验
wire            crc_en                  ;//CRC校验使能
wire    [07:00] crc_data                ;//待校验数据
reg             crc_clr                 ;//CRC校验模块恢复初始值
wire    [15:00] crc_value               ;//16位CRC计算值

//传输字节计数器
reg     [03:00] byte_cnt                ;
wire            byte_add                ;
wire            byte_end                ;
reg     [03:00] byte_max                ;

reg     [07:00] write_result            ;

wire    [07:00] rdy_status;

reg             icap_bit;

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        icap_bit <= 'd0;
    end 
    else if(icap_req)begin 
        icap_bit <= 'd1;
    end 
    else if(crc2idle)begin
        icap_bit <= 'd0;
    end 
    else begin 
        icap_bit <= icap_bit;
    end 
end

assign icap_en = (crc2idle && icap_bit);

assign idle2e1  = (state_c == IDLE) && boot_req;
assign idle2e2  = (state_c == IDLE) && upd_confirm;
assign idle2e3  = (state_c == IDLE) && (write_successed || write_faild || one_page_done);
assign idle2e4  = (state_c == IDLE) && file_head_info;
assign idle2e5  = (state_c == IDLE) && rdy_status_query;
assign idle2e6  = (state_c == IDLE) && crc_status_query;
assign idle2e7  = (state_c == IDLE) && icap_req;
assign e12crc   = (state_c == E1) && byte_end;
assign e22crc   = (state_c == E2) && byte_end;
assign e32crc   = (state_c == E3) && byte_end;
assign e42crc   = (state_c == E4) && byte_end;
assign e52crc   = (state_c == E5) && byte_end;
assign e62crc   = (state_c == E6) && byte_end;
assign e72crc   = (state_c == E7) && byte_end;
assign crc2idle = (state_c == CRC) && byte_end;

assign send_done = crc2idle;
assign rdy_status = (erasing)?8'h00:8'h01;

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

assign byte_add = tx_completed;
assign byte_end = byte_add && byte_cnt == byte_max - 1'b1;

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        byte_max <= 4'd4;
    end 
    else if((state_n == E1) || (state_n == E2))begin 
        byte_max <= 4'd5;
    end 
    else if((state_n == E4))begin
        byte_max <= 4'd5;
    end 
    else if(state_n == E3)begin
        byte_max <= 4'd7;
    end 
    else if(state_n == E5)begin
        byte_max <= 4'd5;
    end 
    else if(state_n == E6)begin
        byte_max <= 4'd5;
    end 
    else if(state_n == E7)begin
        byte_max <= 4'd5;
    end
    else if(state_n == CRC)begin
        byte_max <= 4'd2;
    end 
    else begin 
        byte_max <= 4'd4;
    end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        tx_en <= 'd0;
    end 
    else if(idle2e1 || idle2e2 || idle2e3 || idle2e4 || idle2e5 || idle2e6 || idle2e7 || (tx_completed && (!byte_end) && (state_c == CRC)) || (((state_c == E1) || (state_c == E2) || (state_c == E3) || (state_c == E4) || (state_c == E5) || (state_c == E6) || (state_c == E7)) && tx_completed))begin 
        tx_en <= 1'b1;
    end 
    else begin 
        tx_en <= 1'b0;
    end 
end

always @(*)begin 
    if(!sys_rst_n)begin
        tx_data <= {8{1'b0}};
    end 
    else if(state_n == E1)begin 
        case(byte_cnt)
            1'd0:tx_data <= 8'h82;
            1'd1:tx_data <= 8'h66;
            2'd2:tx_data <= 8'h01;
            2'd3:tx_data <= 8'h01;
            3'd4:tx_data <= 8'h01;
            default:tx_data <= {8{1'b0}};
        endcase
    end 
    else if(state_n == E2)begin
        case(byte_cnt)
            1'd0:tx_data <= 8'h82;
            1'd1:tx_data <= 8'h66;
            2'd2:tx_data <= 8'h02;
            2'd3:tx_data <= 8'h01;
            3'd4:tx_data <= 8'h01;
            default:tx_data <= {8{1'b0}};
        endcase
    end 
    else if(state_n == E3)begin
        case(byte_cnt)
            1'd0:tx_data <= 8'h82;
            1'd1:tx_data <= 8'h66;
            2'd2:tx_data <= 8'h04;
            2'd3:tx_data <= 8'h03;
            3'd4:tx_data <= current_seq[07:00];
            3'd5:tx_data <= current_seq[15:08];
            3'd6:tx_data <= write_result;
            default:tx_data <= {8{1'b0}};
        endcase
    end 
    else if(state_n == E4)begin
        case(byte_cnt)
            1'd0:tx_data <= 8'h82;
            1'd1:tx_data <= 8'h66;
            2'd2:tx_data <= 8'h03;
            2'd3:tx_data <= 8'h01;
            3'd4:tx_data <= 8'h01;
            default:tx_data <= {8{1'b0}};
        endcase
    end 
    else if(state_n == E5)begin
        case(byte_cnt)
            1'd0:tx_data <= 8'h82;
            1'd1:tx_data <= 8'h66;
            2'd2:tx_data <= 8'h85;
            2'd3:tx_data <= 8'h01;
            3'd4:tx_data <= rdy_status;
            default:tx_data <= {8{1'b0}};
        endcase
    end 
    else if(state_n == E6)begin
        case(byte_cnt)
            1'd0:tx_data <= 8'h82;
            1'd1:tx_data <= 8'h66;
            2'd2:tx_data <= 8'h86;
            2'd3:tx_data <= 8'h01;
            3'd4:tx_data <= 8'h01;
            default:tx_data <= {8{1'b0}};
        endcase
    end 
    else if(state_n == E7)begin
        case(byte_cnt)
            1'd0:tx_data <= 8'h82;
            1'd1:tx_data <= 8'h66;
            2'd2:tx_data <= 8'h05;
            2'd3:tx_data <= 8'h01;
            3'd4:tx_data <= 8'h01;
            default:tx_data <= {8{1'b0}};
        endcase
    end
    else if(state_n == CRC)begin
        if(byte_cnt == 'd0)
            tx_data <= crc_value[07:00];
        else 
            tx_data <= crc_value[15:08];
    end 
    else begin 
        tx_data <= {8{1'b0}};
    end 
end

assign crc_en = tx_en && (state_c != CRC);
assign crc_data = tx_data;

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        crc_clr <= 'd0;
    end 
    else if(crc2idle)begin 
        crc_clr <= 1'b1;
    end 
    else begin 
        crc_clr <= 'd0;
    end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        write_result <= 'd0;
    end 
    else if(write_faild)begin 
        write_result <= 8'h00;
    end 
    else if(write_successed || one_page_done)begin
        write_result <= 8'h01;
    end 
    else begin 
        write_result <= write_result;
    end 
end

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
        IDLE    :begin
            if(idle2e1)
                state_n = E1;
            else if(idle2e2)
                state_n = E2;
            else if(idle2e3)
                state_n = E3;
            else if(idle2e4)
                state_n = E4;
            else if(idle2e5)
                state_n = E5;
            else if(idle2e6)
                state_n = E6;
            else if(idle2e7)
                state_n = E7;
            else 
                state_n = state_c;
        end 
        E1      :begin
            if(e12crc)
                state_n = CRC;
            else 
                state_n = state_c;
        end 
        E2      :begin
            if(e22crc)
                state_n = CRC;
            else 
                state_n = state_c;
        end 
        E3      :begin
            if(e32crc)
                state_n = CRC;
            else 
                state_n = state_c;
        end 
        E4      :begin
            if(e42crc)
                state_n = CRC;
            else 
                state_n = state_c;
        end 
        E5      :begin
            if(e52crc)
                state_n = CRC;
            else 
                state_n = state_c;
        end 
        E6      :begin
            if(e62crc)
                state_n = CRC;
            else 
                state_n = state_c;
        end
        E7      :begin
            if(e72crc)
                state_n = CRC;
            else 
                state_n = state_c;
        end
        CRC     :begin
            if(crc2idle)
                state_n = IDLE;
            else 
                state_n = state_c;
        end 
        default :state_n = IDLE;
    endcase
end

uart_tx
#(.BAUD(BAUD))
u_uart_tx(
.sys_clk             (sys_clk           ),
.sys_rst_n           (sys_rst_n         ),
//Uart
.uart_tx             (uart_tx           ),
.tx_data             (tx_data           ),//一字节待发送数据
.tx_en               (tx_en             ),//一字节发送使能
.tx_completed        (tx_completed      ),//一字节发送完成 
.tx_ing              (tx_ing            ) //处于发送中
    );


//CRC校验模块
crc_16_modbus
crc_16_modbus_send( 
.sys_clk            (sys_clk            ),
.sys_rst_n          (sys_rst_n          ),
.crc_en             (crc_en             ),//使能，计算CRC
.crc_data           (crc_data           ),//待校验数据
.crc_clr            (crc_clr            ),//清除，恢复初始值
.crc_value          (crc_value          )//计算得到的CRC值           
);
endmodule
