library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity apb_splitter is
    port (
        -- =====================================================================
        -- Upstream Master APB Interface (32-bit Data & Address)
        -- =====================================================================
        pclk_i         : in  std_logic;
        presetn_i      : in  std_logic;
        psel_i         : in  std_logic;
        penable_i      : in  std_logic;
        pwrite_i       : in  std_logic;
        paddr_i        : in  std_logic_vector(31 downto 0);
        pwdata_i       : in  std_logic_vector(31 downto 0);
        prdata_o       : out std_logic_vector(31 downto 0);
        pready_o       : out std_logic;
        pslverr_o      : out std_logic;

        -- =====================================================================
        -- Interface 1: FPGA Register Interface (32-bit Data, 32-bit Address)
        -- Occupies first 512 Bytes (Offset 0x000 to 0x1FF -> 0x0000_8000 to 0x0000_81FF)
        -- =====================================================================
        reg_psel_o     : out std_logic;
        reg_penable_o  : out std_logic;
        reg_pwrite_o   : out std_logic;
        reg_paddr_o    : out std_logic_vector(31 downto 0);
        reg_pwdata_o   : out std_logic_vector(31 downto 0);
        reg_prdata_i   : in  std_logic_vector(31 downto 0);
        reg_pready_i   : in  std_logic;
        reg_pslverr_i  : in  std_logic;

        -- =====================================================================
        -- Interface 2: SPI BRAM Interface (32-bit Data, 32-bit Address)
        -- Occupies next 512 Bytes (Offset 0x200 to 0x3FF -> 0x0000_8200 to 0x0000_83FF)
        -- =====================================================================
        spi_psel_o     : out std_logic;
        spi_penable_o  : out std_logic;
        spi_pwrite_o   : out std_logic;
        spi_paddr_o    : out std_logic_vector(31 downto 0);
        spi_pwdata_o   : out std_logic_vector(31 downto 0);
        spi_prdata_i   : in  std_logic_vector(31 downto 0);
        spi_pready_i   : in  std_logic;
        spi_pslverr_i  : in  std_logic;

        -- =====================================================================
        -- Interface 3: Memory Stream Interface (32-bit Data, 32-bit Address)
        -- Occupies remaining 3 KB (Offset 0x400 to 0xFFF -> 0x0000_8400 to 0x0000_8FFF)
        -- =====================================================================
        stream_psel_o    : out std_logic;
        stream_penable_o : out std_logic;
        stream_pwrite_o  : out std_logic;
        stream_paddr_o   : out std_logic_vector(31 downto 0);
        stream_pwdata_o  : out std_logic_vector(31 downto 0);
        stream_prdata_i  : in  std_logic_vector(31 downto 0);
        stream_pready_i  : in  std_logic;
        stream_pslverr_i : in  std_logic
    );
end entity apb_splitter;

architecture rtl of apb_splitter is

    type target_slave_type is (SLAVE_REG, SLAVE_SPI, SLAVE_STREAM);
    signal active_slave : target_slave_type;

begin

    -- =========================================================================
    -- Address decoding uses bits [11:9] within the APB window at 0x0000_8000.
    -- =========================================================================
    process(paddr_i)
    begin
        case paddr_i(11 downto 9) is
            when "000" =>
                -- Offset 0x000 to 0x1FF (First 512 Bytes) -> FPGA Registers
                active_slave <= SLAVE_REG;
            when "001" =>
                -- Offset 0x200 to 0x3FF (Next 512 Bytes) -> SPI BRAM
                active_slave <= SLAVE_SPI;
            when others =>
                -- Offset 0x400 to 0xFFF (Remaining 3 KB) -> Memory Stream
                active_slave <= SLAVE_STREAM;
        end case;
    end process;

    -- =========================================================================
    -- Downstream APB Signal Routing
    -- =========================================================================
    
    -- Control strobes broadcasted to all interfaces
    reg_penable_o    <= penable_i;
    reg_pwrite_o     <= pwrite_i;
    spi_penable_o    <= penable_i;
    spi_pwrite_o     <= pwrite_i;
    stream_penable_o <= penable_i;
    stream_pwrite_o  <= pwrite_i;

    -- PSEL decoding per target slave
    reg_psel_o       <= psel_i when (active_slave = SLAVE_REG)    else '0';
    spi_psel_o       <= psel_i when (active_slave = SLAVE_SPI)    else '0';
    stream_psel_o    <= psel_i when (active_slave = SLAVE_STREAM) else '0';

    -- Pass-through for 32-bit address and data buses
    reg_paddr_o      <= paddr_i;
    reg_pwdata_o     <= pwdata_i;
    
    spi_paddr_o      <= paddr_i;
    spi_pwdata_o     <= pwdata_i;
    
    stream_paddr_o   <= paddr_i;
    stream_pwdata_o  <= pwdata_i;

    -- =========================================================================
    -- Upstream Response Multiplexing (Read Data, Ready, and Slverr)
    -- =========================================================================
    process(active_slave, reg_prdata_i, reg_pready_i, reg_pslverr_i,
            spi_prdata_i, spi_pready_i, spi_pslverr_i,
            stream_prdata_i, stream_pready_i, stream_pslverr_i)
    begin
        case active_slave is
            when SLAVE_REG =>
                prdata_o  <= reg_prdata_i;
                pready_o  <= reg_pready_i;
                pslverr_o <= reg_pslverr_i;

            when SLAVE_SPI =>
                prdata_o  <= spi_prdata_i;
                pready_o  <= spi_pready_i;
                pslverr_o <= spi_pslverr_i;

            when SLAVE_STREAM =>
                prdata_o  <= stream_prdata_i;
                pready_o  <= stream_pready_i;
                pslverr_o <= stream_pslverr_i;
        end case;
    end process;

end architecture rtl;