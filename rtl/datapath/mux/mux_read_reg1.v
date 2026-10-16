module mux_read_reg1 (
    input wire                 seletor,
    input wire    [4:0]        data_0,
    output wire   [4:0]        data_output
);

    assign data_output = (seletor) ? 5'b11101 : data_0;

endmodule
