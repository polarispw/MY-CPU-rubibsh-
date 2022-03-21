`include "lib/defines.vh"
module MEM(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,
    input wire [70:0] mul_div_to_mem,
    input wire [31:0] data_sram_rdata,
    output wire [104:0] mem_to_id_bus,
    output wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,
    output wire [66:0] mul_div_to_wb
);

    reg [`EX_TO_MEM_WD-1:0] ex_to_mem_bus_r;
    reg [70:0] mul_div_to_mem_r;
    always @ (posedge clk) begin
        if (rst) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
            mul_div_to_mem_r<= 71'b0;
        end
        // else if (flush) begin
        //     ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        // end
        else if (stall[3]==`Stop && stall[4]==`NoStop) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
            mul_div_to_mem_r<= 71'b0;
        end
        else if (stall[3]==`NoStop) begin
            ex_to_mem_bus_r <= ex_to_mem_bus;
            mul_div_to_mem_r<=mul_div_to_mem;
        end
    end

    wire [31:0] mem_pc;
    wire data_ram_en;
    wire [3:0] data_ram_wen;
    wire sel_rf_res;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire [31:0] rf_wdata;
    wire [31:0] ex_result;
    wire [31:0] mem_result;

    assign {
        mem_pc,         // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    } =  ex_to_mem_bus_r;
    
    wire [31:0] hi_rdata;
    wire [31:0] lo_rdata;
    wire [3:0] inst_md;
    wire hi_we;
    wire lo_we;
    wire hilo_en;
    assign {
        hi_rdata,
        lo_rdata,
        inst_md,
        hi_we,   
        lo_we,
        hilo_en  
    } = mul_div_to_mem_r;

    //load from ram
    wire inst_lb, inst_lbu, inst_lh, inst_lhu,  inst_lw;
    assign inst_lb  = data_ram_wen == 4'b0100 ? 1:0; 
    assign inst_lbu = data_ram_wen == 4'b0000 ? 1:0;
    assign inst_lh  = data_ram_wen == 4'b0110 ? 1:0;
    assign inst_lhu = data_ram_wen == 4'b0010 ? 1:0;
    assign inst_lw  = data_ram_wen == 4'b0101 ? 1:0;
    wire [31:0] byte_ram_data;
    wire [31:0] half_ram_data;
    assign byte_ram_data = inst_lb  && ex_result[1:0]==2'b00 ? {{24{data_sram_rdata[7]}},data_sram_rdata[7:0]}:
                           inst_lb  && ex_result[1:0]==2'b01 ? {{24{data_sram_rdata[15]}},data_sram_rdata[15:8]}:
                           inst_lb  && ex_result[1:0]==2'b10 ? {{24{data_sram_rdata[23]}},data_sram_rdata[23:16]}:
                           inst_lb  && ex_result[1:0]==2'b11 ? {{24{data_sram_rdata[31]}},data_sram_rdata[31:24]}:
                           inst_lbu && ex_result[1:0]==2'b00 ? {24'b0,data_sram_rdata[7:0]}:
                           inst_lbu && ex_result[1:0]==2'b01 ? {24'b0,data_sram_rdata[15:8]}:
                           inst_lbu && ex_result[1:0]==2'b10 ? {24'b0,data_sram_rdata[23:16]}:
                           inst_lbu && ex_result[1:0]==2'b11 ? {24'b0,data_sram_rdata[31:24]}: 32'b0;
    assign half_ram_data = inst_lh  && ex_result[1:0]==2'b00 ? {{16{data_sram_rdata[15]}},data_sram_rdata[15:0]}:
                           inst_lh  && ex_result[1:0]==2'b10 ? {{16{data_sram_rdata[31]}},data_sram_rdata[31:16]}:
                           inst_lhu && ex_result[1:0]==2'b00 ? {16'b0,data_sram_rdata[15:0]}:
                           inst_lhu && ex_result[1:0]==2'b10 ? {16'b0,data_sram_rdata[31:16]}: 32'b0;
    assign rf_wdata = sel_rf_res ? mem_result :
                      data_ram_en && inst_lw ? data_sram_rdata : 
                      data_ram_en && (inst_lb | inst_lbu) ? byte_ram_data:
                      data_ram_en && (inst_lh | inst_lhu) ? half_ram_data: ex_result;

    assign mem_to_wb_bus = {
        mem_pc,     // 41:38
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata    // 31:0
    };
    
    assign mul_div_to_wb = {
        hilo_en,
        hi_rdata,
        lo_rdata,
        hi_we,
        lo_we
    };

    assign mem_to_id_bus = {
        hilo_en,
        hi_rdata,
        lo_rdata,
        hi_we,
        lo_we,
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata    // 31:0
    };
   
endmodule