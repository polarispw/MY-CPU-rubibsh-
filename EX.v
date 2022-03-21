`include "lib/defines.vh"
module EX(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,
    input wire [6:0] mul_div_to_ex,
    output wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,
    output wire [70:0] mul_div_to_mem,
    output wire [105:0] ex_to_id_bus,
    output wire stallreq_for_ex,
    
    output wire data_sram_en,
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata
);

    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;
    reg [6:0] mul_div_to_ex_r;
    always @ (posedge clk) begin
        if (rst) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
            mul_div_to_ex_r<= 6'b0;
        end
        // else if (flush) begin
        //     id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        // end
        else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
            mul_div_to_ex_r<= 6'b0;
        end
        else if (stall[2]==`NoStop) begin
            id_to_ex_bus_r <= id_to_ex_bus;
            mul_div_to_ex_r<=mul_div_to_ex;
        end
    end

    wire [31:0] ex_pc, inst;
    wire [11:0] alu_op;
    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire data_ram_en;
    wire [3:0] data_ram_wen;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [31:0] rf_rdata1, rf_rdata2;
    reg is_in_delayslot;

    assign {
        ex_pc,          // 148:117
        inst,           // 116:85
        alu_op,         // 84:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rf_rdata1,         // 63:32
        rf_rdata2          // 31:0
    } = id_to_ex_bus_r;

    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend;
    assign imm_sign_extend = {{16{inst[15]}},inst[15:0]};
    assign imm_zero_extend = {16'b0, inst[15:0]};
    assign sa_zero_extend = {27'b0,inst[10:6]};

    wire [31:0] alu_src1, alu_src2;
    wire [31:0] alu_result, ex_result;

    assign alu_src1 = sel_alu_src1[1] ? ex_pc :
                      sel_alu_src1[2] ? sa_zero_extend : rf_rdata1;

    assign alu_src2 = sel_alu_src2[1] ? imm_sign_extend :
                      sel_alu_src2[2] ? 32'd8 :
                      sel_alu_src2[3] ? imm_zero_extend : rf_rdata2;
    
    alu u_alu(
    	.alu_control (alu_op ),
        .alu_src1    (alu_src1    ),
        .alu_src2    (alu_src2    ),
        .alu_result  (alu_result  )
    );
    
    assign ex_result = alu_result;
    
    //ram
    wire inst_sb, inst_sh, inst_sw;
    assign inst_sb  = data_ram_wen == 4'b1100 ? 1:0;
    assign inst_sh  = data_ram_wen == 4'b1110 ? 1:0;
    assign inst_sw  = data_ram_wen == 4'b1101 ? 1:0;
    
    assign data_sram_en=data_ram_en;
    assign data_sram_wen= inst_sw ? 4'b1111:
                          inst_sh && ex_result[1:0]==2'b00 ? 4'b0011:
                          inst_sh && ex_result[1:0]==2'b10 ? 4'b1100:
                          inst_sb && ex_result[1:0]==2'b00 ? 4'b0001:
                          inst_sb && ex_result[1:0]==2'b01 ? 4'b0010:
                          inst_sb && ex_result[1:0]==2'b10 ? 4'b0100:
                          inst_sb && ex_result[1:0]==2'b11 ? 4'b1000: 4'b0;
    assign data_sram_addr=alu_result;
    assign data_sram_wdata = inst_sh && ex_result[1:0]==2'b10 ? {rf_rdata2[15:0],16'b0}:
                             inst_sb && ex_result[1:0]==2'b01 ? {16'b0,rf_rdata2[7:0],8'b0}:
                             inst_sb && ex_result[1:0]==2'b10 ? {8'b0,rf_rdata2[7:0],16'b0}:
                             inst_sb && ex_result[1:0]==2'b11 ? {rf_rdata2[7:0],24'b0}: rf_rdata2;
    
    assign ex_to_mem_bus = {
        ex_pc,          // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    };
    
    wire inst_mfhi,inst_mflo,inst_mthi,inst_mtlo;
    assign inst_mfhi = mul_div_to_ex_r[6:3]==4'b1001 ? 1:0;
    assign inst_mflo = mul_div_to_ex_r[6:3]==4'b0110 ? 1:0;
    assign inst_mthi = mul_div_to_ex_r[6:3]==4'b1010 ? 1:0;
    assign inst_mtlo = mul_div_to_ex_r[6:3]==4'b0101 ? 1:0;
    
    // MUL part
    wire [63:0] mul_result;
    //wire mul_signed; // 有符号乘法标记
    wire inst_mul,inst_mulu;
    assign inst_mult = mul_div_to_ex_r[6:3]==4'b0010 ? 1:0;
    assign inst_multu = mul_div_to_ex_r[6:3]==4'b0001 ? 1:0;
    mul u_mul(
    	.clk        (clk            ),
        .resetn     (~rst           ),
        .mul_signed (inst_mult      ),
        .ina        (rf_rdata1      ), // 乘法源操作数1
        .inb        (rf_rdata2      ), // 乘法源操作数2
        .result     (mul_result     ) // 乘法结果 64bit
    );

    // DIV part
    wire [63:0] div_result;
    wire inst_div, inst_divu;
    wire div_ready_i;
    reg stallreq_for_div;
    
    assign stallreq_for_ex = stallreq_for_div;
    assign inst_div = mul_div_to_ex_r[6:3]==4'b1000 ? 1:0;
    assign inst_divu = mul_div_to_ex_r[6:3]==4'b0100 ? 1:0;
    reg [31:0] div_opdata1_o;
    reg [31:0] div_opdata2_o;
    reg div_start_o;
    reg signed_div_o;

    div u_div(
    	.rst          (rst          ),
        .clk          (clk          ),
        .signed_div_i (signed_div_o ),
        .opdata1_i    (div_opdata1_o    ),
        .opdata2_i    (div_opdata2_o    ),
        .start_i      (div_start_o      ),
        .annul_i      (1'b0      ),
        .result_o     (div_result     ), // 除法结果 64bit
        .ready_o      (div_ready_i      )
    );
    
    assign mul_div_to_mem= ( inst_mult | inst_multu ) ? {mul_result,mul_div_to_ex_r} :
                           ( inst_div | inst_divu ) ? {div_result,mul_div_to_ex_r} : {64'b0,mul_div_to_ex_r};
    
    always @ (*) begin
        if (rst) begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
        end
        else begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
            case ({inst_div,inst_divu})
                2'b10:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                2'b01:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                default:begin
                end
            endcase
        end
    end
    
    //forwarding
    wire [1:0] ex_hilo_we;
    wire ex_hilo_en;
    wire ex_data_sram_en;
    wire ex_rf_we;
    wire [4:0] ex_rf_waddr;
    wire [63:0] ex_hilo_data;
    assign ex_hilo_we=mul_div_to_ex_r[2:1];
    assign ex_hilo_en=mul_div_to_ex_r[0];
    assign ex_data_sram_en=data_ram_en;
    assign ex_rf_we = rf_we;
    assign ex_rf_waddr = rf_waddr;
    assign ex_hilo_data =  ( inst_mult | inst_multu ) ? mul_result :
                           ( inst_div | inst_divu ) ? div_result : 64'b0;
    assign ex_to_id_bus = {
        ex_hilo_en,
        ex_hilo_data,
        ex_hilo_we,
        ex_data_sram_en,   // 38
        ex_rf_we,          // 37
        ex_rf_waddr,       // 36:32
        ex_result       // 31:0
    };
endmodule