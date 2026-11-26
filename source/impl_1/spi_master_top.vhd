library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_master_top is
    port (
        -- System Clocks & Resets (Driven from PLL)
        clk_i           : in  std_logic;                     -- Connected to slow_clk (12.5 MHz)
        rst_i           : in  std_logic;                     -- Connected to lock_o (active-high reset)
        
        -- External Configuration / Control Inputs (Driven from sys_clk domain)
        byte_count_i    : in  std_logic_vector(8 downto 0);
        control_reg_i   : in  std_logic_vector(7 downto 0);
        
        -- Status / Handshake Outputs (Synchronized back to sys_clk domain via apb_pclk_i)
        start_i         : in  std_logic;                     -- 1-cycle pulse from sys_clk domain
        busy_o          : out std_logic;                     -- Synchronized to apb_pclk_i
        done_o          : out std_logic;                     -- Synchronized to apb_pclk_i

        -- Physical ADC3544 & DAC SPI Interface IOs (1.8V LVCMOS18H)
        adc_sen_o       : out std_logic;                     -- ADC SPI Chip Select (Active Low) -> Pin 42
        dac_sen_o       : out std_logic;                     -- DAC SPI Chip Select (Active Low)
        adc_sclk_o      : out std_logic;                     -- Shared SPI Serial Clock (for ADC/DAC) -> Pin 44
        adc_sdio_io     : inout std_logic;                   -- SPI Serial Data I/O (ADC / Shared Bidirectional) -> Pin 31

        -- Physical SPI Flash Memory IOs (4 separate lines)
        F_sclk          : out std_logic;                     -- SPI Flash Clock (multiplexed when Flash CS is low)
        F_CSn           : out std_logic;                     -- SPI Flash Chip Select (Active Low)
        F_MOSI          : out std_logic;                     -- SPI Flash Master Out Slave In
        F_MISO          : in  std_logic;                     -- SPI Flash Master In Slave Out

        -- APB Slave Interface (7-bit word address bus)
        apb_pclk_i      : in  std_logic;                     -- APB Clock (sys_clk = 125 MHz)
        apb_presetn_i   : in  std_logic;                     -- APB Active-Low Reset
        apb_psel_i      : in  std_logic;                     -- APB Select
        apb_penable_i   : in  std_logic;                     -- APB Enable
        apb_pwrite_i    : in  std_logic;                     -- APB Write (1 = Write, 0 = Read)
        apb_paddr_i     : in  std_logic_vector(6 downto 0);  -- APB 7-bit Address Bus
        apb_pwdata_i    : in  std_logic_vector(31 downto 0); -- APB Write Data (32-bit)
        apb_prdata_o    : out std_logic_vector(31 downto 0); -- APB Read Data (32-bit)
        apb_pready_o    : out std_logic;                     -- APB Ready handshake
        apb_pslverr_o   : out std_logic                      -- APB Slave Error
    );
end entity spi_master_top;

architecture rtl of spi_master_top is

    -- Component declaration for spi_master_bram
    component spi_master_bram is
        port (
            clk_i           : in  std_logic;
            rst_i           : in  std_logic;
            byte_count_i    : in  std_logic_vector(8 downto 0);
            control_reg_i   : in  std_logic_vector(7 downto 0);
            start_i         : in  std_logic;
            busy_o          : out std_logic;
            done_o          : out std_logic;
            bram_addr_o     : out std_logic_vector(8 downto 0);
            bram_en_o       : out std_logic;
            bram_we_o       : out std_logic;
            bram_wr_data_o  : out std_logic_vector(7 downto 0);
            bram_rd_data_i  : in  std_logic_vector(7 downto 0);
            sclk_o          : out std_logic;
            mosi_o          : out std_logic;
            miso_i          : in  std_logic;
            cs_n_o          : out std_logic_vector(2 downto 0)
        );
    end component;

    -- Component declaration for true_dual_port_ram[cite: 6]
    component true_dual_port_ram is
        generic (
            PORT_A_WIDTH : integer := 32;
            PORT_B_WIDTH : integer := 8;
            PORT_A_DEPTH : integer := 128;
            PORT_B_DEPTH : integer := 512
        );
        port (
            clk_a_i    : in  std_logic;
            rst_a_i    : in  std_logic;
            clk_en_a_i : in  std_logic;
            wr_en_a_i  : in  std_logic;
            addr_a_i   : in  std_logic_vector(6 downto 0);
            wr_data_a_i: in  std_logic_vector(31 downto 0);
            rd_data_a_o: out std_logic_vector(31 downto 0);
            clk_b_i    : in  std_logic;
            rst_b_i    : in  std_logic;
            clk_en_b_i : in  std_logic;
            wr_en_b_i  : in  std_logic;
            addr_b_i   : in  std_logic_vector(8 downto 0);
            wr_data_b_i: in  std_logic_vector(7 downto 0);
            rd_data_b_o: out std_logic_vector(7 downto 0)
        );
    end component;

    -- Component declaration for apb_to_bram_bridge[cite: 7]
    component apb_to_bram_bridge is
        port (
            pclk_i         : in  std_logic;
            presetn_i      : in  std_logic;
            psel_i         : in  std_logic;
            penable_i      : in  std_logic;
            pwrite_i       : in  std_logic;
            paddr_i        : in  std_logic_vector(6 downto 0);
            pwdata_i       : in  std_logic_vector(31 downto 0);
            prdata_o       : out std_logic_vector(31 downto 0);
            pready_o       : out std_logic;
            pslverr_o      : out std_logic;
            bram_clk_o     : out std_logic;
            bram_rst_o     : out std_logic;
            bram_clk_en_o  : out std_logic;
            bram_wr_en_o   : out std_logic;
            bram_addr_o    : out std_logic_vector(6 downto 0);
            bram_wr_data_o : out std_logic_vector(31 downto 0);
            bram_rd_data_i : in  std_logic_vector(31 downto 0)
        );
    end component;

    -- CDC / Handshake signals
    signal start_toggle     : std_logic := '0';
    signal start_toggle_sync0 : std_logic := '0';
    signal start_toggle_sync1 : std_logic := '0';
    signal start_toggle_sync2 : std_logic := '0';
    signal start_pulse_slow : std_logic;

    signal busy_sig         : std_logic;
    signal busy_sync0       : std_logic := '0';
    signal busy_sync1       : std_logic := '0';

    signal done_sig         : std_logic;
    signal done_sync0       : std_logic := '0';
    signal done_sync1       : std_logic := '0';

    -- Internal BRAM Port B interface signals (9-bit address for 512 bytes)
    signal bram_addr_spi    : std_logic_vector(8 downto 0);
    signal bram_en_spi      : std_logic;
    signal bram_we_spi      : std_logic;
    signal bram_wr_data_spi : std_logic_vector(7 downto 0);
    signal bram_rd_data_spi : std_logic_vector(7 downto 0);

    -- Internal SPI signals
    signal sclk_sig         : std_logic;
    signal mosi_sig         : std_logic;
    signal miso_sig         : std_logic;
    signal cs_n_sig         : std_logic_vector(2 downto 0);

    -- Internal bridge-to-RAM Port A signals
    signal bram_clk_a       : std_logic;
    signal bram_rst_a       : std_logic;
    signal bram_clk_en_a    : std_logic;
    signal bram_wr_en_a     : std_logic;
    signal bram_addr_a      : std_logic_vector(6 downto 0);
    signal bram_wr_data_a   : std_logic_vector(31 downto 0);
    signal bram_rd_data_a   : std_logic_vector(31 downto 0);

    -- SDIO Direction Control Signals
    signal first_bit_reg    : std_logic;
    signal is_input_mode    : std_logic;

begin

    -- =========================================================================
    -- CDC 1: Toggle-based Synchronizer for `start_i` (sys_clk -> slow_clk)
    -- =========================================================================
    process(apb_pclk_i, apb_presetn_i)
    begin
        if apb_presetn_i = '0' then
            start_toggle <= '0';
        elsif rising_edge(apb_pclk_i) then
            if start_i = '1' then
                start_toggle <= not start_toggle; -- Toggle on every start command
            end if;
        end if;
    end process;

    -- Synchronize toggle into slow clock domain (clk_i)
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            start_toggle_sync0 <= '0';
            start_toggle_sync1 <= '0';
            start_toggle_sync2 <= '0';
        elsif rising_edge(clk_i) then
            start_toggle_sync0 <= start_toggle;
            start_toggle_sync1 <= start_toggle_sync0;
            start_toggle_sync2 <= start_toggle_sync1;
        end if;
    end process;

    -- Edge detection on slow clock to generate a 1-cycle pulse for spi_master_bram
    start_pulse_slow <= start_toggle_sync1 xor start_toggle_sync2;

    -- =========================================================================
    -- CDC 2: 2-Stage Synchronizer for `busy_o` and `done_o` (slow_clk -> sys_clk)
    -- =========================================================================
    process(apb_pclk_i, apb_presetn_i)
    begin
        if apb_presetn_i = '0' then
            busy_sync0 <= '0';
            busy_sync1 <= '0';
            done_sync0 <= '0';
            done_sync1 <= '0';
        elsif rising_edge(apb_pclk_i) then
            busy_sync0 <= busy_sig;
            busy_sync1 <= busy_sync0;

            done_sync0 <= done_sig;
            done_sync1 <= done_sync0;
        end if;
    end process;

    busy_o <= busy_sync1;
    done_o <= done_sync1;

    -- =========================================================================
    -- Instantiate the SPI Master with BRAM interface
    -- =========================================================================
    u_spi_master : spi_master_bram
        port map (
            clk_i           => clk_i,
            rst_i           => rst_i,
            byte_count_i    => byte_count_i,
            control_reg_i   => control_reg_i,
            start_i         => start_pulse_slow,
            busy_o          => busy_sig,
            done_o          => done_sig,
            bram_addr_o     => bram_addr_spi,
            bram_en_o       => bram_en_spi,
            bram_we_o       => bram_we_spi,
            bram_wr_data_o  => bram_wr_data_spi,
            bram_rd_data_i  => bram_rd_data_spi,
            sclk_o          => sclk_sig,
            mosi_o          => mosi_sig,
            miso_i          => miso_sig,
            cs_n_o          => cs_n_sig
        );

    -- =========================================================================
    -- Instantiate APB-to-BRAM Bridge[cite: 7]
    -- =========================================================================
    u_apb_bridge : apb_to_bram_bridge
        port map (
            pclk_i         => apb_pclk_i,
            presetn_i      => apb_presetn_i,
            psel_i         => apb_psel_i,
            penable_i      => apb_penable_i,
            pwrite_i       => apb_pwrite_i,
            paddr_i        => apb_paddr_i,
            pwdata_i       => apb_pwdata_i,
            prdata_o       => apb_prdata_o,
            pready_o       => apb_pready_o,
            pslverr_o      => apb_pslverr_o,
            bram_clk_o     => bram_clk_a,
            bram_rst_o     => bram_rst_a,
            bram_clk_en_o  => bram_clk_en_a,
            bram_wr_en_o   => bram_wr_en_a,
            bram_addr_o    => bram_addr_a,
            bram_wr_data_o => bram_wr_data_a,
            bram_rd_data_i => bram_rd_data_a
        );

    -- =========================================================================
    -- Instantiate True Dual-Port RAM[cite: 6]
    -- =========================================================================
    u_true_dp_ram : true_dual_port_ram
        generic map (
            PORT_A_WIDTH => 32,
            PORT_B_WIDTH => 8,
            PORT_A_DEPTH => 128,
            PORT_B_DEPTH => 512
        )
        port map (
            -- Port A (Connected to APB-to-BRAM Bridge running on apb_pclk_i / sys_clk)
            clk_a_i     => bram_clk_a,
            rst_a_i     => bram_rst_a,
            clk_en_a_i  => bram_clk_en_a,
            wr_en_a_i   => bram_wr_en_a,
            addr_a_i    => bram_addr_a,
            wr_data_a_i => bram_wr_data_a,
            rd_data_a_o => bram_rd_data_a,
            
            -- Port B (Wired to 9-bit SPI Master interface running on clk_i / slow_clk)
            clk_b_i     => clk_i,
            rst_b_i     => rst_i,
            clk_en_b_i  => bram_en_spi,
            wr_en_b_i   => bram_we_spi,
            addr_b_i    => bram_addr_spi,
            wr_data_b_i => bram_wr_data_spi,
            rd_data_b_o => bram_rd_data_spi
        );

    -- =========================================================================
    -- Multiplexing SPI Signals to Target Peripherals (ADC, DAC, SPI Flash)
    -- =========================================================================

    -- Chip Select Mappings
    adc_sen_o  <= cs_n_sig(0);
    dac_sen_o  <= cs_n_sig(1);
    F_CSn      <= cs_n_sig(2);

    -- Clock Multiplexing: Route sclk_sig to Flash (F_sclk) when Flash CS is low, else to ADC/DAC sclk
    F_sclk     <= sclk_sig when (cs_n_sig(2) = '0') else '0';
    adc_sclk_o <= sclk_sig;

    -- MOSI / MISO / Flash Data Multiplexing
    F_MOSI     <= mosi_sig when (cs_n_sig(2) = '0') else '0';
    
    -- Route MISO from SPI Flash when Flash CS is low, otherwise route from ADC SDIO line
    miso_sig   <= F_MISO when (cs_n_sig(2) = '0') else adc_sdio_io;

    -- SDIO Direction and Data Routing Logic (for ADC):
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                first_bit_reg <= '0';
                is_input_mode <= '0';
            else
                if cs_n_sig(0) = '1' then
                    is_input_mode <= '0';
                else
                    first_bit_reg <= mosi_sig;
                    if first_bit_reg = '1' then
                        is_input_mode <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Tri-state buffer control for shared ADC SDIO pin
    adc_sdio_io <= 'Z'      when (is_input_mode = '1' and cs_n_sig(0) = '0') else 
                   mosi_sig;

end architecture rtl;