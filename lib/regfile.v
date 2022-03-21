`include "defines.vh"
module regfile(
    input wire clk,
    input wire [4:0] raddr1,
    output wire [31:0] rdata1,
    input wire [4:0] raddr2,
    output wire [31:0] rdata2,
    input wire [1:0] hilo_we,
    input wire hilo_en,
    input wire hilo_relate,
    input wire ex_we,
    input wire [1:0] ex_hilo_we,
    input wire ex_hilo_en,
    input wire [63:0] ex_hilo_data,
    input wire [4:0] ex_waddr,
    input wire [31:0] ex_wdata,
    input wire mem_we,
    input wire [1:0] mem_hilo_we,
    input wire mem_hilo_en,
    input wire [63:0] mem_hilo_data,
    input wire [4:0] mem_waddr,
    input wire [31:0] mem_wdata,
    input wire we,
    input wire [4:0] waddr,
    input wire [31:0] wdata,
    input wire [31:0] hi_rdata,
    input wire [31:0] lo_rdata,
    input wire [1:0] hilo_we_rf,
    input wire hilo_en_rf
);
    reg [31:0] reg_array [31:0];
    reg [31:0] hilo_reg [1:0];//1hi,0lo
    // write
    always @ (posedge clk) begin
        if (we && waddr!=5'b0) begin
            reg_array[waddr] <= wdata;
        end
        if (hilo_we_rf == 2'b11 && hilo_en_rf)begin
           hilo_reg[0]<=lo_rdata;
           hilo_reg[1]<=hi_rdata;
        end
        if (hilo_we_rf == 2'b10 && hilo_en_rf)begin
           hilo_reg[1]<=wdata;
        end
        if (hilo_we_rf == 2'b01 && hilo_en_rf)begin
           hilo_reg[0]<=wdata;
        end
    end
    reg [31:0] temp [1:0];
    // read out 1
    //assign rdata1 = (raddr1 == 5'b0) ? 32'b0 : reg_array[raddr1];
    always @ (*) begin
      if((ex_we ==1'b1) && (raddr1 ==ex_waddr) && ~hilo_relate)
       temp[0] <= ex_wdata;
     else if((mem_we ==1'b1) && (raddr1 ==mem_waddr) && ~hilo_relate)
       temp[0] <= mem_wdata;
     else if((we ==1'b1) && (raddr1 == waddr) && ~hilo_relate)
       temp[0] <= wdata;
     else if (raddr1 !=5'b0)
       temp[0] <= reg_array[raddr1];
     else if(ex_hilo_we[1] && ~hilo_we[1] && ex_hilo_en && ~hilo_en && hilo_relate)
       temp[0] <= ex_hilo_we==2'b11 ? ex_hilo_data[63:32]:ex_wdata;
     else if(ex_hilo_we[0] && ~hilo_we[0] && ex_hilo_en && ~hilo_en && hilo_relate)
       temp[0] <= ex_hilo_we==2'b11 ? ex_hilo_data[31:0]:ex_wdata;
     else if(mem_hilo_we[1] && ~hilo_we[1] && mem_hilo_en && ~hilo_en && hilo_relate)
       temp[0] <= mem_hilo_we==2'b11 ?  mem_hilo_data[63:32]:mem_wdata;
     else if(mem_hilo_we[0] && ~hilo_we[0] && mem_hilo_en && ~hilo_en && hilo_relate)
       temp[0] <= mem_hilo_we==2'b11 ?  mem_hilo_data[31:0]:mem_wdata;
     else if(hilo_we_rf[1] && ~hilo_we[1] && hilo_en_rf && ~hilo_en && hilo_relate)
       temp[0] <= hilo_we_rf==2'b11 ? hi_rdata:wdata;
     else if(hilo_we_rf[0] && ~hilo_we[0] && hilo_en_rf && ~hilo_en && hilo_relate)
       temp[0] <= hilo_we_rf==2'b11 ? lo_rdata:wdata;
     else if (~hilo_we[0] && ~hilo_en && hilo_relate)
       temp[0] <= hilo_reg[0];  
     else if (~hilo_we[1] && ~hilo_en && hilo_relate)
       temp[0] <= hilo_reg[1];
     else
       temp[0] <= 32'b0;
    end
    assign rdata1 = temp[0];
    // read out2
    //assign rdata2 = (raddr2 == 5'b0) ? 32'b0 : reg_array[raddr2];
    always @ (*) begin
     if((ex_we ==1'b1) && (raddr2 ==ex_waddr))
       temp[1] <= ex_wdata;
     else if((mem_we == 1'b1) && (raddr2 ==mem_waddr))
       temp[1] <= mem_wdata;
     else if((we ==1'b1) && (raddr2 == waddr))
       temp[1] <= wdata;
     else if (raddr2 !=5'b0)
       temp[1] <=reg_array[raddr2];
     else
       temp[1] <=32'b0;
    end
    assign rdata2 = temp[1];
endmodule