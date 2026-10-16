module UnidadeControle (

    input wire clk,
    input wire rst,
    input wire [5:0] Opcode, // IR[31-26]
    input wire [5:0] Funct,
    input wire overflow,      
    input wire div_zero,
    input wire ready,   
    
    // Sinais de Saída
    output reg start,          // Dispara o MultDiv
    output reg set_type,       // 1 para Mul, 0 para Div
    output reg Write_High,     // Escreve no registrador HI do Datapath
    output reg Write_Low,      // Escreve no registrador LO do Datapath
    output reg Read1Sel,       // Porta de leitura 1: 0 = rs, 1 = R29 (SP)
    output reg Read2Sel,       // Porta de leitura 2: 0 = rt, 1 = rs
    output reg ShiftIN,
    output reg EPCWrite,
    output reg [1:0] ShiftAmount,
    output reg [2:0] ShiftType, 
    output reg [2:0] IorD,
    output reg Wr,
    output reg AluSrcA,
    output reg [1:0] AluSrcB,
    output reg [2:0] AluOp,
    output reg [2:0] PCSource,
    output reg PCWrite,
    output reg IRWrite,
    output reg AWrite,
    output reg BWrite,
    output reg ALUOutWrite,
    output reg WriteMDR,
    output reg [1:0] RegDst,
    output reg [3:0] MenToReg, 
    output reg RegWrite,
    output reg [1:0] MenWriteSrc, 
    output reg [1:0] ErrorType,  
    output reg PCWriteCond
);

    typedef enum reg [6:0] {
        INIT_SP,
        FETCH_1, FETCH_2, FETCH_3,
        DECODE,
        LW_1, LW_2, LW_3, LW_4, LW_5,
        SW_1, SW_2, SW_3,
        BEQ_1,BEQ_2,BEQ_3,
        BNE_1,BNE_2,BNE_3,
        R_TYPE,
        AND_1,AND_2,AND_3,
        ADD_1,ADD_2,ADD_3,
        SUB_1,SUB_2,SUB_3,
        PUSH_1,PUSH_2,PUSH_3,
        POP_1,POP_2,POP_3,POP_4,POP_5,POP_6,
        SLT_1,SLT_2,
        SRA_1,SRA_2,SRA_3,SRA_4,
        SLL_1,SLL_2,SLL_3,SLL_4,
        MFLO_1,
        MFHI_1,
        JR_1,JR_2,
        LUI_1,LUI_2,LUI_3,
        LB_1,LB_2,LB_3,LB_4,LB_5,
        ADDI_1,ADDI_2,ADDI_3,
        SB_1,SB_2,SB_3,SB_4,SB_5,
        J_1,
        JAL_1,JAL_2,
        EXCEPTION_OVERFLOW,EXCEPTION_ZERO,EXCEPTION_OPCODE,EXCEPTION_2,EXCEPTION_3,EXCEPTION_4,EXCEPTION_WAIT, 
        MUL_1, DIV_1, MUL_2, DIV_2, ESPERA_MD, SALVA_MD,
        WAIT_LW,WAIT_LB,WAIT_SB
    } state_t;

    state_t state, next_state;

    reg [1:0] error_type_reg;

    // --- 1. Lógica de Transição de Estado (Sequencial) ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= INIT_SP;
            error_type_reg <= 2'b00;
        end
        else begin
            state <= next_state;

            // Seletor do mux_excecao: 00 = 253 (opcode), 01 = 254 (overflow), 10 = 255 (div/0)
            if (next_state == EXCEPTION_OPCODE)   error_type_reg <= 2'b00;
            if (next_state == EXCEPTION_OVERFLOW) error_type_reg <= 2'b01;
            if (next_state == EXCEPTION_ZERO)     error_type_reg <= 2'b10;
        end
    end

    // --- 2. Lógica do Próximo Estado (Combinacional) ---
    always @(*) begin
        case (state)
            // Inicializa o SP (R29 = 227) logo após o reset
            INIT_SP: next_state = FETCH_1;

            // Ciclo de Busca (PC+4)
            FETCH_1: next_state = FETCH_2;
            FETCH_2: next_state = FETCH_3;
            FETCH_3: next_state = DECODE;

            // Decodificação (Opcodes em Hexadecimal)
            DECODE: begin
                case (Opcode)
                    6'h23:   next_state = LW_1;
                    6'h2b:   next_state = SW_1;
                    6'h4:   next_state = BEQ_1;
                    6'h5:   next_state = BNE_1;
                    6'hf:   next_state = LUI_1;
                    6'h20:  next_state = LB_1;
                    6'h8:   next_state = ADDI_1;
                    6'h28:  next_state = SB_1;
                    6'h2:   next_state = J_1;
                    6'h3:   next_state = JAL_1;
                    6'h00: next_state = R_TYPE;
                    default: next_state = EXCEPTION_OPCODE;
                endcase
            end

            // Decodificação do Tipo R via Funct
            R_TYPE: begin
                case (Funct)
                    6'h20: next_state = ADD_1;
                    6'h24: next_state = AND_1;
                    6'h22: next_state = SUB_1;
                    6'h12: next_state = MFLO_1;
                    6'h10: next_state = MFHI_1;
                    6'h8: next_state = JR_1;
                    6'h5: next_state = PUSH_1;
                    6'h6: next_state = POP_1;
                    6'h2a: next_state = SLT_1;
                    6'h3: next_state = SRA_1;
                    6'h0: next_state = SLL_1;
                    6'h1a: next_state = DIV_1;
                    6'h18: next_state = MUL_1;
                    default: next_state = EXCEPTION_OPCODE;
                endcase
            end

            MUL_1: next_state = MUL_2;
            MUL_2: next_state = ESPERA_MD;
            DIV_1: next_state = DIV_2;
            DIV_2: next_state = ESPERA_MD;

            ESPERA_MD: begin
                if (div_zero) 
                    next_state = EXCEPTION_ZERO;
                else if (ready) 
                    next_state = SALVA_MD;
                else  
                    next_state = ESPERA_MD;
            end

            SALVA_MD: next_state = FETCH_1;
            
            SLT_1: next_state = SLT_2; SLT_2: next_state = FETCH_1;
            SRA_1: next_state = SRA_2;SRA_2: next_state = SRA_3;SRA_3: next_state = SRA_4;SRA_4: next_state = FETCH_1;
            SLL_1: next_state = SLL_2;SLL_2: next_state = SLL_3;SLL_3: next_state = SLL_4;SLL_4: next_state = FETCH_1;
            PUSH_1: next_state = PUSH_2; PUSH_2: next_state = PUSH_3; PUSH_3: next_state = FETCH_1;
            POP_1: next_state = POP_2; POP_2: next_state = POP_3; POP_3: next_state = POP_4;
            POP_4: next_state = POP_5; POP_5: next_state = POP_6; POP_6: next_state = FETCH_1;
            MFLO_1: next_state = FETCH_1;
            MFHI_1: next_state = FETCH_1;
            JR_1: next_state = JR_2; JR_2: next_state = FETCH_1;
            SUB_1: next_state = SUB_2;
            SUB_2: next_state = (overflow) ? EXCEPTION_OVERFLOW : SUB_3;
            SUB_3: next_state = FETCH_1;
            AND_1: next_state = AND_2;AND_2: next_state = AND_3;AND_3: next_state = FETCH_1;
            ADD_1: next_state = ADD_2;
            ADD_2: next_state = (overflow) ? EXCEPTION_OVERFLOW : ADD_3;
            ADD_3: next_state = FETCH_1;
            LW_1: next_state = LW_2; LW_2: next_state = LW_3; LW_3: next_state = WAIT_LW;WAIT_LW: next_state = LW_4; LW_4: next_state = LW_5; LW_5: next_state = FETCH_1;
            SW_1: next_state = SW_2; SW_2: next_state = SW_3;SW_3: next_state = FETCH_1;
            BEQ_1: next_state = BEQ_2;BEQ_2: next_state = FETCH_1;
            BNE_1: next_state = BNE_2;BNE_2: next_state = FETCH_1;
            LUI_1: next_state = LUI_2;LUI_2: next_state = LUI_3;LUI_3: next_state = FETCH_1;
            LB_1: next_state = LB_2;LB_2: next_state = LB_3;LB_3: next_state = WAIT_LB;WAIT_LB: next_state = LB_4;LB_4: next_state = LB_5;LB_5: next_state = FETCH_1;
            ADDI_1: next_state = ADDI_2;
            ADDI_2: next_state = (overflow) ? EXCEPTION_OVERFLOW : ADDI_3;
            ADDI_3: next_state = FETCH_1;
            SB_1: next_state = SB_2;SB_2: next_state = SB_3;SB_3: next_state = WAIT_SB;WAIT_SB: next_state = SB_4;SB_4: next_state = SB_5;SB_5: next_state = FETCH_1; 
            J_1: next_state = FETCH_1;
            JAL_1: next_state = JAL_2; JAL_2: next_state = FETCH_1;
            EXCEPTION_OVERFLOW: next_state = EXCEPTION_2; 
            EXCEPTION_ZERO: next_state = EXCEPTION_2; 
            EXCEPTION_OPCODE: next_state = EXCEPTION_2; 
            EXCEPTION_2: next_state = EXCEPTION_WAIT; 
            EXCEPTION_WAIT: next_state = EXCEPTION_3; EXCEPTION_3: next_state = EXCEPTION_4;EXCEPTION_4: next_state = FETCH_1;

            default: next_state = FETCH_1;
        endcase
    end

    // --- 3. Lógica de Saída (Combinacional) ---
    always @(*) begin
        // Reset padrão de todos os sinais (Evita latches)
        IorD = 3'b000; Wr = 0; AluSrcA = 0; AluSrcB = 2'b00;
        AluOp = 3'b000; PCSource = 3'b000; PCWrite = 0; IRWrite = 0;
        AWrite = 0; BWrite = 0; ALUOutWrite = 0; WriteMDR = 0;
        RegDst = 2'b00; MenToReg = 4'b0000; RegWrite = 0; MenWriteSrc = 2'b00; PCWriteCond=0;
        ShiftType = 3'b000; ShiftIN = 1'b0; ShiftAmount = 2'b00;
        start = 0; set_type = 0; Write_High = 0; Write_Low = 0;
        Read1Sel = 0; Read2Sel = 0; EPCWrite = 0; ErrorType = 2'b00;

        case (state)
            // --- INIT_SP: R29 <- 227 ---
            INIT_SP: begin
                RegDst = 2'b11; MenToReg = 4'b1000; RegWrite = 1;
            end

            // --- FETCH ---
            FETCH_1: begin
                IorD = 3'b000; Wr   = 0;
            end

            FETCH_2: begin
                AluSrcA = 0; AluSrcB = 2'b11; AluOp = 3'b001; PCSource = 3'b010; PCWrite  = 1;
            end

            FETCH_3: begin
                IRWrite = 1;
            end

            // --- DECODE ---
            DECODE: begin

            end

            MUL_1: begin
                AWrite = 1; BWrite = 1; set_type = 1;  // carrega A e B, NÃO dispara start
            end

            MUL_2: begin
                set_type = 1; start = 1;  // A e B já estão estáveis, dispara
            end

            DIV_1: begin
                AWrite = 1; BWrite = 1; set_type = 0;
            end

            DIV_2: begin
                set_type = 0; start = 1;
            end

            ESPERA_MD: begin
                if (Opcode == 6'h00 && Funct == 6'h1a) begin 
                    set_type = 0;
                end else begin
                    set_type = 1;
                end
            end

            SALVA_MD: begin
                Write_High = 1;
                Write_Low  = 1;
            end


            // --- LOAD WORD ---
            LW_1: AWrite = 1;

            LW_2: begin
                AluSrcA = 1; AluSrcB = 2'b01; AluOp = 3'b001; ALUOutWrite = 1;
            end

            LW_3: begin
                Wr = 0; IorD = 3'b100; 
            end

             WAIT_LW: begin 

            end
            
            LW_4: WriteMDR = 1;

            LW_5: begin
                RegDst = 2'b00; MenToReg = 4'b0000; RegWrite = 1;
            end

            // --- STORE WORD ---
            SW_1: begin
                AWrite = 1; BWrite = 1;
            end

            SW_2: begin
                AluSrcA = 1; AluSrcB = 2'b01;AluOp = 3'b001;ALUOutWrite = 1;
            end

            SW_3: begin
                Wr = 1; IorD = 3'b100; MenWriteSrc = 2'b00;
            end

            // --- BEQ ---
            BEQ_1: begin
                AWrite = 1;BWrite = 1;
                AluSrcA= 0;AluSrcB= 2'b10;
                AluOp  = 3'b001; ALUOutWrite = 1;
            end

            BEQ_2: begin
                AluSrcA = 1; AluSrcB = 2'b00; AluOp = 3'b010;
                PCWriteCond = 1; PCSource = 3'b011; // decide aqui, z_out ainda válido
            end

            // --- BNE ---
            BNE_1: begin
                AWrite = 1; BWrite = 1; AluSrcA= 0;AluSrcB= 2'b10; AluOp  = 3'b001; ALUOutWrite = 1;
            end

            BNE_2: begin
                AluSrcA = 1; AluSrcB = 2'b00; AluOp = 3'b010;
                PCWriteCond = 1; PCSource = 3'b011;
            end

            // --- LUI ---
            LUI_1: begin 
                ShiftType = 3'b001; ShiftIN = 1;
            end

            LUI_2: begin 
                ShiftIN = 1; ShiftAmount = 2'b01; ShiftType = 3'b010;
            end

            LUI_3: begin 
                MenToReg = 4'b0001;RegWrite = 1;RegDst = 2'b00;
            end

            // --- LB ---
            LB_1:begin 
                AWrite = 1;
            end

            LB_2: begin 
                AluSrcA = 1;AluSrcB = 2'b01;AluOp = 3'b001;ALUOutWrite = 1;
            end

            LB_3: begin 
                Wr =0;IorD = 3'b100;
            end

            WAIT_LB: begin 

            end

            LB_4: begin 
                WriteMDR = 1;
            end

            LB_5: begin 
                RegDst =2'b00;MenToReg = 4'b0110;RegWrite = 1;
            end

            // --- ADDI ---
            ADDI_1: begin 
                AWrite = 1;
            end
            
            ADDI_2: begin 
                AluSrcA = 1;AluSrcB = 2'b01;AluOp = 3'b001;ALUOutWrite = 1;
            end

            ADDI_3: begin 
                RegDst = 2'b00;MenToReg = 4'b0101;RegWrite = 1;
            end

            // --- SB ---
            
            SB_1: begin 
                AWrite = 1;BWrite = 1;
            end

            SB_2: begin 
                AluSrcA = 1;AluSrcB = 2'b01;AluOp = 3'b001;ALUOutWrite = 1;
            end

            SB_3: begin 
                Wr = 0;IorD = 3'b100;
            end

            SB_4: begin 
                WriteMDR = 1;
            end

            SB_5: begin 
                Wr = 1;IorD = 3'b100;MenWriteSrc = 2'b11;
            end

            // --- J ---
            J_1: begin 
                PCWrite = 1;PCSource = 3'b001;
            end

            // --- JAL ---
            JAL_1: begin 
                MenToReg = 4'b0111;RegDst = 2'b01;RegWrite = 1;
            end

            JAL_2: begin 
                PCWrite = 1;PCSource = 3'b001;
            end

            // --- SUB ---
            SUB_1: begin
                AWrite = 1; BWrite = 1;
            end

            SUB_2: begin
                AluSrcA = 1; AluSrcB = 2'b00; AluOp = 3'b010; ALUOutWrite = 1;
            end

            SUB_3: begin
                RegDst= 2'b10; MenToReg = 4'b0101; RegWrite = 1;
            end

            // --- ADD ---
            ADD_1: begin
                AWrite = 1; BWrite = 1;
            end

            ADD_2: begin
                AluSrcA = 1; AluSrcB = 2'b00; AluOp = 3'b001; ALUOutWrite = 1;
            end

            ADD_3: begin
                RegDst= 2'b10; MenToReg = 4'b0101; RegWrite = 1;
            end

            // --- AND ---
            AND_1: begin
                AWrite = 1; BWrite = 1;
            end

            AND_2: begin
                AluSrcA = 1; AluSrcB = 2'b00; AluOp = 3'b011; ALUOutWrite = 1;
            end

            AND_3: begin
                RegDst= 2'b10; MenToReg = 4'b0101; RegWrite = 1;
            end

            // --- SRA ---
            SRA_1: begin
                BWrite = 1;
                ShiftType = 3'b000;  // idle
            end

            SRA_2: begin
                ShiftIN = 0;
                ShiftType = 3'b001;  // load
            end

            SRA_3: begin
                ShiftIN = 0;
                ShiftAmount = 2'b10;
                ShiftType = 3'b100;  // shift right aritmético
            end

            SRA_4: begin
                RegDst = 2'b10; MenToReg = 4'b0001; RegWrite = 1;
            end

            // --- SLL ---
            SLL_1: begin
                BWrite = 1;          
                ShiftType = 3'b000;
            end

            SLL_2: begin
                ShiftIN = 0;        
                ShiftType = 3'b001;  
            end

            SLL_3: begin
                ShiftIN = 0;
                ShiftAmount = 2'b10; 
                ShiftType = 3'b010;  // shift left
            end

            SLL_4: begin
                RegDst = 2'b10; MenToReg = 4'b0001; RegWrite = 1;
            end

            SLT_1: begin
                AWrite = 1; BWrite = 1;
            end

            SLT_2: begin
                AluSrcA = 1; AluSrcB = 2'b00; AluOp = 3'b111; RegDst= 2'b10; MenToReg = 4'b0100; RegWrite = 1;
            end

            JR_1: begin
                AWrite = 1;
            end

            JR_2: begin
                PCSource = 3'b000; PCWrite = 1;
            end

            MFLO_1: begin
                RegWrite = 1; RegDst = 2'b10; MenToReg = 4'b0011;
            end

            MFHI_1: begin
                RegWrite = 1; RegDst = 2'b10; MenToReg = 4'b0010;
            end

            // --- PUSH rs ---
            PUSH_1: begin // A <- R29 (SP), B <- rs
                Read1Sel = 1; Read2Sel = 1; AWrite = 1; BWrite = 1;
            end

            PUSH_2: begin // ALUOut <- SP - 4
                AluSrcA = 1; AluSrcB = 2'b11; AluOp = 3'b010; ALUOutWrite = 1;
            end

            PUSH_3: begin // Mem[SP - 4] <- rs ; R29 <- SP - 4
                IorD = 3'b100; Wr = 1; MenWriteSrc = 2'b00;
                RegDst = 2'b11; MenToReg = 4'b0101; RegWrite = 1;
            end

            // --- POP rd ---
            POP_1: begin // A <- R29 (SP)
                Read1Sel = 1; AWrite = 1;
            end

            POP_2: begin // ALUOut <- SP (ALU passa A)
                AluSrcA = 1; AluOp = 3'b000; ALUOutWrite = 1;
            end

            POP_3: begin // requisita Mem[SP]; ALUOut <- SP + 4 na mesma borda
                IorD = 3'b100; Wr = 0;
                AluSrcA = 1; AluSrcB = 2'b11; AluOp = 3'b001; ALUOutWrite = 1;
            end

            POP_4: begin // espera da memória; R29 <- SP + 4
                RegDst = 2'b11; MenToReg = 4'b0101; RegWrite = 1;
            end

            POP_5: begin // MDR <- Mem[SP]
                WriteMDR = 1;
            end

            POP_6: begin // rd <- MDR
                RegDst = 2'b10; MenToReg = 4'b0000; RegWrite = 1;
            end

            EXCEPTION_OVERFLOW: begin
                AluSrcA = 0;     
                AluSrcB = 2'b11; 
                AluOp = 3'b010;  
                EPCWrite = 1;    
            end

            EXCEPTION_ZERO: begin
                AluSrcA = 0;
                AluSrcB = 2'b11;
                AluOp = 3'b010;
                EPCWrite = 1;
            end

            EXCEPTION_OPCODE: begin
                AluSrcA = 0;
                AluSrcB = 2'b11;
                AluOp = 3'b010;
                EPCWrite = 1;
            end

            EXCEPTION_2: begin
                Wr=0;IorD=3'b011;ErrorType=error_type_reg;
            end

            EXCEPTION_WAIT: begin 

            end

            EXCEPTION_3: begin
                WriteMDR=1;
            end

            EXCEPTION_4: begin
                PCSource=3'b101;PCWrite=1;
            end


        endcase
    end

endmodule