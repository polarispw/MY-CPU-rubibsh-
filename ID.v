`include "lib/defines.vh"
module ID(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,
    
    output wire stallreq,
    
    output wire [31:0] new_pc,
    
    input wire [`IF_TO_ID_WD-1:0] if_to_id_bus,

    input wire [31:0] inst_sram_rdata,

    input wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,
    
    input wire [65:0] mul_div_to_rf,
    
    input wire [105:0] ex_to_id_bus,
    
    input wire [104:0] mem_to_id_bus,

    output wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,
    
    output wire [6:0] mul_div_to_ex,

    output wire [`BR_WD-1:0] br_bus 
);

    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r;
    wire [31:0] inst;
    wire [31:0] id_pc;
    wire ce;

    wire wb_rf_we;
    wire [4:0] wb_rf_waddr;
    wire [31:0] wb_rf_wdata;
    
    wire [31:0] hi_rdata;
    wire [31:0] lo_rdata;
    wire [1:0] hilo_we_rf;
    wire hilo_en_rf;

    always @ (posedge clk) begin
        if (rst) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;        
        end
        // else if (flush) begin
        //     ic_to_id_bus <= `IC_TO_ID_WD'b0;
        // end
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
        end
        else if (stall[1]==`NoStop) begin
            if_to_id_bus_r <= if_to_id_bus;
        end
    end
    
    assign inst = inst_sram_rdata;
    assign {
        ce,
        id_pc
    } = if_to_id_bus_r;
    
    assign {
        wb_rf_we,
        wb_rf_waddr,
        wb_rf_wdata
    } = wb_to_rf_bus;
    
    assign {
        hi_rdata,
        lo_rdata,
        hilo_we_rf,
        hilo_en_rf
    } = mul_div_to_rf;
    
    wire ex_rf_we;
    wire [1:0] ex_hilo_we;
    wire ex_hilo_en;
    wire [4:0] ex_rf_waddr;
    wire [31:0] ex_result;
    wire ex_data_sram_en;
    wire [63:0] ex_hilo_data;
    wire mem_rf_we;
    wire [1:0] mem_hilo_we;
    wire mem_hilo_en;
    wire [4:0] mem_rf_waddr;
    wire [31:0] mem_rf_wdata;
    wire [63:0] mem_hilo_data;
    assign {
        ex_hilo_en,
        ex_hilo_data,
        ex_hilo_we,//39.40
        ex_data_sram_en,   // 38
        ex_rf_we,          // 37
        ex_rf_waddr,       // 36:32
        ex_result       // 31:0
    }=ex_to_id_bus;
    assign {
        mem_hilo_en,
        mem_hilo_data,
        mem_hilo_we,//38.39
        mem_rf_we,          // 37
        mem_rf_waddr,       // 36:32
        mem_rf_wdata       // 31:0
    }=mem_to_id_bus;
    
    wire [5:0] opcode;
    wire [4:0] rs,rt,rd,sa;
    wire [5:0] func;
    wire [15:0] imm;
    wire [25:0] instr_index;
    wire [19:0] code;
    wire [4:0] base;
    wire [15:0] offset;
    wire [2:0] sel;

    wire [63:0] op_d, func_d;
    wire [31:0] rs_d, rt_d, rd_d, sa_d;

    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire [11:0] alu_op;

    wire data_ram_en;
    wire [3:0] data_ram_wen;
    
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [2:0] sel_rf_dst;
    wire [31:0] rdata1, rdata2;
    wire [1:0] hilo_we;//1write 0read
    wire hilo_en;
    wire hilo_relate;
    regfile u_regfile(
    	.clk    (clk    ),
    	.ex_we (ex_rf_we),
    	.ex_hilo_we(ex_hilo_we),
    	.ex_hilo_en(ex_hilo_en),
    	.ex_hilo_data(ex_hilo_data),
    	.ex_waddr(ex_rf_waddr),
        .ex_wdata(ex_result),   
    	.mem_we (mem_rf_we),
    	.mem_hilo_we(mem_hilo_we),
    	.mem_hilo_en(mem_hilo_en),
    	.mem_hilo_data(mem_hilo_data),
    	.mem_waddr (mem_rf_waddr),
    	.mem_wdata (mem_rf_wdata),
        .raddr1 (rs ),
        .rdata1 (rdata1 ),
        .raddr2 (rt ),
        .rdata2 (rdata2 ),
        .hilo_we(hilo_we      ),
        .hilo_en(hilo_en      ),
        .hilo_relate(hilo_relate),
        .we     (wb_rf_we     ),
        .waddr  (wb_rf_waddr  ),
        .wdata  (wb_rf_wdata  ),
        .hi_rdata(hi_rdata    ),
        .lo_rdata(lo_rdata    ),
        .hilo_we_rf(hilo_we_rf),
        .hilo_en_rf(hilo_en_rf)
    );

    assign opcode = inst[31:26];
    assign rs = inst[25:21];
    assign rt = inst[20:16];
    assign rd = inst[15:11];
    assign sa = inst[10:6];
    assign func = inst[5:0];
    assign imm = inst[15:0];
    assign instr_index = inst[25:0];
    assign code = inst[25:6];
    assign base = inst[25:21];
    assign offset = inst[15:0];
    assign sel = inst[2:0];

    wire inst_ori, inst_lui, inst_addiu, inst_beq,
          inst_addu, inst_subu, inst_jr, inst_jal, 
          inst_sll, inst_or, inst_sw, inst_lw,
          inst_xor, inst_sltu, inst_bne, inst_slt,
          inst_slti, inst_j, inst_add, inst_addi,
          int_sub, inst_and, inst_andi, inst_nor,
          inst_xori, inst_sllv, inst_sra, inst_srav,
          inst_bgez, inst_bgtz, inst_blez, inst_bltz,
          inst_bltzal, inst_bgezal, inst_jalr,
          inst_div, inst_divu, inst_mult, inst_multu,
          inst_mfhi, inst_mflo, inst_mthi, inst_mtlo,
          inst_lb, inst_lbu, inst_lh, inst_lhu,
          inst_sb, inst_sh;

    wire op_add, op_sub, op_slt, op_sltu;
    wire op_and, op_nor, op_or, op_xor;
    wire op_sll, op_srl, op_sra, op_lui;

    decoder_6_64 u0_decoder_6_64(
    	.in  (opcode  ),
        .out (op_d )
    );

    decoder_6_64 u1_decoder_6_64(
    	.in  (func  ),
        .out (func_d )
    );
    
    decoder_5_32 u0_decoder_5_32(
    	.in  (rs  ),
        .out (rs_d )
    );

    decoder_5_32 u1_decoder_5_32(
    	.in  (rt  ),
        .out (rt_d )
    );
    
    assign inst_ori     = op_d[6'b00_1101];
    assign inst_lui     = op_d[6'b00_1111];
    assign inst_addiu   = op_d[6'b00_1001];
    assign inst_beq     = op_d[6'b00_0100];
    assign inst_subu    = op_d[6'b00_0000]&func_d[6'b10_0011];
    assign inst_j       = op_d[6'b00_0010];
    assign inst_jr      = op_d[6'b00_0000]&func_d[6'b00_1000];
    assign inst_jal     = op_d[6'b00_0011];
    assign inst_addu    = op_d[6'b00_0000]&func_d[6'b10_0001];
    assign inst_sll     = op_d[6'b00_0000]&func_d[6'b00_0000];
    assign inst_or      = op_d[6'b00_0000]&func_d[6'b10_0101];
    assign inst_xor     = op_d[6'b00_0000]&func_d[6'b10_0110];
    assign inst_sltu    = op_d[6'b00_0000]&func_d[6'b10_1011];
    assign inst_sltiu   = op_d[6'b00_1011];
    assign inst_bne     = op_d[6'b00_0101];
    assign inst_slt     = op_d[6'b00_0000]&func_d[6'b10_1010];
    assign inst_slti    = op_d[6'b00_1010];
    assign inst_add     = op_d[6'b00_0000]&func_d[6'b10_0000];
    assign inst_addi    = op_d[6'b00_1000];
    assign inst_sub     = op_d[6'b00_0000]&func_d[6'b10_0010];
    assign inst_and     = op_d[6'b00_0000]&func_d[6'b10_0100];
    assign inst_andi    = op_d[6'b00_1100];
    assign inst_nor     = op_d[6'b00_0000]&func_d[6'b10_0111];
    assign inst_xori    = op_d[6'b00_1110];
    assign inst_sllv    = op_d[6'b00_0000]&func_d[6'b00_0100];
    assign inst_sra     = op_d[6'b00_0000]&func_d[6'b00_0011];
    assign inst_srav    = op_d[6'b00_0000]&func_d[6'b00_0111];
    assign inst_srl     = op_d[6'b00_0000]&func_d[6'b00_0010];
    assign inst_srlv    = op_d[6'b00_0000]&func_d[6'b00_0110];
    assign inst_bgez    = op_d[6'b00_0001]&rt_d[5'b00_001];
    assign inst_bgtz    = op_d[6'b00_0111]&rt_d[5'b00_000];
    assign inst_blez    = op_d[6'b00_0110]&rt_d[5'b00_000];
    assign inst_bltz    = op_d[6'b00_0001]&rt_d[5'b00_000];
    assign inst_bltzal  = op_d[6'b00_0001]&rt_d[5'b10_000];
    assign inst_bgezal  = op_d[6'b00_0001]&rt_d[5'b10_001];
    assign inst_jalr    = op_d[6'b00_0000]&func_d[6'b00_1001];
    assign inst_div     = op_d[6'b00_0000]&func_d[6'b01_1010];
    assign inst_divu    = op_d[6'b00_0000]&func_d[6'b01_1011];
    assign inst_mult    = op_d[6'b00_0000]&func_d[6'b01_1000];
    assign inst_multu   = op_d[6'b00_0000]&func_d[6'b01_1001];
    assign inst_mfhi    = op_d[6'b00_0000]&func_d[6'b01_0000];
    assign inst_mflo    = op_d[6'b00_0000]&func_d[6'b01_0010];
    assign inst_mthi    = op_d[6'b00_0000]&func_d[6'b01_0001];
    assign inst_mtlo    = op_d[6'b00_0000]&func_d[6'b01_0011];
    assign inst_lb      = op_d[6'b10_0000];
    assign inst_lbu     = op_d[6'b10_0100];
    assign inst_lh      = op_d[6'b10_0001];
    assign inst_lhu     = op_d[6'b10_0101];
    assign inst_sb      = op_d[6'b10_1000];
    assign inst_sh      = op_d[6'b10_1001];
    assign inst_sw      = op_d[6'b10_1011];
    assign inst_lw      = op_d[6'b10_0011];
   // rs(base) to reg1
    assign sel_alu_src1[0] = inst_ori | inst_addiu | inst_subu | inst_addu | inst_or | inst_sw | inst_lw | inst_xor | inst_sltu | inst_slt 
                           | inst_slti | inst_sltiu | inst_bne | inst_beq | inst_add | inst_addi | inst_sub | inst_and | inst_andi | inst_nor
                           | inst_xori | inst_sllv | inst_srav | inst_srlv | inst_jalr | inst_div | inst_divu | inst_mult | inst_multu
                           | inst_mfhi | inst_mflo | inst_mthi | inst_mtlo | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sb | inst_sh;

    // pc to reg1
    assign sel_alu_src1[1] = 1'b0;

    // sa_zero_extend to reg1
    assign sel_alu_src1[2] = inst_sll | inst_sra | inst_srl ;

    
    // rt to reg2
    assign sel_alu_src2[0] = inst_subu | inst_addu | inst_sll | inst_or | inst_xor | inst_sltu | inst_slt | inst_bne | inst_beq 
                           | inst_add | inst_sub | inst_and | inst_nor | inst_sllv | inst_sra | inst_srav | inst_srl | inst_srlv 
                           | inst_div | inst_divu | inst_mult | inst_multu;
    
    // imm_sign_extend to reg2
    assign sel_alu_src2[1] = inst_lui | inst_addiu | inst_sw | inst_lw | inst_slti | inst_sltiu | inst_addi | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sb | inst_sh;

    // 32'b8 to reg2
    assign sel_alu_src2[2] = 1'b0;

    // imm_zero_extend to reg2
    assign sel_alu_src2[3] = inst_ori | inst_andi | inst_xori;

    assign op_add = inst_addiu | inst_sw | inst_jal | inst_addu | inst_sw | inst_lw | inst_add | inst_addi | inst_bltzal | inst_bgezal | inst_jalr 
                  | inst_mfhi | inst_mflo | inst_mthi | inst_mtlo | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sb | inst_sh;
    assign op_sub = inst_subu | inst_sub;
    assign op_slt = inst_slt | inst_slti;
    assign op_sltu = inst_sltu | inst_sltiu;
    assign op_and = inst_and | inst_andi;
    assign op_nor = inst_nor;
    assign op_or = inst_ori | inst_or;
    assign op_xor = inst_xor | inst_xori;
    assign op_sll = inst_sll | inst_sllv;
    assign op_srl = inst_srl | inst_srlv;
    assign op_sra = inst_sra | inst_srav;
    assign op_lui = inst_lui;
    
    assign alu_op = {op_add, op_sub, op_slt, op_sltu,
                     op_and, op_nor, op_or, op_xor,
                     op_sll, op_srl, op_sra, op_lui};

    // load and store enable
    assign data_ram_en = inst_sw | inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sb | inst_sh;

    // write enable [s/l,signed/unsigned,2 bit?,4 bit?]
    assign data_ram_wen = inst_lb  ? 4'b0100 : 
                          inst_lbu ? 4'b0000 :
                          inst_lh  ? 4'b0110 :
                          inst_lhu ? 4'b0010 :
                          inst_lw  ? 4'b0101 :
                          inst_sb  ? 4'b1100 :
                          inst_sh  ? 4'b1110 :
                          inst_sw  ? 4'b1101 : 4'b0;

    // regfile store enable
    assign rf_we = inst_ori | inst_lui | inst_addiu | inst_subu | inst_jal | inst_addu | inst_sll | inst_or | inst_lw | inst_xor 
                 | inst_sltu | inst_slt | inst_slti | inst_sltiu | inst_add | inst_addi | inst_sub | inst_and | inst_andi
                 | inst_nor | inst_xori | inst_sllv | inst_sra | inst_srav | inst_srl | inst_srlv | inst_bltzal | inst_bgezal
                 | inst_jalr | inst_mfhi | inst_mflo | inst_lb | inst_lbu | inst_lh | inst_lhu; 

    // store in [rd]
    assign sel_rf_dst[0] = inst_subu | inst_addu | inst_sll | inst_or | inst_xor | inst_sltu | inst_slt | inst_add | inst_sub | inst_and 
                         | inst_nor | inst_sllv | inst_sra | inst_srav | inst_srl | inst_srlv | inst_jalr | inst_mfhi | inst_mflo;
    // store in [rt] 
    assign sel_rf_dst[1] = inst_ori | inst_lui | inst_addiu | inst_lw | inst_slti | inst_sltiu | inst_addi | inst_andi | inst_xori | inst_lb | inst_lbu | inst_lh | inst_lhu;
    // store in [31]
    assign sel_rf_dst[2] = inst_jal | inst_bltzal | inst_bgezal;

    // sel for regfile address
    assign rf_waddr = {5{sel_rf_dst[0]}} & rd 
                    | {5{sel_rf_dst[1]}} & rt
                    | {5{sel_rf_dst[2]}} & 32'd31;

     //mul_div inst
     wire [3:0] mul_div_inst_onehot;
     assign mul_div_inst_onehot = inst_div ? 4'b1000 :
                                  inst_divu ? 4'b0100 :
                                  inst_mult ? 4'b0010 :
                                  inst_multu ? 4'b0001 :
                                  inst_mfhi ? 4'b1001 :
                                  inst_mflo ? 4'b0110 :
                                  inst_mthi ? 4'b1010 :
                                  inst_mtlo ? 4'b0101 : 4'b0000;
    // hilo store enable
    assign hilo_we = inst_div | inst_divu | inst_mult | inst_multu ? 2'b11 : 
                     inst_mthi ? 2'b10 :
                     inst_mtlo ? 2'b01 : 
                     inst_mfhi ? 2'b01 :
                     inst_mflo ? 2'b10 : 2'b00;
    assign hilo_en = inst_div | inst_divu | inst_mult | inst_multu | inst_mthi | inst_mtlo ;//1 write enable
    assign hilo_relate=inst_mfhi | inst_mflo;
    assign mul_div_to_ex={ mul_div_inst_onehot, hilo_we, hilo_en};
    
    // 0 from alu_res ; 1 from ld_res
    assign sel_rf_res = 1'b0; 
    
    //for dalayslot next pc
    wire [31:0] valid_rdata1,valid_rdata2;
    assign valid_rdata1 = (inst_jal | inst_bltzal | inst_bgezal | inst_jalr) ? id_pc+32'h8 : rdata1;
    assign valid_rdata2 = (inst_jal | inst_bltzal | inst_bgezal | inst_jalr | inst_mfhi | inst_mflo| inst_mthi | inst_mtlo) ? 32'b0 : rdata2;
    
    assign id_to_ex_bus = {
        id_pc,          // 158:127
        inst,           // 126:95
        alu_op,         // 94:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        valid_rdata1,         // 63:32 ����������
        valid_rdata2          // 31:0
    };
    
    //stall control
    
    assign stallreq = ((ex_rf_waddr==rs) & (sel_alu_src1[0]==1) & ex_data_sram_en) ? 1:
                      ((ex_rf_waddr==rt) & (sel_alu_src2[0]==1) & ex_data_sram_en) ? 1:0;
    assign new_pc = ((ex_rf_waddr==rs) & (sel_alu_src1[0]==1) & ex_data_sram_en) ? id_pc:
                      ((ex_rf_waddr==rt) & (sel_alu_src2[0]==1) & ex_data_sram_en) ? id_pc:0;
    
    wire br_e;
    wire [31:0] br_addr;
    wire rs_eq_rt;
    wire rs_ge_z;
    wire rs_gt_z;
    wire rs_le_z;
    wire rs_lt_z;
    wire [31:0] pc_plus_4;
    assign pc_plus_4 = id_pc + 32'h4;

    assign rs_eq_rt = (rdata1 == rdata2);
    assign rs_ge_z = (rdata1[31]==0);
    assign rs_gt_z = (rdata1>32'h0 & rdata1[31]!=1);
    assign rs_le_z = (rdata1==32'h0 | rdata1[31]==1);
    assign rs_lt_z = (rdata1[31]==1);
    assign br_e = (inst_beq & rs_eq_rt) | (inst_bne & ~rs_eq_rt) | inst_jr | inst_jal | inst_j | inst_jalr
                | (inst_bgez & rs_ge_z) | (inst_bgtz & rs_gt_z) | (inst_blez & rs_le_z) | (inst_bltz & rs_lt_z)
                | (inst_bltzal & rs_lt_z)| (inst_bgezal & rs_ge_z);           //是否跳转
    assign br_addr = inst_beq ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :          //跳转地址
                     inst_bne ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :
                     inst_jal ? ({pc_plus_4[31:28],inst[25:0],2'b0}) :
                     inst_j   ? ({pc_plus_4[31:28],inst[25:0],2'b0}) :
                     inst_jr ? rdata1 :
                     inst_bgez ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :
                     inst_bgtz ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :
                     inst_blez ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :
                     inst_bltz ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :
                     inst_bltzal ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :
                     inst_bgezal ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :
                     inst_jalr ? rdata1 : 32'b0;

    assign br_bus = {
        br_e,
        br_addr
    };
    


endmodule