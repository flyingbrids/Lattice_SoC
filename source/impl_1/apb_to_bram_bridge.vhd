library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity apb_to_bram_bridge is
    port (
        -- APB Bus Interface (from APB Master / Processor)
        pclk_i         : in  std_logic;                     -- APB Clock
        presetn_i      : in  std_logic;                     -- APB Active-Low Reset
        psel_i         : in  std_logic;                     -- APB Select
        penable_i      : in  std_logic;                     -- APB Enable
        pwrite_i       : in  std_logic;                     -- APB Write (1 = Write, 0 = Read)
        paddr_i        : in  std_logic_vector(6 downto 0);  -- APB 7-bit Word Address Bus (matches BRAM word address width)
        pwdata_i       : in  std_logic_vector(31 downto 0); -- APB Write Data (32-bit)
        prdata_o       : out std_logic_vector(31 downto 0); -- APB Read Data (32-bit)
        pready_o       : out std_logic;                     -- APB Ready handshake
        pslverr_o      : out std_logic;                     -- APB Slave Error (tied low)

        -- Dual-Port RAM Port A Interface (32-bit fixed width)
        bram_clk_o     : out std_logic;                     -- Clock out to RAM Port A
        bram_rst_o     : out std_logic;                     -- Reset out to RAM Port A
        bram_clk_en_o  : out std_logic;                     -- Clock Enable for RAM Port A
        bram_wr_en_o   : out std_logic;                     -- Write Enable (1 = Write, 0 = Read)
        bram_addr_o    : out std_logic_vector(6 downto 0);  -- Word Address (7 bits for 128 x 32-bit words = 512 bytes)
        bram_wr_data_o : out std_logic_vector(31 downto 0); -- Write Data to RAM Port A
        bram_rd_data_i : in  std_logic_vector(31 downto 0)  -- Read Data from RAM Port A
    );
end entity apb_to_bram_bridge;

architecture rtl of apb_to_bram_bridge is

    -- State machine for APB protocol handshake (Access phase completion)
    type apb_state_type is (ST_IDLE, ST_ACCESS);
    signal state : apb_state_type := ST_IDLE;
	signal pready_int : std_logic;

begin

    -- Drive clock and reset straight through to RAM Port A
    bram_clk_o <= pclk_i;
    bram_rst_o <= not presetn_i;  -- Convert active-low preset to active-high ram reset if needed, or keep sync
    pslverr_o  <= '0';            -- No error response generated
   
    pready_o <= pready_int; 
	prdata_o <= bram_rd_data_i;
    -- APB Protocol State Machine & RAM Control Signal Generation
    process(pclk_i, presetn_i)
    begin
        if presetn_i = '0' then
            state          <= ST_IDLE;
            pready_int       <= '0';
            bram_clk_en_o  <= '0';
            bram_wr_en_o   <= '0';
            bram_addr_o    <= (others => '0');
            bram_wr_data_o <= (others => '0');
        elsif rising_edge(pclk_i) then
            -- Default strobes
            pready_int      <= '0';
            bram_clk_en_o <= '0';
            bram_wr_en_o  <= '0';

            case state is
                when ST_IDLE =>
                    -- APB Setup Phase: When PSEL is asserted and PENABLE is low
                    if psel_i = '1' then
                        -- Direct assignment since paddr_i is now 7 bits matching bram_addr_o
                        bram_addr_o <= paddr_i;
                        
                        if pwrite_i = '1' then
                            -- Write Transfer Setup
                            bram_wr_data_o <= pwdata_i;
                            bram_wr_en_o   <= '1';
                            bram_clk_en_o  <= '1';
                        else
                            -- Read Transfer Setup
                            bram_wr_en_o   <= '0';
                            bram_clk_en_o  <= '1';
                        end if;

                        state <= ST_ACCESS;
                    end if;

                when ST_ACCESS =>
                    -- APB Access Phase: PENABLE is high
                    if penable_i = '1' then
                        pready_int <= '1'; -- Complete the APB transfer handshake
                        
                        --if pwrite_i = '0' then
                            ---- Latch read data coming back from the BRAM 1-cycle read latency
                            --prdata_v := bram_rd_data_i;
                        --end if;
                         
                        if pready_int = '1' then -- handshaked
                           state <= ST_IDLE;
                        end if;
                    else
                        state <= ST_IDLE;
                    end if;

                when others =>
                    state <= ST_IDLE;
            end case;
        end if;
    end process;

end architecture rtl;