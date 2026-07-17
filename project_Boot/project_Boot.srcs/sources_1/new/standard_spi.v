/**************************************功能描述***********************************
Date     :				2024.08.06
Author   :			    KWA
Description:		               
            SPI接口模块，完成数据的传输，支持模式的切换
            传输数据的长度适用为8的整数倍
            SPI的SCLK为1MHz
            使用说明：
            1.数据通信周期以start开始，以stop结束
            2.调用该模块，产生相应的spi_cmd 和 writedata(8 bit)
Change history:    
*********************************************************************************/
    
module standard_spi #(parameter SPI_FREQ = 25_000_000/1_000_000,SPI_CLK1_2 = SPI_FREQ/2,
                CPOL = 0,TIME_1US = 1_000)( 
    input				sys_clk		    ,
    input				sys_rst_n	    ,
    //Control
    input       [03:00] spi_cmd         ,//{start,write,read,stop}
    input       [07:00] writedata       ,
    output      [07:00] readdata        ,
    output reg          read_vld        ,
    output              cmd_update      ,
    output              spi_trans_done  , 
    //SPI intf
    input               miso            ,
    output reg          mosi            ,
    output reg          cs_n            ,
    output reg          sclk            
);			

//Parameter definition			 
// IDLE --> START --> WAIT --> WRITE -- > WAIT --> STOP
//                              READ --> WAIT ---> STOP
//状态机参数
localparam  IDLE    = 6 'b000_001, 
            START   = 6 'b000_010,
            WAIT    = 6 'b000_100, 
            WRITE   = 6 'b001_000, 
            READ    = 6 'b010_000, 
            STOP    = 6 'b100_000;  

//Internal signal definition		 
//状态
reg  [05:00]    state_c;
reg  [05:00]    state_n;

//spi_cmd寄存打拍   
reg  [03:00]    cmd_r1;
reg  [03:00]    cmd_r2;

//指令计数
reg  [02:00]    ins_cnt;
wire            ins_add;
wire            ins_end;    

//SCLK时钟计数
reg  [$clog2(SPI_FREQ) - 1:00]        scl_cnt;
wire                                  scl_add;
wire                                  scl_end;

//等待时间计数，用于满足器件的BUS FREE TIME
reg  [03:00]        wait_cnt;
wire                wait_add;
wire                wait_end;

//传输数据bit位计数
reg  [07:00]    bit_cnt;
wire            bit_add;
wire            bit_end;

//stop cnt
reg  [$clog2(TIME_1US) - 1:00]    stop_cnt;
wire                              stop_add;
wire                              stop_end;

//状态机跳转条件
    wire            idle2start,
                    start2wait,
                    wait2write,
                    wait2read ,
                    wait2stop ,
                    write2wait,
                    read2wait ,
                    stop2idle ;

assign  idle2start = state_c == IDLE  && cmd_r2[3], 
        start2wait = state_c == START && ins_end  ,//指令发送完成
        wait2write = state_c == WAIT  && wait_end && cmd_r2[2],//空闲时间满足，且下一Phase继续写入(地址or数据)
        wait2read  = state_c == WAIT  && wait_end && cmd_r2[1],//空闲时间满足，且下一Phase继续写入(地址or数据)
        wait2stop  = state_c == WAIT  && wait_end && cmd_r2[0],//空闲时间满足，无下一Phase
        write2wait = state_c == WRITE && bit_end,//写入完成
        read2wait  = state_c == READ  && bit_end ,//读取完成
        stop2idle  = state_c == STOP  && stop_end;//每次communication间隔


//cmd打拍
    always @(posedge sys_clk or negedge sys_rst_n)begin 
        if(!sys_rst_n)begin
            cmd_r1 <= 'd0;
            cmd_r2 <= 'd0;
        end 
        else begin 
            cmd_r1 <= spi_cmd;
            cmd_r2 <= cmd_r1;
        end 
    end

//ins计数器
    always @(posedge sys_clk or negedge sys_rst_n)begin 
       if(!sys_rst_n)begin
            ins_cnt <= 'd0;
        end 
        else if(ins_add)begin 
            if(ins_end)begin 
                ins_cnt <= 'd0;
            end
            else begin 
                ins_cnt <= ins_cnt + 1'b1;
            end 
        end
    end 
    
    assign ins_add = (state_c == START) && scl_end;
    assign ins_end = ins_add && ins_cnt == 4'd8 - 1'b1;
    
//SCLK计数器
    always @(posedge sys_clk or negedge sys_rst_n)begin 
       if(!sys_rst_n)begin
            scl_cnt <= 'd0;
        end 
        else if(scl_add)begin 
            if(scl_end)begin 
                scl_cnt <= 'd0;
            end
            else begin 
                scl_cnt <= scl_cnt + 1'b1;
            end 
        end
    end 
    
    assign scl_add = (state_c == START || state_c == WRITE || state_c == READ);
    assign scl_end = scl_add && scl_cnt == SPI_FREQ - 1'b1;

//WAIT计数器
    always @(posedge sys_clk or negedge sys_rst_n)begin 
       if(!sys_rst_n)begin
            wait_cnt <= 'd0;
        end 
        else if(wait_add)begin 
            if(wait_end)begin 
                wait_cnt <= 'd0;
            end
            else begin 
                wait_cnt <= wait_cnt + 1'b1;
            end 
        end
    end 
    
    assign wait_add = (state_c == WAIT);
    assign wait_end = wait_add && wait_cnt == 5'd16 - 1'b1;
    
//传输bit计数器
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
    
    assign bit_add = (state_c == WRITE || state_c == READ) && scl_end;
    assign bit_end = bit_add && bit_cnt == 4'd8 - 1'b1;
    
//stop计数器
    always @(posedge sys_clk or negedge sys_rst_n)begin 
       if(!sys_rst_n)begin
            stop_cnt <= 'd0;
        end 
        else if(stop_add)begin 
            if(stop_end)begin 
                stop_cnt <= 'd0;
            end
            else begin 
                stop_cnt <= stop_cnt + 1'b1;
            end 
        end
    end 
    
    assign stop_add = (state_c == STOP);
    assign stop_end = stop_add && stop_cnt == TIME_1US - 1'd1; 
    
//状态机
//1.
    always @(posedge sys_clk or negedge sys_rst_n)begin 
        if(!sys_rst_n)begin
            state_c <= IDLE;
        end 
        else begin 
            state_c <= state_n;
        end 
    end
//2.  
    always @(*) begin
        case(state_c)
            IDLE :begin
                if(idle2start)
                    state_n = START;
                else 
                    state_n = state_c;
            end 
            START:begin
                if(start2wait)
                    state_n = WAIT;
                else 
                    state_n = state_c;
            end 
            WAIT :begin
                if(wait2stop)
                    state_n = STOP;
                else if(wait2write)
                    state_n = WRITE;
                else if(wait2read)
                    state_n = READ;
                else 
                    state_n = state_c;
            end 
            WRITE:begin
                if(write2wait)
                    state_n = WAIT;
                else 
                    state_n = state_c;
            end 
            READ :begin
                if(read2wait)
                    state_n = WAIT;
                else 
                    state_n = state_c;
            end 
            STOP :begin
                if(stop2idle)
                    state_n = IDLE;
                else 
                    state_n = state_c;
            end 
            default : state_n = state_c;
        endcase
    end

//MOSI
    always @(posedge sys_clk or negedge sys_rst_n)begin 
        if(!sys_rst_n)begin
            mosi <= 'd0;
        end 
        else begin 
            case(state_n)
                IDLE : mosi <= 'd0;
                START: mosi <= writedata[3'd7 - ins_cnt];
                WAIT : mosi <= 'd0;
                WRITE: mosi <= writedata[3'd7 - bit_cnt];
                READ : mosi <= 'd0;
                STOP : mosi <= 'd0;
            endcase
        end 
    end

//cs_n
    always @(posedge sys_clk or negedge sys_rst_n)begin 
        if(!sys_rst_n)begin
            cs_n <= 1'd1;
        end 
        else begin 
            case(state_c)    
                IDLE : cs_n <= 1'b1;
                START,WAIT,WRITE,READ: cs_n <= 1'b0;
                STOP : cs_n <= (stop_cnt <= 5'd20)?1'b0:1'b1;
            endcase
        end 
    end

//sclk
    always @(posedge sys_clk or negedge sys_rst_n)begin 
        if(!sys_rst_n)begin
            sclk <= CPOL; //榛橈拷?鏋佹?у簲涓猴拷?锟??锟斤拷妯″紡
        end 
        else begin
            case(state_c) 
                IDLE,WAIT,STOP : sclk <= CPOL;
                START,WRITE,READ : sclk <= (scl_cnt < SPI_CLK1_2)?CPOL:(!CPOL);
            endcase
        end 
    end

//read_data
    reg  [31:00]    readdata_r;

    always @(posedge sys_clk or negedge sys_rst_n)begin 
        if(!sys_rst_n)begin
            readdata_r <= 'd0;
        end 
        else if((state_c == READ) && (scl_cnt == SPI_CLK1_2))begin
            readdata_r <= {readdata_r[30:00],miso};
        end 
        else if(state_c == IDLE)begin
            readdata_r <= 'd0;
        end 
        else begin 
            readdata_r <= readdata_r;
        end 
    end

//read flag
    reg                 read_flag;

    always @(posedge sys_clk or negedge sys_rst_n)begin 
        if(!sys_rst_n)begin
            read_flag <= 'd0;
        end 
        else if(wait2read)begin 
            read_flag <= 1'b1;
        end 
        else if(wait2stop)begin
            read_flag <= 1'b0;
        end 
        else begin 
            read_flag <= read_flag;
        end 
    end

//read_vld
    always @(posedge sys_clk or negedge sys_rst_n)begin 
        if(!sys_rst_n)begin
            read_vld <= 'd0;
        end 
        else if(read_flag && (wait2stop || wait2read))begin 
            read_vld <= 1'b1;
        end 
        else begin 
            read_vld <= 1'b0;
        end 
    end

    // assign read_vld = (read_flag && wait2stop)?1'b1:1'b0;

// //readdata
//     always @(posedge sys_clk or negedge sys_rst_n)begin 
//         if(!sys_rst_n)begin
//             readdata <= 'd0;
//         end 
//         else if(read_vld)begin 
//             readdata <= readdata_r;
//         end 
//         else begin 
//             readdata <= readdata;
//         end 
//     end

    assign readdata = read_vld?readdata_r:'d0;

//cmd_update
    assign cmd_update = start2wait || write2wait || read2wait;

//spi_trans_done
    assign spi_trans_done = stop2idle;

endmodule