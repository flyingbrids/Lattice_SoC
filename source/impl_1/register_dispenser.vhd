library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity register_dispenser is
    port (
        -- =====================================================================
        -- APB Slave Interface (from apb_splitter reg_* branch)
        -- =====================================================================
        pclk_i              : in  std_logic;
        presetn_i           : in  std_logic;
        psel_i              : in  std_logic;
        penable_i           : in  std_logic;
        pwrite_i            : in  std_logic;
        paddr_i             : in  std_logic_vector(31 downto 0);
        pwdata_i            : in  std_logic_vector(31 downto 0);
        prdata_o            : out std_logic_vector(31 downto 0);
        pready_o            : out std_logic;
        pslverr_o           : out std_logic;

        -- =====================================================================
        -- Read-Only (RO) Register Inputs (Wired only to reg_rd_bus_i)
        -- =====================================================================
        version_i           : in  std_logic_vector(15 downto 0);
        serial_i            : in  std_logic_vector(15 downto 0);
        type_i              : in  std_logic_vector(15 downto 0);
        roi_i               : in  std_logic_vector(15 downto 0);
        dead_low_i          : in  std_logic_vector(15 downto 0);
        dead_high_i         : in  std_logic_vector(15 downto 0);
        live_low_i          : in  std_logic_vector(15 downto 0);
        live_high_i         : in  std_logic_vector(15 downto 0);
        real_low_i          : in  std_logic_vector(15 downto 0);
        real_high_i         : in  std_logic_vector(15 downto 0);
        hv_feedback_i       : in  std_logic_vector(15 downto 0);
        sdi_low_i           : in  std_logic_vector(15 downto 0);
        sdi_high_i          : in  std_logic_vector(15 downto 0);
        adc_status_i        : in  std_logic_vector(15 downto 0);
        temperature_i       : in  std_logic_vector(15 downto 0);
        spi_status_i        : in  std_logic_vector(15 downto 0);

        -- =====================================================================
        -- Read/Write (R/W) & Command Register Outputs (Echoed to reg_rd_bus_i)
        -- =====================================================================
        rst_hist_o          : out std_logic_vector(15 downto 0);
        start_hist_o        : out std_logic_vector(15 downto 0);
        stop_hist_o         : out std_logic_vector(15 downto 0);
        lld_o               : out std_logic_vector(15 downto 0);
        uld_o               : out std_logic_vector(15 downto 0);
        threshold_o         : out std_logic_vector(15 downto 0);
        hv_o                : out std_logic_vector(15 downto 0);
        gain_o              : out std_logic_vector(15 downto 0);
        hist_o              : out std_logic_vector(15 downto 0);
        mode_o              : out std_logic_vector(15 downto 0);
        zone1_o             : out std_logic_vector(15 downto 0);
        zone2_o             : out std_logic_vector(15 downto 0);
        zone3_o             : out std_logic_vector(15 downto 0);
        zone_set_o          : out std_logic_vector(15 downto 0);
        zone4_o             : out std_logic_vector(15 downto 0);
        zone5_o             : out std_logic_vector(15 downto 0);
        zone6_o             : out std_logic_vector(15 downto 0);
        pz_o                : out std_logic_vector(15 downto 0);
        a_low_o             : out std_logic_vector(15 downto 0);
        a_high_o            : out std_logic_vector(15 downto 0);
        b_low_o             : out std_logic_vector(15 downto 0);
        b_high_o            : out std_logic_vector(15 downto 0);
        c_o                 : out std_logic_vector(15 downto 0);
        d_o                 : out std_logic_vector(15 downto 0);
        initial_gain_o      : out std_logic_vector(15 downto 0);
        gain_stab_o         : out std_logic_vector(15 downto 0);
        gate_width_o        : out std_logic_vector(15 downto 0);
        adc_control_o       : out std_logic_vector(15 downto 0);
        spi_byte_count_o    : out std_logic_vector(15 downto 0);
        spi_control_reg_o   : out std_logic_vector(15 downto 0);

        -- 1-Cycle Write Strobes for Command Triggers
        rst_hist_stb_o      : out std_logic;
        start_hist_stb_o    : out std_logic;
        stop_hist_stb_o     : out std_logic;
        spi_ctrl_wr_stb_o   : out std_logic
    );
end entity register_dispenser;

architecture rtl of register_dispenser is

    -- =========================================================================
    -- Register Address Constants
    -- =========================================================================
    constant VERSION_ADDR         : integer range 0 to 127 := 0;
    constant SERIAL_ADDR          : integer range 0 to 127 := 1;  -- Sensor Serial
    constant TYPE_ADDR            : integer range 0 to 127 := 2;  -- Sensor Type
    constant RST_HIST_ADDR        : integer range 0 to 127 := 3;  -- Resetting the histogram
    constant START_HIST_ADDR      : integer range 0 to 127 := 4;  -- Starting the histogram
    constant STOP_HIST_ADDR       : integer range 0 to 127 := 5;  -- Stopping the histogram
    constant LLD_ADDR             : integer range 0 to 127 := 6;  -- write/read
    constant ULD_ADDR             : integer range 0 to 127 := 7;  -- write/read
    constant THRESHOLD_ADDR       : integer range 0 to 127 := 8;  -- Threshold used with ROI
    constant ROI_ADDR             : integer range 0 to 127 := 9;  -- RO
    constant DEAD_LOW_ADDR        : integer range 0 to 127 := 10; -- RO
    constant DEAD_HIGH_ADDR       : integer range 0 to 127 := 11; -- RO
    constant LIVE_LOW_ADDR        : integer range 0 to 127 := 12; -- RO
    constant LIVE_HIGH_ADDR       : integer range 0 to 127 := 13; -- RO
    constant REAL_LOW_ADDR        : integer range 0 to 127 := 14; -- RO
    constant REAL_HIGH_ADDR       : integer range 0 to 127 := 15; -- RO
    constant HV_FEEDBACK_ADDR     : integer range 0 to 127 := 16; -- RO
    constant HV_ADDR              : integer range 0 to 127 := 17; -- write/read
    constant GAIN_ADDR            : integer range 0 to 127 := 18; -- write/read
    constant HIST_ADDR            : integer range 0 to 127 := 19;
    constant MODE_ADDR            : integer range 0 to 127 := 20;
    -- Addresses 21 to 24 reserved/unused
    constant ZONE1_ADDR           : integer range 0 to 127 := 25; -- Low boundary
    constant ZONE2_ADDR           : integer range 0 to 127 := 26;
    constant ZONE3_ADDR           : integer range 0 to 127 := 27;
    constant ZONE_SET_ADDR        : integer range 0 to 127 := 28; -- Set point
    constant ZONE4_ADDR           : integer range 0 to 127 := 29;
    constant ZONE5_ADDR           : integer range 0 to 127 := 30;
    constant ZONE6_ADDR           : integer range 0 to 127 := 31; -- High boundary
    constant SDI_LOW_ADDR         : integer range 0 to 127 := 32; -- RO
    constant SDI_HIGH_ADDR        : integer range 0 to 127 := 33; -- RO
    constant PZ_ADDR              : integer range 0 to 127 := 34; -- Pole zero
    constant A_LOW_ADDR           : integer range 0 to 127 := 35;
    constant A_HIGH_ADDR          : integer range 0 to 127 := 36;
    constant B_LOW_ADDR           : integer range 0 to 127 := 37;
    constant B_HIGH_ADDR          : integer range 0 to 127 := 38;
    constant C_ADDR               : integer range 0 to 127 := 39;
    constant D_ADDR               : integer range 0 to 127 := 40;
    constant INITIAL_GAIN_ADDR    : integer range 0 to 127 := 41;
    constant GAIN_STAB_ADDR       : integer range 0 to 127 := 42;
    constant GATE_WIDTH_ADDR      : integer range 0 to 127 := 43;

    -- Newly Added Registers (44 to 49)
    constant ADC_CONTROL_ADDR     : integer range 0 to 127 := 44; -- R/W
    constant ADC_STATUS_ADDR      : integer range 0 to 127 := 45; -- RO
    constant TEMPERATURE_ADDR     : integer range 0 to 127 := 46; -- RO
    constant SPI_BYTE_COUNT_ADDR  : integer range 0 to 127 := 47; -- R/W
    constant SPI_CONTROL_REG_ADDR : integer range 0 to 127 := 48; -- R/W
    constant SPI_STATUS_ADDR      : integer range 0 to 127 := 49; -- RO (wraps spi_busy & spi_done)

    constant UNDEFINED_ADDR       : integer range 50 to 127 := 127;
    constant NUM_REGS             : integer := 50;

    -- =========================================================================
    -- Component Declaration for apb_to_reg_bridge
    -- =========================================================================
    component apb_to_reg_bridge is
        generic (
            NUM_REGS  : integer := 50;
            ADDR_BITS : integer := 8
        );
        port (
            pclk_i        : in  std_logic;
            presetn_i     : in  std_logic;
            psel_i        : in  std_logic;
            penable_i     : in  std_logic;
            pwrite_i      : in  std_logic;
            paddr_i       : in  std_logic_vector(31 downto 0);
            pwdata_i      : in  std_logic_vector(31 downto 0);
            prdata_o      : out std_logic_vector(31 downto 0);
            pready_o      : out std_logic;
            pslverr_o     : out std_logic;
            reg_wr_bus_o  : out std_logic_vector((NUM_REGS * 16) - 1 downto 0);
            reg_rd_bus_i  : in  std_logic_vector((NUM_REGS * 16) - 1 downto 0);
            reg_wr_stb_o  : out std_logic_vector(NUM_REGS - 1 downto 0)
        );
    end component;

    -- Flattened bus wires connecting to apb_to_reg_bridge
    signal reg_wr_bus : std_logic_vector((NUM_REGS * 16) - 1 downto 0);
    signal reg_rd_bus : std_logic_vector((NUM_REGS * 16) - 1 downto 0) := (others => '0');
    signal reg_wr_stb : std_logic_vector(NUM_REGS - 1 downto 0);

begin

    -- =========================================================================
    -- 1. Instantiate APB to Register Bridge
    -- =========================================================================
    u_apb_to_reg_bridge : apb_to_reg_bridge
        generic map (
            NUM_REGS  => NUM_REGS,
            ADDR_BITS => 8
        )
        port map (
            pclk_i       => pclk_i,
            presetn_i    => presetn_i,
            psel_i       => psel_i,
            penable_i    => penable_i,
            pwrite_i     => pwrite_i,
            paddr_i      => paddr_i,
            pwdata_i     => pwdata_i,
            prdata_o     => prdata_o,
            pready_o     => pready_o,
            pslverr_o    => pslverr_o,
            reg_wr_bus_o => reg_wr_bus,
            reg_rd_bus_i => reg_rd_bus,
            reg_wr_stb_o => reg_wr_stb
        );

    -- =========================================================================
    -- 2. Default Echo Loopback: Echo reg_wr_bus to reg_rd_bus for all R/W slots,
    --    and override Read-Only (RO) addresses with external status inputs
    -- =========================================================================
    gen_bus_map : for i in 0 to NUM_REGS - 1 generate
        
        -- Read-Only Registers (Wired ONLY to reg_rd_bus)
        gen_ro_version : if i = VERSION_ADDR generate
            reg_rd_bus((i + 1) * 16 - 1 downto i * 16) <= version_i;
        end generate;

        gen_ro_serial : if i = SERIAL_ADDR generate
            reg_rd_bus((i + 1) * 16 - 1 downto i * 16) <= serial_i;
        end generate;

        gen_ro_type : if i = TYPE_ADDR generate
            reg_rd_bus((i + 1) * 16 - 1 downto i * 16) <= type_i;
        end generate;

        gen_ro_roi : if i = ROI_ADDR generate
            reg_rd_bus((i + 1) * 16 - 1 downto i * 16) <= roi_i;
        end generate;

        gen_ro_dead_l : if i = DEAD_LOW_ADDR generate
            reg_rd_bus((i + 1) * 16 - 1 downto i * 16) <= dead_low_i;
        end generate;

        gen_ro_dead_h : if i = DEAD_HIGH_ADDR generate
            reg_rd_bus((i + 1) * 16 - 1 downto i * 16) <= dead_high_i;
        end generate;

        gen_ro_live_l : if i = LIVE_LOW_ADDR generate
            reg_rd_bus((i + 1) * 16 - 1 downto i * 16) <= live_low_i;
        end generate;

        gen_ro_live_h : if i = LIVE_HIGH_ADDR generate
            reg_rd_bus((i + 1) * 16 - 1 downto i * 16) <= live_high_i;
        end generate;

        gen_ro_real_l : if i = REAL_LOW_ADDR generate
            reg_rd_bus((i + 1) * 16 - 1 downto i * 16) <= real_low_i;
        end generate;

        gen_ro_real_h : if i = REAL_HIGH_ADDR generate
            reg_rd_bus((i + 1) * 16 - 1 downto i * 16) <= real_high_i;
        end generate;

        gen_ro_hv_fb : if i = HV_FEEDBACK_ADDR generate
            reg_rd_bus((i + 1) * 16 - 1 downto i * 16) <= hv_feedback_i;
        end generate;

        gen_ro_sdi_l : if i = SDI_LOW_ADDR generate
            reg_rd_bus((i + 1) * 16 - 1 downto i * 16) <= sdi_low_i;
        end generate;

        gen_ro_sdi_h : if i = SDI_HIGH_ADDR generate
            reg_rd_bus((i + 1) * 16 - 1 downto i * 16) <= sdi_high_i;
        end generate;

        gen_ro_adc_stat : if i = ADC_STATUS_ADDR generate
            reg_rd_bus((i + 1) * 16 - 1 downto i * 16) <= adc_status_i;
        end generate;

        gen_ro_temp : if i = TEMPERATURE_ADDR generate
            reg_rd_bus((i + 1) * 16 - 1 downto i * 16) <= temperature_i;
        end generate;

        gen_ro_spi_stat : if i = SPI_STATUS_ADDR generate
            reg_rd_bus((i + 1) * 16 - 1 downto i * 16) <= spi_status_i;
        end generate;

        -- All Other R/W Registers: Echo reg_wr_bus_o back to reg_rd_bus_i
        gen_rw_echo : if (i /= VERSION_ADDR)     and (i /= SERIAL_ADDR)      and
                         (i /= TYPE_ADDR)        and (i /= ROI_ADDR)         and
                         (i /= DEAD_LOW_ADDR)    and (i /= DEAD_HIGH_ADDR)   and
                         (i /= LIVE_LOW_ADDR)    and (i /= LIVE_HIGH_ADDR)   and
                         (i /= REAL_LOW_ADDR)    and (i /= REAL_HIGH_ADDR)   and
                         (i /= HV_FEEDBACK_ADDR) and (i /= SDI_LOW_ADDR)     and
                         (i /= SDI_HIGH_ADDR)    and (i /= ADC_STATUS_ADDR)  and
                         (i /= TEMPERATURE_ADDR) and (i /= SPI_STATUS_ADDR) generate
            reg_rd_bus((i + 1) * 16 - 1 downto i * 16) <= reg_wr_bus((i + 1) * 16 - 1 downto i * 16);
        end generate;

    end generate gen_bus_map;

    -- =========================================================================
    -- 3. Break Out Individual R/W Registers to Module Outputs
    -- =========================================================================
    rst_hist_o        <= reg_wr_bus((RST_HIST_ADDR + 1) * 16 - 1        downto RST_HIST_ADDR * 16);
    start_hist_o      <= reg_wr_bus((START_HIST_ADDR + 1) * 16 - 1      downto START_HIST_ADDR * 16);
    stop_hist_o       <= reg_wr_bus((STOP_HIST_ADDR + 1) * 16 - 1       downto STOP_HIST_ADDR * 16);
    lld_o             <= reg_wr_bus((LLD_ADDR + 1) * 16 - 1             downto LLD_ADDR * 16);
    uld_o             <= reg_wr_bus((ULD_ADDR + 1) * 16 - 1             downto ULD_ADDR * 16);
    threshold_o       <= reg_wr_bus((THRESHOLD_ADDR + 1) * 16 - 1       downto THRESHOLD_ADDR * 16);
    hv_o              <= reg_wr_bus((HV_ADDR + 1) * 16 - 1              downto HV_ADDR * 16);
    gain_o            <= reg_wr_bus((GAIN_ADDR + 1) * 16 - 1            downto GAIN_ADDR * 16);
    hist_o            <= reg_wr_bus((HIST_ADDR + 1) * 16 - 1            downto HIST_ADDR * 16);
    mode_o            <= reg_wr_bus((MODE_ADDR + 1) * 16 - 1            downto MODE_ADDR * 16);
    zone1_o           <= reg_wr_bus((ZONE1_ADDR + 1) * 16 - 1           downto ZONE1_ADDR * 16);
    zone2_o           <= reg_wr_bus((ZONE2_ADDR + 1) * 16 - 1           downto ZONE2_ADDR * 16);
    zone3_o           <= reg_wr_bus((ZONE3_ADDR + 1) * 16 - 1           downto ZONE3_ADDR * 16);
    zone_set_o        <= reg_wr_bus((ZONE_SET_ADDR + 1) * 16 - 1        downto ZONE_SET_ADDR * 16);
    zone4_o           <= reg_wr_bus((ZONE4_ADDR + 1) * 16 - 1           downto ZONE4_ADDR * 16);
    zone5_o           <= reg_wr_bus((ZONE5_ADDR + 1) * 16 - 1           downto ZONE5_ADDR * 16);
    zone6_o           <= reg_wr_bus((ZONE6_ADDR + 1) * 16 - 1           downto ZONE6_ADDR * 16);
    pz_o              <= reg_wr_bus((PZ_ADDR + 1) * 16 - 1              downto PZ_ADDR * 16);
    a_low_o           <= reg_wr_bus((A_LOW_ADDR + 1) * 16 - 1           downto A_LOW_ADDR * 16);
    a_high_o          <= reg_wr_bus((A_HIGH_ADDR + 1) * 16 - 1          downto A_HIGH_ADDR * 16);
    b_low_o             <= reg_wr_bus((B_LOW_ADDR + 1) * 16 - 1         downto B_LOW_ADDR * 16);
    b_high_o          <= reg_wr_bus((B_HIGH_ADDR + 1) * 16 - 1          downto B_HIGH_ADDR * 16);
    c_o               <= reg_wr_bus((C_ADDR + 1) * 16 - 1               downto C_ADDR * 16);
    d_o               <= reg_wr_bus((D_ADDR + 1) * 16 - 1               downto D_ADDR * 16);
    initial_gain_o    <= reg_wr_bus((INITIAL_GAIN_ADDR + 1) * 16 - 1    downto INITIAL_GAIN_ADDR * 16);
    gain_stab_o       <= reg_wr_bus((GAIN_STAB_ADDR + 1) * 16 - 1       downto GAIN_STAB_ADDR * 16);
    gate_width_o      <= reg_wr_bus((GATE_WIDTH_ADDR + 1) * 16 - 1      downto GATE_WIDTH_ADDR * 16);
    adc_control_o     <= reg_wr_bus((ADC_CONTROL_ADDR + 1) * 16 - 1     downto ADC_CONTROL_ADDR * 16);
    spi_byte_count_o  <= reg_wr_bus((SPI_BYTE_COUNT_ADDR + 1) * 16 - 1  downto SPI_BYTE_COUNT_ADDR * 16);
    spi_control_reg_o <= reg_wr_bus((SPI_CONTROL_REG_ADDR + 1) * 16 - 1 downto SPI_CONTROL_REG_ADDR * 16);

    -- Write Strobe Outputs for Command Triggers
    rst_hist_stb_o    <= reg_wr_stb(RST_HIST_ADDR);
    start_hist_stb_o  <= reg_wr_stb(START_HIST_ADDR);
    stop_hist_stb_o   <= reg_wr_stb(STOP_HIST_ADDR);
    spi_ctrl_wr_stb_o <= reg_wr_stb(SPI_CONTROL_REG_ADDR);

end architecture rtl;