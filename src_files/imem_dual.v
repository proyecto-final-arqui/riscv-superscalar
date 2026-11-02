module imem_dual(input  [31:0] a,
            output [31:0] rd0, 
            output [31:0] rd1);
  
  reg [31:0] RAM[63:0]; 

  initial begin
      $readmemh("riscvtest.dat",RAM); 
  end

  assign rd0 = RAM[a[31:2]]; // word aligned 0
  assign rd1 = RAM[a[31:2] + 1]; // word aligned 1
endmodule