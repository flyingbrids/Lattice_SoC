`timescale 1 ps / 1 ps

module my_soc_Top (
     output wire ledn
    ,output wire hv_drive
    ,input  wire osc_clk
    ,output wire adc_sen_o
    ,output wire dac_sen_o
    ,output wire adc_sclk_o
    ,inout  wire adc_sdio_io
    ,output wire F_sclk
    ,output wire F_CSn
    ,output wire F_MOSI
    ,input  wire F_MISO
);

    //----------------------------------------------------------
    // Reset generation
    //----------------------------------------------------------
    reg [7:0] rstn = 8'h00;

    always @(posedge osc_clk) begin
        rstn <= {rstn[6:0],1'b1};
    end

    //----------------------------------------------------------
    // GPIO connection
    //----------------------------------------------------------
    wire [1:0] gpio_00_io;

    assign hv_drive = gpio_00_io[0];
    assign ledn = gpio_00_io[1];

    //----------------------------------------------------------
    // Internal APB2Fabric interface and SoC clock/reset
    //----------------------------------------------------------
    wire [31:0] apb_paddr;
    wire [31:0] apb_pwdata;
    wire [31:0] apb_prdata;

    wire        apb_penable;
    wire        apb_pselx;
    wire        apb_pwrite;
    wire        apb_pready;
    wire        apb_pslverr;
    wire        apb_clk;
    wire        apb_resetn;
    wire        apb_reset;
    // Divide the APB clock for SPI engine clock.
    reg  [3:0]  spi_clk_div = 4'h0;
    wire        spi_clk = spi_clk_div[0];

    assign apb_reset = ~apb_resetn;

    always @(posedge apb_clk or negedge apb_resetn) begin
        if (!apb_resetn)
            spi_clk_div <= 4'h0;
        else
            spi_clk_div <= spi_clk_div + 1'b1;
    end

    //----------------------------------------------------------
    // APB splitter downstream interfaces
    //----------------------------------------------------------
    wire        reg_apb_psel;
    wire        reg_apb_penable;
    wire        reg_apb_pwrite;
    wire [31:0] reg_apb_paddr;
    wire [31:0] reg_apb_pwdata;
    wire [31:0] reg_apb_prdata;
    wire        reg_apb_pready;
    wire        reg_apb_pslverr;

    wire        spi_apb_psel;
    wire        spi_apb_penable;
    wire        spi_apb_pwrite;
    wire [31:0] spi_apb_paddr_full;
    wire [6:0]  spi_apb_paddr;
    wire [31:0] spi_apb_pwdata;
    wire [31:0] spi_apb_prdata;
    wire        spi_apb_pready;
    wire        spi_apb_pslverr;

    wire        stream_apb_psel;
    wire        stream_apb_penable;
    wire        stream_apb_pwrite;
    wire [31:0] stream_apb_paddr;
    wire [31:0] stream_apb_pwdata;
    wire [31:0] stream_apb_prdata;
    wire        stream_apb_pready;
    wire        stream_apb_pslverr;

    assign spi_apb_paddr = spi_apb_paddr_full[8:2];
    assign stream_apb_prdata  = 32'h00000000;
    assign stream_apb_pready  = 1'b1;
    assign stream_apb_pslverr = 1'b0;

    //----------------------------------------------------------
    // Register dispenser and SPI master control/status signals
    //----------------------------------------------------------
    wire [15:0] spi_byte_count_reg;
    wire [15:0] spi_control_reg_full;
    wire [15:0] spi_status_reg;
    wire [8:0]  spi_byte_count;
    wire [7:0]  spi_control_reg;
    wire        spi_start;
    wire        spi_busy;
    wire        spi_done;

    wire [15:0] adc_control_reg;
    wire [15:0] adc_status_reg;
    wire [15:0] adc0_result;
    wire [15:0] adc1_result;

    wire [15:0] reg_rst_hist;
    wire [15:0] reg_start_hist;
    wire [15:0] reg_stop_hist;
    wire [15:0] reg_lld;
    wire [15:0] reg_uld;
    wire [15:0] reg_threshold;
    wire [15:0] reg_hv;
    wire [15:0] reg_gain;
    wire [15:0] reg_hist;
    wire [15:0] reg_mode;
    wire [15:0] reg_zone1;
    wire [15:0] reg_zone2;
    wire [15:0] reg_zone3;
    wire [15:0] reg_zone_set;
    wire [15:0] reg_zone4;
    wire [15:0] reg_zone5;
    wire [15:0] reg_zone6;
    wire [15:0] reg_pz;
    wire [15:0] reg_a_low;
    wire [15:0] reg_a_high;
    wire [15:0] reg_b_low;
    wire [15:0] reg_b_high;
    wire [15:0] reg_c;
    wire [15:0] reg_d;
    wire [15:0] reg_initial_gain;
    wire [15:0] reg_gain_stab;
    wire [15:0] reg_gate_width;
    wire        reg_rst_hist_stb;
    wire        reg_start_hist_stb;
    wire        reg_stop_hist_stb;

    assign spi_byte_count  = spi_byte_count_reg[8:0];
    assign spi_control_reg = spi_control_reg_full[7:0];
    assign spi_status_reg  = {14'b0, spi_done, spi_busy};

    assign adc_status_reg = 16'h0000;
    assign adc0_result    = 16'h0000;
    assign adc1_result    = 16'h0000;

    //----------------------------------------------------------
    // Internal UART loopback (temporary)
    //----------------------------------------------------------
    wire uart_rxd_00_i;
    wire uart_txd_00_o;

    assign uart_rxd_00_i = 1'b1;

    //----------------------------------------------------------
    // SoC Instance
    //----------------------------------------------------------
    my_soc my_soc_inst (

        .gpio_00_io(gpio_00_io),

        .rstn_i(rstn[7]),

        .uart_rxd_00_i(uart_rxd_00_i),
        .uart_txd_00_o(uart_txd_00_o),

        .APB2Fabric_inst_APB_M00_prdata_slv_i_portbus(
            apb_prdata),

        .APB2Fabric_inst_APB_M00_paddr_slv_o_portbus(
            apb_paddr),

        .APB2Fabric_inst_APB_M00_pwdata_slv_o_portbus(
            apb_pwdata),

        .APB2Fabric_inst_APB_M00_pready_slv_i_port(
            apb_pready),

        .APB2Fabric_inst_APB_M00_pslverr_slv_i_port(
            apb_pslverr),

        .APB2Fabric_inst_APB_M00_penable_slv_o_port(
            apb_penable),

        .APB2Fabric_inst_APB_M00_pselx_slv_o_port(
            apb_pselx),

        .APB2Fabric_inst_APB_M00_pwrite_slv_o_port(
            apb_pwrite),

        .apb_clk_o(apb_clk),
        .apb_resetn_o(apb_resetn),
        .osc_clk(osc_clk)
    );

    //----------------------------------------------------------
    // APB address decoder
    //----------------------------------------------------------
    apb_splitter apb_splitter_inst (
        .pclk_i(apb_clk),
        .presetn_i(apb_resetn),
        .psel_i(apb_pselx),
        .penable_i(apb_penable),
        .pwrite_i(apb_pwrite),
        .paddr_i(apb_paddr),
        .pwdata_i(apb_pwdata),
        .prdata_o(apb_prdata),
        .pready_o(apb_pready),
        .pslverr_o(apb_pslverr),

        .reg_psel_o(reg_apb_psel),
        .reg_penable_o(reg_apb_penable),
        .reg_pwrite_o(reg_apb_pwrite),
        .reg_paddr_o(reg_apb_paddr),
        .reg_pwdata_o(reg_apb_pwdata),
        .reg_prdata_i(reg_apb_prdata),
        .reg_pready_i(reg_apb_pready),
        .reg_pslverr_i(reg_apb_pslverr),

        .spi_psel_o(spi_apb_psel),
        .spi_penable_o(spi_apb_penable),
        .spi_pwrite_o(spi_apb_pwrite),
        .spi_paddr_o(spi_apb_paddr_full),
        .spi_pwdata_o(spi_apb_pwdata),
        .spi_prdata_i(spi_apb_prdata),
        .spi_pready_i(spi_apb_pready),
        .spi_pslverr_i(spi_apb_pslverr),

        .stream_psel_o(stream_apb_psel),
        .stream_penable_o(stream_apb_penable),
        .stream_pwrite_o(stream_apb_pwrite),
        .stream_paddr_o(stream_apb_paddr),
        .stream_pwdata_o(stream_apb_pwdata),
        .stream_prdata_i(stream_apb_prdata),
        .stream_pready_i(stream_apb_pready),
        .stream_pslverr_i(stream_apb_pslverr)
    );

    //----------------------------------------------------------
    // FPGA register bank
    //----------------------------------------------------------
    register_dispenser register_dispenser_inst (
        .pclk_i(apb_clk),
        .presetn_i(apb_resetn),
        .psel_i(reg_apb_psel),
        .penable_i(reg_apb_penable),
        .pwrite_i(reg_apb_pwrite),
        .paddr_i(reg_apb_paddr),
        .pwdata_i(reg_apb_pwdata),
        .prdata_o(reg_apb_prdata),
        .pready_o(reg_apb_pready),
        .pslverr_o(reg_apb_pslverr),

        .version_i(16'h0001),
        .serial_i(16'h0000),
        .type_i(16'h0000),
        .roi_i(16'h0000),
        .dead_low_i(16'h0000),
        .dead_high_i(16'h0000),
        .live_low_i(16'h0000),
        .live_high_i(16'h0000),
        .real_low_i(16'h0000),
        .real_high_i(16'h0000),
        .hv_feedback_i(adc0_result),
        .sdi_low_i(16'h0000),
        .sdi_high_i(16'h0000),
        .adc_status_i(adc_status_reg),
        .temperature_i(adc1_result),
        .spi_status_i(spi_status_reg),

        .rst_hist_o(reg_rst_hist),
        .start_hist_o(reg_start_hist),
        .stop_hist_o(reg_stop_hist),
        .lld_o(reg_lld),
        .uld_o(reg_uld),
        .threshold_o(reg_threshold),
        .hv_o(reg_hv),
        .gain_o(reg_gain),
        .hist_o(reg_hist),
        .mode_o(reg_mode),
        .zone1_o(reg_zone1),
        .zone2_o(reg_zone2),
        .zone3_o(reg_zone3),
        .zone_set_o(reg_zone_set),
        .zone4_o(reg_zone4),
        .zone5_o(reg_zone5),
        .zone6_o(reg_zone6),
        .pz_o(reg_pz),
        .a_low_o(reg_a_low),
        .a_high_o(reg_a_high),
        .b_low_o(reg_b_low),
        .b_high_o(reg_b_high),
        .c_o(reg_c),
        .d_o(reg_d),
        .initial_gain_o(reg_initial_gain),
        .gain_stab_o(reg_gain_stab),
        .gate_width_o(reg_gate_width),
        .adc_control_o(adc_control_reg),
        .spi_byte_count_o(spi_byte_count_reg),
        .spi_control_reg_o(spi_control_reg_full),
        .rst_hist_stb_o(reg_rst_hist_stb),
        .start_hist_stb_o(reg_start_hist_stb),
        .stop_hist_stb_o(reg_stop_hist_stb),
        .spi_ctrl_wr_stb_o(spi_start)
    );

    //----------------------------------------------------------
    // SPI master and SPI BRAM interface
    //----------------------------------------------------------
    spi_master_top spi_master_top_inst (
        .clk_i(spi_clk),
        .rst_i(apb_reset),
        .byte_count_i(spi_byte_count),
        .control_reg_i(spi_control_reg),
        .start_i(spi_start),
        .busy_o(spi_busy),
        .done_o(spi_done),
        .adc_sen_o(adc_sen_o),
        .dac_sen_o(dac_sen_o),
        .adc_sclk_o(adc_sclk_o),
        .adc_sdio_io(adc_sdio_io),
        .F_sclk(F_sclk),
        .F_CSn(F_CSn),
        .F_MOSI(F_MOSI),
        .F_MISO(F_MISO),
        .apb_pclk_i(apb_clk),
        .apb_presetn_i(apb_resetn),
        .apb_psel_i(spi_apb_psel),
        .apb_penable_i(spi_apb_penable),
        .apb_pwrite_i(spi_apb_pwrite),
        .apb_paddr_i(spi_apb_paddr),
        .apb_pwdata_i(spi_apb_pwdata),
        .apb_prdata_o(spi_apb_prdata),
        .apb_pready_o(spi_apb_pready),
        .apb_pslverr_o(spi_apb_pslverr)
    );

endmodule