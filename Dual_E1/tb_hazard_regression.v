`timescale 1ns/1ps

// Usa los cuatro programas disponibles en el repositorio
module tb_hazard_regression;
  wire done1, done2, done3, done4;
  wire [31:0] err1, err2, err3, err4;

  comparar #(.MEMFILE("program1.mem")) p1(.done(done1), .errors(err1));
  comparar #(.MEMFILE("program2.mem")) p2(.done(done2), .errors(err2));
  comparar #(.MEMFILE("program3.mem")) p3(.done(done3), .errors(err3));
  comparar #(.MEMFILE("program4.mem")) p4(.done(done4), .errors(err4));

  initial begin
    wait (done1 && done2 && done3 && done4);
    if ({err1, err2, err3, err4} !== 128'b0)
      $fatal(1, "REGRESION HAZARD: resultados diferentes");
    $display("REGRESION HAZARD: CORRECTO en los 4 programas");
    $finish;
  end

  initial begin
    #2000;
    $fatal(1, "REGRESION HAZARD: tiempo agotado");
  end
endmodule
