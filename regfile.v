`include "defines.vh"
module regfile(
    input wire clk,
    input wire [4:0] raddr1,
    output wire [31:0] rdata1,
    input wire [4:0] raddr2,
    output wire [31:0] rdata2,
    
    input wire ex_we,
    input wire [4:0] ex_waddr,
    input wire [31:0] ex_wdata,
    input wire mem_we,
    input wire [4:0] mem_waddr,
    input wire [31:0] mem_wdata,
    input wire we,
    input wire [4:0] waddr,
    input wire [31:0] wdata
);
    reg [31:0] reg_array [31:0];
    // write
    always @ (posedge clk) begin
        if (we && waddr!=5'b0) begin
            reg_array[waddr] <= wdata;
        end
    end
    reg [31:0] temp;
    // read out 1
    assign rdata1 = (raddr1 == 5'b0) ? 32'b0 : reg_array[raddr1];
//    always @ (*) begin
//     if(ex_we && raddr1 ==ex_waddr) begin
//       temp<= ex_wdata;
//     end
//     if(mem_we && raddr1 ==mem_waddr) begin
//       temp<= mem_wdata;
//     end
//    end
//    assign radta1 = temp;
    // read out2
    assign rdata2 = (raddr2 == 5'b0) ? 32'b0 : reg_array[raddr2];
//    always @ (*) begin
//     if(ex_we && raddr2 ==ex_waddr) begin
//       temp<= ex_wdata;
//     end
//     if(mem_we && raddr2 ==mem_waddr) begin
//       temp<= mem_wdata;
//     end
//    end
//    assign radta1 = temp;
endmodule