`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/08 10:40:16
// Design Name: 
// Module Name: uart_receive
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


module uart_receive(
    input               sys_clk             ,
    input               sys_rst_n           ,
    //Uart
    input               uart_rx             ,
    output              receive_done        ,
    //fifo_512
    output      [07:00] fifo_din            ,//FIFO写入数据
    output reg          fifo_write          , //FIFO写使能  
    //flash_ctrl
    //操作请求
    output reg          erase_req           ,//擦除请求
    output reg          icap_req            ,//跳转app请求 回复指令05

    output reg  [31:00] total_byte          ,//文件总字节大小
    output reg  [15:00] total_seq           ,//总序列号 = total_byte/128  
    output reg  [15:00] current_seq         ,//当前数据帧序列号
    //uart_send
    //通信请求
    output reg          boot_req            ,//请求进入boot 回复指令01
    output reg          upd_confirm         ,//更新确认 回复指令02
    output reg          rdy_status_query    ,//更新前准备状态查询 回复指令85
    output reg          crc_status_query    ,//校验状态查询 回复指令86
    output reg          file_head_info      ,//更新固件头信息 回复指令03
    //解析信息
    output reg  [31:00] firmware_version    ,//更新固件版本号
    output reg  [15:00] pack_nums           ,//单包字节数
    output reg  [31:00] bin_place           ,//更新文件存储位置
    output reg  [15:00] filehead_size       ,//文件头大小
    output reg  [15:00] file_crc            ,//文件CRC

    output reg          write_successed     ,//写入成功 回复指令04
    output reg          write_faild          //写入失败 回复指令04
    );

//波特率
parameter BAUD = 434;

//状态机参数
parameter IDLE         = 11'h001; 
parameter HEADER       = 11'h002;//帧头
parameter LENGTH       = 11'h004;//后续数据长度
parameter TYPE         = 11'h008;//指令类型
parameter T_SERIAL     = 11'h010;//总序列号      
parameter SERIAL_NUM   = 11'h040;//当前数据帧序列号
parameter FILE_CONTENT = 11'h080;//文件数据
parameter CRC          = 11'h100; 
parameter RSTOP        = 11'h200;//正常结束      
parameter ESTOP        = 11'h400;//异常结束


//状态机跳转条件
wire idle2header                        ;
wire header2length                      ;
wire header2estop                       ;
wire length2type                        ;
wire length2estop                       ;

wire type2crc                           ;
wire type2tserial                       ;
wire type2serial_num                    ;

wire crc2rstop                          ;
wire crc2estop                          ;
wire t_serial2crc                       ;

wire serial_num2file_content            ;
wire file_content2crc                   ;
wire rstop2idle                         ;
wire estop2idle                         ;

reg  [10:00]    state_c                 ;
reg  [10:00]    state_n                 ;

//RAM读写接口 (Read latency: 2 Clock Cycles)
reg             ram_write_ena           ;
reg             ram_write_wea           ;
reg     [06:00] ram_write_addra         ;
reg     [07:00] ram_write_dina          ;

wire            ram_read_enb            ;
wire    [06:00] ram_read_addrb          ;
wire    [07:00] ram_read_doutb          ;

//uart_rx
wire    [07:00] uart_rx_data            ;//串口接收数据
wire            uart_rx_data_vld        ;//串口接收数据有效

//CRC校验
reg             crc_en                  ;//CRC校验使能
reg     [07:00] crc_data                ;//待校验数据
reg             crc_clr                 ;//CRC校验模块恢复初始值
wire    [15:00] crc_value               ;//16位CRC计算值

//数据长度
reg     [07:00] data_len                ;
//指令类型
reg     [07:00] ins_type                ;
//CRC正确标志
reg             crc_correct             ;
//CRC错误标志
reg             crc_erro                ;

//字节计数器
reg     [07:00] byte_cnt                ;
wire            byte_add                ;
wire            byte_end                ;
reg     [07:00] byte_max                ;

//等待CRC校验
reg     [02:00] crc_cnt                 ;
wire            crc_add                 ;
wire            crc_end                 ;
reg             crc_flag                ;

//收到的CRC
reg     [15:00] receive_crc             ;

//RAM读取标志
reg             read_flag               ;
reg     [07:00] read_cnt                ;
wire            read_add                ;
wire            read_end                ;

reg     [05:00] rstop_cnt               ;

//上一个校验正确且写入内存的帧序列号
reg     [15:00] last_seq                ;
//数据长度获取
always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    data_len <= {8{1'b0}};
  end 
  else if(icap_req)begin
    data_len <= {8{1'b0}};
  end 
  else if((state_c == TYPE) && uart_rx_data_vld)begin 
    data_len <= uart_rx_data;
  end 
  else begin 
    data_len <= data_len;
  end 
end

//指令代码获取
always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    ins_type <= 'd0;
  end 
  else if(icap_req)begin
    ins_type <= 'd0;
  end 
  else if((state_c == LENGTH) && uart_rx_data_vld)begin 
    ins_type <= uart_rx_data;
  end 
  else begin 
    ins_type <= ins_type;
  end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
   if(!sys_rst_n)begin
    byte_cnt <= {8{1'b0}};
  end 
  else if(icap_req)begin
    byte_cnt <= {8{1'b0}};
  end 
  else if(byte_add)begin 
    if(byte_end)begin 
      byte_cnt <= {8{1'b0}};
    end
    else begin 
      byte_cnt <= byte_cnt + 1'b1;
    end 
  end
  else if(state_c == IDLE)begin
      byte_cnt <= {8{1'b0}};
  end 
end 

assign byte_add = ((state_c == CRC) || (state_c == T_SERIAL)  || (state_c == SERIAL_NUM) || (state_c == FILE_CONTENT)) && uart_rx_data_vld;
assign byte_end = byte_add && byte_cnt == byte_max - 1'b1;

always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    byte_max <= 2'd2;
  end 
  else if(icap_req)begin
    byte_max <= 2'd2;
  end 
  else if((state_n == CRC) || (state_n == SERIAL_NUM))begin 
    byte_max <= 2'd2;
  end 
  else if(state_n == T_SERIAL)begin
    byte_max <= data_len;
  end 
  else if(state_n == FILE_CONTENT)begin
    byte_max <= data_len - 2'd2;
  end 
  else begin 
    byte_max <= 2'd2;
  end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    crc_flag <= 'd0;
  end 
  else if(icap_req)begin
    crc_flag <= 'd0;
  end 
  else if((state_c == CRC) && byte_end)begin 
    crc_flag <= 1'b1;
  end 
  else if(crc_end)begin
    crc_flag <= 1'b0;
  end 
  else begin 
    crc_flag <= crc_flag;
  end 
end

//CRC字段接受完后第8个时钟周期进行对比CRC是否正确
always @(posedge sys_clk or negedge sys_rst_n)begin 
   if(!sys_rst_n)begin
    crc_cnt <= 'd0;
  end 
  else if(icap_req)begin
    crc_cnt <= 'd0;
  end 
  else if(crc_add)begin 
    if(crc_end)begin 
      crc_cnt <= 'd0;
    end
    else begin 
      crc_cnt <= crc_cnt + 1'b1;
    end 
  end
end 

assign crc_add = crc_flag;
assign crc_end = crc_add && crc_cnt == 4'd8 - 1'b1;

//收到的CRC
always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    receive_crc <= {15{1'b0}};
  end 
  else if(icap_req)begin
    receive_crc <= {15{1'b0}};
  end 
  else if((state_c == CRC) && uart_rx_data_vld)begin 
    //右移
    receive_crc <= {uart_rx_data,receive_crc[15:8]};
  end 
  else begin 
    receive_crc <= receive_crc;
  end 
end

//CRC字段正确置1,否则为0
always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    crc_correct <= 'd0;
  end 
  else if(icap_req)begin
    crc_correct <= 'd0;
  end 
  else if(crc_end)begin 
    if(receive_crc == crc_value)
      crc_correct <= 1'b1;
    else 
      crc_correct <= 'd0;
  end 
  else begin 
    crc_correct <= 'd0;
  end 
end

//CRC字段错误置1,否则为0
always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    crc_erro <= 'd0;
  end 
  else if(icap_req)begin
    crc_erro <= 'd0;
  end 
  else if(crc_end)begin 
    if(receive_crc != crc_value)
      crc_erro <= 1'b1;
    else 
      crc_erro <= 1'b0;
  end 
  else begin 
    crc_erro <= 'd0;
  end 
end



//更新版本固件号解析
//总文件大小解析
//总序列号解析
always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    firmware_version <= {32{1'b0}};
    total_byte <= {32{1'b0}};
    total_seq <= {16{1'd0}};
    pack_nums <= {16{1'd0}};
    bin_place <= {32{1'b0}};
    filehead_size <= {16{1'd0}};
    file_crc  <= {16{1'd0}};
  end 
  else if(icap_req)begin
    firmware_version <= {32{1'b0}};
    total_byte <= {32{1'b0}};
    total_seq <= {16{1'd0}};
    pack_nums <= {16{1'd0}};
    bin_place <= {32{1'b0}};
    filehead_size <= {16{1'd0}};
    file_crc  <= {16{1'd0}};
  end 
  else if((state_c == T_SERIAL) && uart_rx_data_vld)begin 
    if((byte_cnt >= 'd0) && (byte_cnt < 3'd4))
      firmware_version <= {uart_rx_data,firmware_version[31:08]};
    else if((byte_cnt >= 3'd4) && (byte_cnt < 4'd8))
      total_byte <= {uart_rx_data,total_byte[31:08]};
    else if((byte_cnt >= 4'd8) && (byte_cnt < 4'd10))
      total_seq <= {uart_rx_data,total_seq[15:08]};
    else if((byte_cnt >= 4'd10) && (byte_cnt < 4'd12))
      pack_nums <= {uart_rx_data,pack_nums[15:08]};
    else if((byte_cnt >= 4'd12) && (byte_cnt < 5'd16))
      bin_place <= {uart_rx_data,bin_place[31:08]};
    else if((byte_cnt >= 5'd16) && (byte_cnt < 5'd18))
      filehead_size <= {uart_rx_data,filehead_size[15:08]};
    else if((byte_cnt >= 5'd18) && (byte_cnt < 5'd20))
      file_crc <= {uart_rx_data,file_crc[15:08]};
  end 
  else begin 
    firmware_version <= firmware_version;
    total_byte <= total_byte;
    total_seq <= total_seq;
    pack_nums <= pack_nums;
    bin_place <= bin_place;
    filehead_size <= filehead_size;
    file_crc  <= file_crc;
  end 
end

//当前序列号解析
always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    current_seq <= {16{1'b0}};
  end 
  else if(icap_req)begin
    current_seq <= {16{1'b0}};
  end 
  else if((state_c == SERIAL_NUM) && uart_rx_data_vld)begin 
    current_seq <= {uart_rx_data,current_seq[15:08]};
  end 
  else begin 
    current_seq <= current_seq;
  end 
end

//文件内容写入到RAM
always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    ram_write_ena   <= 'd0;
    ram_write_wea   <= 'd0;
    ram_write_addra <= 7'h7F;
    ram_write_dina  <= {8{1'b0}};
  end 
  else if(icap_req)begin
    ram_write_ena   <= 'd0;
    ram_write_wea   <= 'd0;
    ram_write_addra <= 7'h7F;
    ram_write_dina  <= {8{1'b0}};
  end 
  else if((state_c == FILE_CONTENT) && uart_rx_data_vld)begin 
    //打开写使能
    ram_write_ena <= 1'b1;
    ram_write_wea <= 1'b1;  
    ram_write_addra <= ram_write_addra + 1'b1;
    ram_write_dina <= uart_rx_data;
  end 
  else if(state_c == FILE_CONTENT)begin
    ram_write_ena   <= 'd0;
    ram_write_wea   <= 'd0;
    ram_write_addra <= ram_write_addra;
    ram_write_dina  <= {8{1'b0}};
  end 
  else begin 
    ram_write_ena   <= 'd0;
    ram_write_wea   <= 'd0;
    ram_write_addra <= 7'h7F;
    ram_write_dina  <= {8{1'b0}};
  end 
end

//CRC校验
always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    crc_en   <= 'd0;
    crc_data <= {8{1'b0}}; 
  end 
  else if(icap_req)begin
    crc_en   <= 'd0;
    crc_data <= {8{1'b0}}; 
  end 
  else if((state_c == IDLE) && uart_rx_data_vld && (uart_rx_data != 8'h82))begin
    crc_en   <= 'd0;
    crc_data <= {8{1'b0}}; 
  end 
  else if(state_c != CRC)begin 
    crc_en <= uart_rx_data_vld;
    crc_data <= uart_rx_data;
  end 
  else begin 
    crc_en   <= 'd0;
    crc_data <= {8{1'b0}};
  end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    crc_clr <= 'd0;
  end 
  else if(icap_req)begin
    crc_clr <= 'd0;
  end 
  else if(estop2idle || rstop2idle)begin 
    crc_clr <= 1'b1;
  end 
  else begin 
    crc_clr <= 'd0;
  end 
end

//Flash 擦除请求
always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    erase_req <= 'd0;
  end 
  else if(icap_req)begin
    erase_req <= 'd0;
  end 
  else if((ins_type == 8'h03) && rstop2idle)begin 
    erase_req <= 1'b1;
  end 
  else begin 
    erase_req <= 1'b0;
  end 
end

//写入成功
always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    write_successed <= 'd0;
  end 
  else if(icap_req)begin
    write_successed <= 'd0;
  end 
  else if((ins_type == 8'h04) && rstop2idle && (last_seq >= current_seq) /*&& (current_seq[0] == 'd0)*/)begin
    write_successed <= 'd1;
  end 
  else if(read_end && ((current_seq == total_seq - 'd1) || (current_seq % 2 == 'd0)))begin 
    write_successed <= 1'b1;
  end 
  else begin 
    write_successed <= 1'b0;
  end 
end

//写入失败
always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    write_faild <= 'd0;
  end 
  else if(icap_req)begin
    write_faild <= 'd0;
  end 
  else if((ins_type == 8'h04) && estop2idle)begin 
    write_faild <= 1'b1;
  end 
  else begin 
    write_faild <= 'd0;
  end 
end

//
always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    last_seq <= 16'hFFFF;
  end 
  else if(icap_req)begin
    last_seq <= 16'hFFFF;
  end 
  else if((ins_type == 8'h04) && rstop2idle && ((current_seq >= last_seq) || ((current_seq == 'd0) && (last_seq == 16'hFFFF))))begin 
    last_seq <= current_seq;
  end 
  else begin 
    last_seq <= last_seq;
  end 
end

//固件文件内容校验成功，开始读取
always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    read_flag <= 'd0;
  end 
  else if(icap_req)begin
    read_flag <= 'd0;
  end 
  else if((ins_type == 8'h04) && rstop2idle && ((last_seq < current_seq) || ((current_seq == 'd0) && (last_seq == 16'hFFFF))))begin 
    read_flag <= 1'b1;
  end 
  else if(read_end)begin
    read_flag <= 1'b0;
  end 
  else begin 
    read_flag <= read_flag;
  end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
   if(!sys_rst_n)begin
    read_cnt <= 'd0;
  end 
  else if(icap_req)begin
    read_cnt <= 'd0;
  end 
  else if(read_add)begin 
    if(read_end)begin 
      read_cnt <= 'd0;
    end
    else begin 
      read_cnt <= read_cnt + 1'b1;
    end 
  end
  else begin
      read_cnt <= 'd0;
  end 
end 

assign read_add = read_flag;
assign read_end = read_add && read_cnt == (data_len - 3'd2 - 1'b1);

assign ram_read_enb   = read_flag;
assign ram_read_addrb = read_cnt;

always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    fifo_write <= 'd0;
  end 
  else if(icap_req)begin
    fifo_write <= 'd0;
  end 
  else begin 
    fifo_write <= ram_read_enb;
  end 
end

assign fifo_din = ram_read_doutb;

always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    boot_req <= 'd0;
  end 
  else if(icap_req)begin
    boot_req <= 'd0;
  end 
  else if((ins_type == 8'h01) && rstop2idle)begin 
    boot_req <= 'd1;
  end 
  else begin 
    boot_req <= 'd0;
  end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    upd_confirm <= 'd0;
  end 
  else if(icap_req)begin
    upd_confirm <= 'd0;
  end 
  else if((ins_type == 8'h02) && rstop2idle)begin 
    upd_confirm <= 'd1;
  end 
  else begin 
    upd_confirm <= 'd0;
  end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    rdy_status_query <= 'd0;
  end 
  else if(icap_req)begin
    rdy_status_query <= 'd0;
  end 
  else if((ins_type == 8'h85) && rstop2idle)begin 
    rdy_status_query <= 'd1;
  end 
  else begin 
    rdy_status_query <= 'd0;
  end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    crc_status_query <= 'd0;
  end 
  else if(icap_req)begin
    crc_status_query <= 'd0;
  end 
  else if((ins_type == 8'h86) && rstop2idle)begin 
    crc_status_query <= 'd1;
  end 
  else begin 
    crc_status_query <= 'd0;
  end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    icap_req <= 'd0;
  end 
  else if((ins_type == 8'h05) && rstop2idle)begin 
    icap_req <= 'd1;
  end 
  else begin 
    icap_req <= 'd0;
  end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    file_head_info <= 'd0;
  end 
  else if(icap_req)begin
    file_head_info <= 'd0;
  end 
  else if((ins_type == 8'h03) && rstop2idle)begin 
    file_head_info <= 'd1;
  end 
  else begin 
    file_head_info <= 'd0;
  end 
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
  if(!sys_rst_n)begin
    rstop_cnt <= 'd0;
  end 
  else if(icap_req)begin
    rstop_cnt <= 'd0;
  end 
  else if((state_c == RSTOP))begin 
    if(rstop_cnt == 6'd63)
      rstop_cnt <= 'd0;
    else 
      rstop_cnt <= rstop_cnt + 'd1;
  end 
  else begin 
    rstop_cnt <= 'd0;
  end 
end

//文件内容校验正确,取出放入FIFO

//帧头为0x5A跳转HEADER
assign idle2header              = (state_c == IDLE) && uart_rx_data_vld && (uart_rx_data == 8'h82);
//帧头第二字节为0x5A跳转LENGTH
assign header2length            = (state_c == HEADER) && uart_rx_data_vld && (uart_rx_data == 8'h66);
//帧头第二字节不是0x5A跳转ESTOP
assign header2estop             = (state_c == HEADER) && uart_rx_data_vld && (uart_rx_data != 8'h66);
//数据长度字节接收
assign length2type              = (state_c == LENGTH) && uart_rx_data_vld && ((uart_rx_data == 8'h01) || (uart_rx_data == 8'h02) || (uart_rx_data == 8'h03) || (uart_rx_data == 8'h85) || (uart_rx_data == 8'h04) || (uart_rx_data == 8'h83) || (uart_rx_data == 8'h84) || (uart_rx_data == 8'h86) || (uart_rx_data == 8'h05));
//所接收到的指令类型不在规定内，跳转到错误结束
assign length2estop             = (state_c == LENGTH) && uart_rx_data_vld;
//长度为00，跳转到CRC
assign type2crc                 = (state_c == TYPE) && uart_rx_data_vld && (uart_rx_data == 8'h00);
//指令类型为03，固件头信息:总序列号,固件大小等信息
assign type2tserial             = (state_c == TYPE) && uart_rx_data_vld && (ins_type == 8'h03);
//指令类型为0x04跳转序列号
assign type2serial_num          = (state_c == TYPE) && uart_rx_data_vld && (ins_type == 8'h04);
//CRC正确跳转RSTOP
assign crc2rstop                = (state_c == CRC) && crc_correct;
//CRC错误跳转ESTOP
assign crc2estop                = (state_c == CRC) && crc_erro;
//总序列号接收
assign t_serial2crc             = (state_c == T_SERIAL) && byte_end;
//序列号接收完毕
assign serial_num2file_content  = (state_c == SERIAL_NUM) && byte_end;
assign file_content2crc         = (state_c == FILE_CONTENT) && byte_end;
assign rstop2idle               = (state_c == RSTOP) && (rstop_cnt == 6'd63);
assign estop2idle               = (state_c == ESTOP) && 1'b1;

assign receive_done = crc2rstop;
//状态机
always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        state_c <= IDLE;//初始状态一般为IDLE
    end 
    else if(icap_req)begin
        state_c <= IDLE;//初始状态一般为IDLE
    end 
    else begin 
        state_c <= state_n;
    end 
end

always @(*) begin
    case(state_c)
        IDLE        :begin
          if(idle2header)
            state_n = HEADER;
          else 
            state_n = state_c;
        end 
        HEADER      :begin
          if(header2estop)
            state_n = ESTOP;
          else if(header2length)
            state_n = LENGTH;
          else 
            state_n = state_c;
        end 
        LENGTH      :begin
          if(length2type)
            state_n = TYPE;
          else if(length2estop)
            state_n = ESTOP;
          else 
            state_n = state_c;
        end 
        TYPE        :begin
          if(type2crc)
            state_n = CRC;
          else if(type2serial_num)
            state_n = SERIAL_NUM;
          else if(type2tserial)
            state_n = T_SERIAL;
          else 
            state_n = state_c;
        end 
        T_SERIAL    :begin
          if(t_serial2crc)
            state_n = CRC;
          else 
            state_n = state_c;
        end 
        SERIAL_NUM  :begin
          if(serial_num2file_content)
            state_n = FILE_CONTENT;
          else 
            state_n = state_c;
        end 
        FILE_CONTENT:begin
          if(file_content2crc)
            state_n = CRC;
          else 
            state_n = state_c;
        end 
        CRC         :begin
          if(crc2rstop)
            state_n = RSTOP;
          else if(crc2estop)
            state_n = ESTOP;
          else 
            state_n = state_c;
        end 
        RSTOP       :begin
          if(rstop2idle)
            state_n = IDLE;
          else 
            state_n = state_c;
        end 
        ESTOP       :begin
          if(estop2idle)
            state_n = IDLE;
          else 
            state_n = state_c;
        end 
        default :state_n = IDLE;
    endcase
end


//串口接收数据放入
//CRC校验正确后读出,否则覆盖
ram_128x8 receive_ram(
  .clka             (sys_clk            ),// input wire clka
  .ena              (ram_write_ena      ),// input wire ena
  .wea              (ram_write_wea      ),// input wire [0 : 0] wea
  .addra            (ram_write_addra    ),// input wire [6 : 0] addra
  .dina             (ram_write_dina     ),// input wire [7 : 0] dina
  .clkb             (sys_clk            ),// input wire clkb
  .rstb             (~sys_rst_n         ),// input wire rstb
  .enb              (ram_read_enb       ),// input wire enb
  .addrb            (ram_read_addrb     ),// input wire [7 : 0] addrb
  .doutb            (ram_read_doutb     ) // output wire [7 : 0] doutb
);

uart_rx
#(.BAUD(BAUD))
u_uart_rx(
.sys_clk            (sys_clk            ),
.sys_rst_n          (sys_rst_n          ),
//Uart
.uart_rx            (uart_rx            ),

.uart_rx_data       (uart_rx_data       ),//Uart接受数据
.uart_rx_data_vld   (uart_rx_data_vld   ) //Uart接受数据有效
);

//CRC校验模块
crc_16_modbus
crc_16_modbus_receive( 
.sys_clk            (sys_clk            ),
.sys_rst_n          (sys_rst_n          ),
.crc_en             (crc_en             ),//使能，计算CRC
.crc_data           (crc_data           ),//待校验数据
.crc_clr            (crc_clr            ),//清除，恢复初始值
.crc_value          (crc_value          )//计算得到的CRC值           
);
endmodule
