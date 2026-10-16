module mux_read_reg2 (
    input wire                 seletor,
    input wire    [4:0]        data_0,
    input wire    [4:0]        data_1,
    output wire   [4:0]        data_output
);

    assign data_output = (seletor) ? data_1 : data_0;

endmodule
