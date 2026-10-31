// ---------------------------------------------------------------------------
// TOP: procesador + memorias
// ---------------------------------------------------------------------------
module top_dual(input         clk, reset,
                output [31:0] WriteData, DataAdr,
                output        MemWrite);
 
  wire [31:0] PC, Instr0, Instr1, ReadData;
 
  riscvdual rv(
    .clk(clk), 
    .reset(reset),
    .PC(PC),
    .Instr0(Instr0), .Instr1(Instr1),
    .MemWrite(MemWrite),
    .DataAdr(DataAdr), 
    .WriteData(WriteData),
    .ReadData(ReadData)
  );
 
  imem imem(.a(PC), .rd0(Instr0), .rd1(Instr1));               // Dual Fetch
  dmem dmem(.clk(clk), .we(MemWrite), .a(DataAdr),
            .wd(WriteData), .rd(ReadData));                    // 1 solo puerto
endmodule
