module CPU(
    input wire clk,
    input wire reset
);

// Sinais de controle (UnidadeControle -> Datapath)
wire [2:0] PCSource;
wire WritePC;
wire PcWriteCond;
wire [2:0] IorD;
wire Wr;
wire IRWrite;
wire [1:0] RegDst;
wire [3:0] MenToReg;
wire RegWrite;
wire AWrite;
wire BWrite;
wire ALUSrcA;
wire [1:0] ALUSrcB;
wire [2:0] ALUControl_out;
wire ALUOutWrite;
wire WriteEPC;
wire WriteMDR;
wire set_type_MD;
wire startMD;
wire WriteHigh;
wire WriteLow;
wire Read1Sel;
wire Read2Sel;
wire ShiftIN;
wire [1:0] ErrorType;
wire [2:0] ShiftType;
wire [1:0] ShiftAmount;
wire [1:0] MenWriteSrc;

// Sinais de status (Datapath -> UnidadeControle)
wire [5:0] IR_31_26;
wire [5:0] Funct;
wire Overflow_out;
wire div_zero_MD;
wire ready_MD;

Datapath datapath(
    .clk(clk),
    .reset(reset),
    .PCSource(PCSource),
    .WritePC(WritePC),
    .PcWriteCond(PcWriteCond),
    .IorD(IorD),
    .Wr(Wr),
    .IRWrite(IRWrite),
    .RegDst(RegDst),
    .MenToReg(MenToReg),
    .RegWrite(RegWrite),
    .AWrite(AWrite),
    .BWrite(BWrite),
    .ALUSrcA(ALUSrcA),
    .ALUSrcB(ALUSrcB),
    .ALUControl_out(ALUControl_out),
    .ALUOutWrite(ALUOutWrite),
    .WriteEPC(WriteEPC),
    .WriteMDR(WriteMDR),
    .set_type_MD(set_type_MD),
    .startMD(startMD),
    .WriteHigh(WriteHigh),
    .WriteLow(WriteLow),
    .Read1Sel(Read1Sel),
    .Read2Sel(Read2Sel),
    .ShiftIN(ShiftIN),
    .ErrorType(ErrorType),
    .ShiftType(ShiftType),
    .ShiftAmount(ShiftAmount),
    .MenWriteSrc(MenWriteSrc),
    .IR_31_26(IR_31_26),
    .Funct(Funct),
    .Overflow_out(Overflow_out),
    .div_zero_MD(div_zero_MD),
    .ready_MD(ready_MD)
);

UnidadeControle uc(
    .clk(clk),
    .rst(reset),
    .Opcode(IR_31_26),
    .Funct(Funct),
    .overflow(Overflow_out),
    .div_zero(div_zero_MD),
    .ready(ready_MD),
    .start(startMD),
    .set_type(set_type_MD),
    .Write_High(WriteHigh),
    .Write_Low(WriteLow),
    .Read1Sel(Read1Sel),
    .Read2Sel(Read2Sel),
    .ShiftIN(ShiftIN),
    .EPCWrite(WriteEPC),
    .ShiftAmount(ShiftAmount),
    .ShiftType(ShiftType),
    .IorD(IorD),
    .Wr(Wr),
    .AluSrcA(ALUSrcA),
    .AluSrcB(ALUSrcB),
    .AluOp(ALUControl_out),
    .PCSource(PCSource),
    .PCWrite(WritePC),
    .IRWrite(IRWrite),
    .AWrite(AWrite),
    .BWrite(BWrite),
    .ALUOutWrite(ALUOutWrite),
    .WriteMDR(WriteMDR),
    .RegDst(RegDst),
    .MenToReg(MenToReg),
    .RegWrite(RegWrite),
    .MenWriteSrc(MenWriteSrc),
    .ErrorType(ErrorType),
    .PCWriteCond(PcWriteCond)
);

endmodule
