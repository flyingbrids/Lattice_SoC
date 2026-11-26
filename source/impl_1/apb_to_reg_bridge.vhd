library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity apb_to_reg_bridge is
    generic (
        NUM_REGS  : integer := 49;  -- Number of 16-bit registers (0 to 48)
        ADDR_BITS : integer := 8    -- Bits mapped from paddr_i(8 downto 1)
    );
    port (
        -- APB Slave Interface (from apb_splitter reg_* branch)
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

        -- Flattened 16-bit Register Buses (16 bits per register index)
        reg_wr_bus_o  : out std_logic_vector((NUM_REGS * 16) - 1 downto 0);
        reg_rd_bus_i  : in  std_logic_vector((NUM_REGS * 16) - 1 downto 0);
        reg_wr_stb_o  : out std_logic_vector(NUM_REGS - 1 downto 0)
    );
end entity apb_to_reg_bridge;

architecture rtl of apb_to_reg_bridge is

    signal reg_idx   : integer range 0 to (2**(ADDR_BITS)) - 1;
    signal half_sel  : std_logic; -- paddr_i(1): 0 = lower 16 bits [15:0], 1 = upper 16 bits [31:16]
    signal apb_wr_en : std_logic;
    signal apb_rd_en : std_logic;
    signal read_valid : std_logic;
    signal read_mux : std_logic_vector(31 downto 0);

begin

    -- Extract 16-bit register index from paddr_i(8 downto 1)
    reg_idx   <= to_integer(unsigned(paddr_i(ADDR_BITS downto 1)));
    -- Extract half-word selector from address bit [1]
    half_sel  <= paddr_i(0);

    -- APB transfer qualifiers
    apb_wr_en <= psel_i and penable_i and pwrite_i;
    apb_rd_en <= psel_i and (not pwrite_i);

    -- Writes complete without waiting; reads wait until PRDATA is registered.
    pready_o  <= '1' when pwrite_i = '1' else read_valid;
    pslverr_o <= '0';

    -- =========================================================================
    -- 1. Generate Loop: 16-bit Register Writes selected via paddr_i(1)
    -- =========================================================================
    gen_apb_regs : for i in 0 to NUM_REGS - 1 generate
        process(pclk_i, presetn_i)
        begin
            if presetn_i = '0' then
                reg_wr_bus_o(((i + 1) * 16) - 1 downto (i * 16)) <= (others => '0');
                reg_wr_stb_o(i) <= '0';
            elsif rising_edge(pclk_i) then
                reg_wr_stb_o(i) <= '0';

                if (apb_wr_en = '1') and (reg_idx = i) then
                    if half_sel = '0' then
                        -- Write from lower 16 bits of 32-bit APB write data [15:0]
                        reg_wr_bus_o(((i + 1) * 16) - 1 downto (i * 16)) <= pwdata_i(15 downto 0);
                    else
                        -- Write from upper 16 bits of 32-bit APB write data [31:16]
                        reg_wr_bus_o(((i + 1) * 16) - 1 downto (i * 16)) <= pwdata_i(31 downto 16);
                    end if;
                    reg_wr_stb_o(i) <= '1';
                end if;
            end if;
        end process;
    end generate gen_apb_regs;

    -- =========================================================================
    -- 2. Combinational APB Read Multiplexer
    -- =========================================================================
    process(reg_rd_bus_i, reg_idx, half_sel, apb_rd_en, presetn_i)
        variable read_data : std_logic_vector(31 downto 0);
    begin
        read_data := (others => '0');
        if presetn_i = '1' and apb_rd_en = '1' then
            for i in 0 to NUM_REGS - 1 loop
                if reg_idx = i then
                    if half_sel = '0' then
                        read_data(15 downto 0) :=
                                reg_rd_bus_i(((i + 1) * 16) - 1 downto (i * 16));
                    else
                        read_data(31 downto 16) :=
                                reg_rd_bus_i(((i + 1) * 16) - 1 downto (i * 16));
                    end if;
                end if;
            end loop;
        end if;
        read_mux <= read_data;
    end process;

    -- Latch read data and assert read-ready together, after one access cycle.
    process(pclk_i, presetn_i)
    begin
        if presetn_i = '0' then
            prdata_o <= (others => '0');
            read_valid <= '0';
        elsif rising_edge(pclk_i) then
            if psel_i = '0' or read_valid = '1' then
                read_valid <= '0';
            elsif apb_rd_en = '1' then
                prdata_o <= read_mux;
                read_valid <= '1';
            end if;
        end if;
    end process;

end architecture rtl;