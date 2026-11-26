library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity true_dual_port_ram is
    generic (
        PORT_A_WIDTH : integer := 32;
        PORT_B_WIDTH : integer := 8;
        PORT_A_DEPTH : integer := 128;
        PORT_B_DEPTH : integer := 512
    );
    port (
        -- Port A: 32-bit APB Bridge Side (sys_clk)
        clk_a_i     : in  std_logic;
        rst_a_i     : in  std_logic;
        clk_en_a_i  : in  std_logic;
        wr_en_a_i   : in  std_logic;
        addr_a_i    : in  std_logic_vector(6 downto 0);
        wr_data_a_i : in  std_logic_vector(31 downto 0);
        rd_data_a_o : out std_logic_vector(31 downto 0);

        -- Port B: 8-bit SPI Master Side (slow_clk)
        clk_b_i     : in  std_logic;
        rst_b_i     : in  std_logic;
        clk_en_b_i  : in  std_logic;
        wr_en_b_i   : in  std_logic;
        addr_b_i    : in  std_logic_vector(8 downto 0);
        wr_data_b_i : in  std_logic_vector(7 downto 0);
        rd_data_b_o : out std_logic_vector(7 downto 0)
    );
end entity true_dual_port_ram;

architecture rtl of true_dual_port_ram is

    -- Four 128x8 symmetric True Dual-Port RAM byte lanes
    type byte_ram_type is array (0 to PORT_A_DEPTH - 1) of std_logic_vector(7 downto 0);
    
    shared variable ram_lane_0 : byte_ram_type := (others => (others => '0'));
    shared variable ram_lane_1 : byte_ram_type := (others => (others => '0'));
    shared variable ram_lane_2 : byte_ram_type := (others => (others => '0'));
    shared variable ram_lane_3 : byte_ram_type := (others => (others => '0'));

    attribute syn_ramstyle : string;
    attribute syn_ramstyle of ram_lane_0 : variable is "block_ram";
    attribute syn_ramstyle of ram_lane_1 : variable is "block_ram";
    attribute syn_ramstyle of ram_lane_2 : variable is "block_ram";
    attribute syn_ramstyle of ram_lane_3 : variable is "block_ram";

    -- Port B internal byte-lane read outputs and registered byte select
    signal rd_b_lane_0  : std_logic_vector(7 downto 0) := (others => '0');
    signal rd_b_lane_1  : std_logic_vector(7 downto 0) := (others => '0');
    signal rd_b_lane_2  : std_logic_vector(7 downto 0) := (others => '0');
    signal rd_b_lane_3  : std_logic_vector(7 downto 0) := (others => '0');
    signal byte_sel_b_q : std_logic_vector(1 downto 0) := "00";

    -- Port B per-lane write enables
    signal we_b_lane_0  : std_logic;
    signal we_b_lane_1  : std_logic;
    signal we_b_lane_2  : std_logic;
    signal we_b_lane_3  : std_logic;

begin

    -- Decode which byte lane Port B is writing to based on addr_b_i(1 downto 0)
    we_b_lane_0 <= '1' when (wr_en_b_i = '1' and addr_b_i(1 downto 0) = "00") else '0';
    we_b_lane_1 <= '1' when (wr_en_b_i = '1' and addr_b_i(1 downto 0) = "01") else '0';
    we_b_lane_2 <= '1' when (wr_en_b_i = '1' and addr_b_i(1 downto 0) = "10") else '0';
    we_b_lane_3 <= '1' when (wr_en_b_i = '1' and addr_b_i(1 downto 0) = "11") else '0';

    -- =========================================================================
    -- Byte Lane 0: Bits [7:0]
    -- =========================================================================
    process(clk_a_i)
    begin
        if rising_edge(clk_a_i) then
            if clk_en_a_i = '1' then
                if wr_en_a_i = '1' then
                    ram_lane_0(to_integer(unsigned(addr_a_i))) := wr_data_a_i(7 downto 0);
                end if;
                rd_data_a_o(7 downto 0) <= ram_lane_0(to_integer(unsigned(addr_a_i)));
            end if;
        end if;
    end process;

    process(clk_b_i)
    begin
        if rising_edge(clk_b_i) then
            if clk_en_b_i = '1' then
                if we_b_lane_0 = '1' then
                    ram_lane_0(to_integer(unsigned(addr_b_i(8 downto 2)))) := wr_data_b_i;
                end if;
                rd_b_lane_0 <= ram_lane_0(to_integer(unsigned(addr_b_i(8 downto 2))));
            end if;
        end if;
    end process;

    -- =========================================================================
    -- Byte Lane 1: Bits [15:8]
    -- =========================================================================
    process(clk_a_i)
    begin
        if rising_edge(clk_a_i) then
            if clk_en_a_i = '1' then
                if wr_en_a_i = '1' then
                    ram_lane_1(to_integer(unsigned(addr_a_i))) := wr_data_a_i(15 downto 8);
                end if;
                rd_data_a_o(15 downto 8) <= ram_lane_1(to_integer(unsigned(addr_a_i)));
            end if;
        end if;
    end process;

    process(clk_b_i)
    begin
        if rising_edge(clk_b_i) then
            if clk_en_b_i = '1' then
                if we_b_lane_1 = '1' then
                    ram_lane_1(to_integer(unsigned(addr_b_i(8 downto 2)))) := wr_data_b_i;
                end if;
                rd_b_lane_1 <= ram_lane_1(to_integer(unsigned(addr_b_i(8 downto 2))));
            end if;
        end if;
    end process;

    -- =========================================================================
    -- Byte Lane 2: Bits [23:16]
    -- =========================================================================
    process(clk_a_i)
    begin
        if rising_edge(clk_a_i) then
            if clk_en_a_i = '1' then
                if wr_en_a_i = '1' then
                    ram_lane_2(to_integer(unsigned(addr_a_i))) := wr_data_a_i(23 downto 16);
                end if;
                rd_data_a_o(23 downto 16) <= ram_lane_2(to_integer(unsigned(addr_a_i)));
            end if;
        end if;
    end process;

    process(clk_b_i)
    begin
        if rising_edge(clk_b_i) then
            if clk_en_b_i = '1' then
                if we_b_lane_2 = '1' then
                    ram_lane_2(to_integer(unsigned(addr_b_i(8 downto 2)))) := wr_data_b_i;
                end if;
                rd_b_lane_2 <= ram_lane_2(to_integer(unsigned(addr_b_i(8 downto 2))));
            end if;
        end if;
    end process;

    -- =========================================================================
    -- Byte Lane 3: Bits [31:24]
    -- =========================================================================
    process(clk_a_i)
    begin
        if rising_edge(clk_a_i) then
            if clk_en_a_i = '1' then
                if wr_en_a_i = '1' then
                    ram_lane_3(to_integer(unsigned(addr_a_i))) := wr_data_a_i(31 downto 24);
                end if;
                rd_data_a_o(31 downto 24) <= ram_lane_3(to_integer(unsigned(addr_a_i)));
            end if;
        end if;
    end process;

    process(clk_b_i)
    begin
        if rising_edge(clk_b_i) then
            if clk_en_b_i = '1' then
                if we_b_lane_3 = '1' then
                    ram_lane_3(to_integer(unsigned(addr_b_i(8 downto 2)))) := wr_data_b_i;
                end if;
                rd_b_lane_3 <= ram_lane_3(to_integer(unsigned(addr_b_i(8 downto 2))));
            end if;
        end if;
    end process;

    -- =========================================================================
    -- Port B Read Output Multiplexer (Aligned with 1-cycle RAM read latency)
    -- =========================================================================
    process(clk_b_i)
    begin
        if rising_edge(clk_b_i) then
            if clk_en_b_i = '1' then
                byte_sel_b_q <= addr_b_i(1 downto 0);
            end if;
        end if;
    end process;

    with byte_sel_b_q select
        rd_data_b_o <= rd_b_lane_0 when "00",
                       rd_b_lane_1 when "01",
                       rd_b_lane_2 when "10",
                       rd_b_lane_3 when others;

end architecture rtl;