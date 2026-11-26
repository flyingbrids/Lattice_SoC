library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_master_bram is
    port (
        -- System Clocks & Resets
        clk_i           : in  std_logic;                     -- System clock
        rst_i           : in  std_logic;                     -- Synchronous active-high reset
        
        -- Configuration Registers
        byte_count_i    : in  std_logic_vector(8 downto 0);  -- Number of bytes to transfer per transaction (up to 512)
        control_reg_i   : in  std_logic_vector(7 downto 0);  -- Control Register:
                                                             --   bit [0]     : 1 = Read, 0 = Write
                                                             --   bit [3:1]   : Slave CS select (001=CS0, 010=CS1, 100=CS2)
                                                             --   bit [4]     : 1 = Invert SCLK (CPOL), 0 = Normal SCLK
                                                             --   bit [7:5]   : Reserved / Future use
        start_i         : in  std_logic;                     -- Strobe pulse to start a new transaction
        busy_o          : out std_logic;                     -- High when SPI transaction is in progress
        done_o          : out std_logic;                     -- Strobe pulse when transaction completes
        
        -- Block RAM (BRAM) Interface (9-bit address for 512 bytes)
        bram_addr_o     : out std_logic_vector(8 downto 0);  -- Read/Write address pointer for BRAM
        bram_en_o       : out std_logic;                     -- BRAM enable
        bram_we_o       : out std_logic;                     -- BRAM write enable (1 = Write data received from SPI into BRAM)
        bram_wr_data_o  : out std_logic_vector(7 downto 0);  -- Data to write into BRAM (during SPI read transactions)
        bram_rd_data_i  : in  std_logic_vector(7 downto 0);  -- Data read from BRAM (to be transmitted out via SPI)
        
        -- SPI Physical Interface
        sclk_o          : out std_logic;                     -- SPI Serial Clock
        mosi_o          : out std_logic;                     -- Master Out Slave In
        miso_i          : in  std_logic;                     -- Master In Slave Out
        cs_n_o          : out std_logic_vector(2 downto 0)   -- Chip Selects for 3 Slave devices (Active Low)
    );
end entity spi_master_bram;

architecture rtl of spi_master_bram is

    -- State Machine Definition
    type state_type is (ST_IDLE, ST_LOAD_BYTE, ST_WAIT_BRAM, ST_SHIFT_BIT, ST_SAVE_BYTE, ST_DONE);
    signal state            : state_type := ST_IDLE;

    -- Internal Registers & Counters
    signal bit_cnt          : unsigned(2 downto 0);              -- Counts 0 to 7 bits
    signal byte_cnt         : unsigned(8 downto 0);              -- Tracks remaining bytes in transaction
    signal byte_limit       : unsigned(8 downto 0);              -- Latched byte count limit
    signal addr_ptr         : unsigned(8 downto 0);              -- BRAM address tracker
    signal shift_reg_tx     : std_logic_vector(7 downto 0);      -- Transmit shift register
    signal shift_reg_rx     : std_logic_vector(7 downto 0);      -- Receive shift register
    signal sclk_int         : std_logic;
    signal is_read          : std_logic;
    signal cs_sel           : std_logic_vector(2 downto 0);
    signal cpol             : std_logic;                         -- Clock polarity bit

begin

    -- Control register decoding
    is_read <= control_reg_i(0);
    cs_sel  <= control_reg_i(3 downto 1);
    cpol    <= control_reg_i(4);

    -- Main SPI Controller State Machine
    process(clk_i)
        variable shift_reg_tx_v : std_logic_vector(7 downto 0);
    begin
        if rising_edge(clk_i) then
            shift_reg_tx_v := shift_reg_tx;

            if rst_i = '1' then
                state           <= ST_IDLE;
                sclk_int        <= '0';
                mosi_o          <= '0';
                cs_n_o          <= "111";
                busy_o          <= '0';
                done_o          <= '0';
                bram_en_o       <= '0';
                bram_we_o       <= '0';
                bram_addr_o     <= (others => '0');
                bram_wr_data_o  <= (others => '0');
                bit_cnt         <= (others => '0');
                byte_cnt        <= (others => '0');
                byte_limit      <= (others => '0');
                addr_ptr        <= (others => '0');
                shift_reg_tx_v  := (others => '0');
                shift_reg_rx    <= (others => '0');
            else
                -- Default strobes
                done_o    <= '0';
                bram_en_o <= '0';
                bram_we_o <= '0';

                case state is
                    when ST_IDLE =>
                        sclk_int <= '0';
                        busy_o   <= '0';
                        cs_n_o   <= "111";
                        if start_i = '1' and unsigned(byte_count_i) > 0 then
                            busy_o      <= '1';
                            byte_limit  <= unsigned(byte_count_i);
                            byte_cnt    <= (others => '0');
                            addr_ptr    <= (others => '0');
                            -- Drive appropriate active-low CS based on control register bits [3:1]
                            case cs_sel is
                                when "001"  => cs_n_o <= "110";
                                when "010"  => cs_n_o <= "101";
                                when "100"  => cs_n_o <= "011";
                                when others => cs_n_o <= "111";
                            end case;
                            state <= ST_LOAD_BYTE;
                        end if;

                    when ST_LOAD_BYTE =>
                        -- Request byte from BRAM at current address pointer
                        bram_en_o   <= '1';
                        bram_we_o   <= '0';
                        bram_addr_o <= std_logic_vector(addr_ptr);
                        bit_cnt     <= "111"; -- 8 bits to shift (7 down to 0)
                        sclk_int    <= '0';
                        state       <= ST_WAIT_BRAM;

                    when ST_WAIT_BRAM =>
                        state <= ST_SHIFT_BIT;

                    when ST_SHIFT_BIT =>
                        -- Latch BRAM data into transmit shift register on the first entry
                        if bit_cnt = "111" and sclk_int = '0' then
                            shift_reg_tx_v := bram_rd_data_i;
                        end if;

                        if sclk_int = '0' then
                            -- Setup MOSI data on leading edge
                            mosi_o   <= shift_reg_tx_v(7); -- MSB first
                            sclk_int <= '1';             -- Drive internal SCLK high
                        else
                            -- Sample MISO on following edge
                            shift_reg_rx <= shift_reg_rx(6 downto 0) & miso_i;
                            sclk_int     <= '0';          -- Drop internal SCLK low
                            
                            if bit_cnt = 0 then
                                state <= ST_SAVE_BYTE;
                            else
                                bit_cnt      <= bit_cnt - 1;
                                shift_reg_tx_v := shift_reg_tx_v(6 downto 0) & '0';
                            end if;
                        end if;

                    when ST_SAVE_BYTE =>
                        sclk_int <= '0';
                        -- If Master Read transaction, write received byte back into BRAM
                        if is_read = '1' then
                            bram_en_o      <= '1';
                            bram_we_o      <= '1';
                            bram_addr_o    <= std_logic_vector(addr_ptr);
                            bram_wr_data_o <= shift_reg_rx;
                        end if;

                        -- Increment address & check if all bytes in transaction are done
                        addr_ptr <= addr_ptr + 1;
                        byte_cnt <= byte_cnt + 1;

                        if (byte_cnt + 1) >= byte_limit then
                            state <= ST_DONE;
                        else
                            state <= ST_LOAD_BYTE;
                        end if;

                    when ST_DONE =>
                        cs_n_o   <= "111"; -- Deassert Chip Select
                        sclk_int <= '0';
                        mosi_o   <= '0';
                        busy_o   <= '0';
                        done_o   <= '1';   -- Assert completion pulse
                        state    <= ST_IDLE;

                    when others =>
                        state <= ST_IDLE;
                end case;
            end if;

            shift_reg_tx <= shift_reg_tx_v;
        end if;
    end process;

    -- Drive serial clock output with optional inversion based on CPOL control bit
    sclk_o <= sclk_int xor cpol;

end architecture rtl;