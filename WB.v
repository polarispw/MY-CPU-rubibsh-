`include "lib/defines.vh"
module WB(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,
    input wire [66:0] mul_div_to_wb,
    output wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,
    output wire [66:0] mul_div_to_rf,
    output wire [31:0] debug_wb_pc,
    output wire [3:0] debug_wb_rf_wen,
    output wire [4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata 
);

    reg [`MEM_TO_WB_WD-1:0] mem_to_wb_bus_r;
    reg [66:0] mul_div_to_wb_r;
    always @ (posedge clk) begin
        if (rst) begin
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;
            mul_div_to_wb_r <= 66'b0; 
        end
        // else if (flush) begin
        //     mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;
        // end
        else if (stall[4]==`Stop && stall[5]==`NoStop) begin
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;
            mul_div_to_wb_r <= 66'b0;
        end
        else if (stall[4]==`NoStop) begin
            mem_to_wb_bus_r <= mem_to_wb_bus;
            mul_div_to_wb_r <= mul_div_to_wb;
        end
    end

    wire [31:0] wb_pc;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire [31:0] rf_wdata;

    assign {
        wb_pc,
        rf_we,
        rf_waddr,
        rf_wdata
    } = mem_to_wb_bus_r;
    // assign wb_to_rf_bus = mem_to_wb_bus_r[`WB_TO_RF_WD-1:0];
    assign wb_to_rf_bus = {
        rf_we,
        rf_waddr,
        rf_wdata
    };
   
    wire [31:0] hi_rdata;
    wire [31:0] lo_rdata;
    wire hi_we;
    wire lo_we;
    wire hilo_en;
    assign {
        hilo_en,
        hi_rdata,
        lo_rdata,
        hi_we,   
        lo_we  
    } = mul_div_to_wb_r;
    
    assign mul_div_to_rf = {
        hi_rdata,
        lo_rdata,
        hi_we,
        lo_we,
        hilo_en
    };

    assign debug_wb_pc = wb_pc;
    assign debug_wb_rf_wen = {4{rf_we}};
    assign debug_wb_rf_wnum = rf_waddr;
    assign debug_wb_rf_wdata = rf_wdata;

    
endmodule