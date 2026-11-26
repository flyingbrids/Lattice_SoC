/*******************************************************************************
    Combinational APB pass-through between S00 and M00 interfaces
*******************************************************************************/

module APB_register (
    // Global / System Signals
    input  wire        clk_i, 
    input  wire        rst_n_i, 

    // --- Master Interface (M00) - Opposite IO direction of S00 ---
    output wire [31:0] APB_M00_paddr_slv_o, 
    output wire        APB_M00_penable_slv_o, 
    input  wire [31:0] APB_M00_prdata_slv_i, 
    input  wire        APB_M00_pready_slv_i, 
    output wire        APB_M00_pselx_slv_o, 
    input  wire        APB_M00_pslverr_slv_i, 
    output wire [31:0] APB_M00_pwdata_slv_o, 
    output wire        APB_M00_pwrite_slv_o, 

    // --- Slave Interface (S00) ---
    input  wire [31:0] APB_S00_paddr_slv_i, 
    input  wire        APB_S00_penable_slv_i, 
    output wire [31:0] APB_S00_prdata_slv_o, 
    output wire        APB_S00_pready_slv_o, 
    input  wire        APB_S00_pselx_slv_i, 
    output wire        APB_S00_pslverr_slv_o, 
    input  wire [31:0] APB_S00_pwdata_slv_i, 
    input  wire        APB_S00_pwrite_slv_i
);

    assign APB_M00_paddr_slv_o   = rst_n_i ? APB_S00_paddr_slv_i   : 32'b0;
    assign APB_M00_penable_slv_o = rst_n_i ? APB_S00_penable_slv_i : 1'b0;
    assign APB_M00_pselx_slv_o   = rst_n_i ? APB_S00_pselx_slv_i   : 1'b0;
    assign APB_M00_pwdata_slv_o  = rst_n_i ? APB_S00_pwdata_slv_i  : 32'b0;
    assign APB_M00_pwrite_slv_o  = rst_n_i ? APB_S00_pwrite_slv_i  : 1'b0;

    assign APB_S00_prdata_slv_o  = rst_n_i ? APB_M00_prdata_slv_i  : 32'b0;
    assign APB_S00_pready_slv_o  = rst_n_i ? APB_M00_pready_slv_i  : 1'b0;
    assign APB_S00_pslverr_slv_o = rst_n_i ? APB_M00_pslverr_slv_i : 1'b0;

endmodule