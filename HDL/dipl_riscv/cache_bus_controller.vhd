--===============================================================================
--MIT License

--Copyright (c) 2022 Tomislav Harmina

--Permission is hereby granted, free of charge, to any person obtaining a copy
--of this software and associated documentation files (the "Software"), to deal
--in the Software without restriction, including without limitation the rights
--to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--copies of the Software, and to permit persons to whom the Software is
--furnished to do so, subject to the following conditions:

--The above copyright notice and this permission notice shall be included in all
--copies or substantial portions of the Software.

--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--SOFTWARE.
--===============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity cache_bus_controller is
    generic(
        ADDR_SIZE : integer;
        ENTRY_SIZE_BYTES : integer;
        ASSOCIATIVITY : integer;
        ENTRIES_PER_CACHELINE : integer;
        ENABLE_NONCACHEABLE_ADDRS : integer;
        ENABLE_WRITES : integer
    );
    port(
        bus_addr_write : out std_logic_vector(ADDR_SIZE - 1 downto 0);
        bus_data_write : out std_logic_vector(ENTRY_SIZE_BYTES * 8 - 1 downto 0);
        bus_addr_read : out std_logic_vector(ADDR_SIZE - 1 downto 0);
        bus_data_read : in std_logic_vector(ENTRY_SIZE_BYTES * 8 - 1 downto 0);
        bus_stbw : out std_logic_vector(3 downto 0);
        bus_ackw : in std_logic;
        bus_stbr : out std_logic;
        bus_ackr : in std_logic;
    
        load_addr : in std_logic_vector(ADDR_SIZE - 1 downto 0);
        load_location_in_set : in std_logic_vector(ASSOCIATIVITY - 1 downto 0);
        load_en : in std_logic;
        load_word_en : in std_logic;
        load_cancel : in std_logic;
        load_busy : out std_logic;
        
        cache_write_word : in std_logic_vector(ENTRY_SIZE_BYTES * 8 - 1 downto 0);
        cache_write_cacheline : in std_logic_vector(ENTRY_SIZE_BYTES * 8 * ENTRIES_PER_CACHELINE - 1 downto 0);
        cache_write_addr : in std_logic_vector(ADDR_SIZE - 1 downto 0);
        cache_write_size : in std_logic_vector(1 downto 0);
        cache_write_en : in std_logic;
        cache_write_word_en : in std_logic;
        write_busy : out std_logic;
        write_done : out std_logic;
        
        cache_writeback_en : out std_logic;
        cache_writeback_addr : out std_logic_vector(ADDR_SIZE - 1 downto 0);
        cache_writeback_set_addr : out std_logic_vector(ASSOCIATIVITY - 1 downto 0);
        cache_writeback_cacheline : out std_logic_vector(ENTRY_SIZE_BYTES * 8 * ENTRIES_PER_CACHELINE - 1 downto 0);
        
        fwd_en : out std_logic;
        
        clk : in std_logic;
        reset : in std_logic
    );
end cache_bus_controller;

architecture rtl of cache_bus_controller is
    constant CACHELINE_DATA_SIZE : integer := ENTRY_SIZE_BYTES * 8 * ENTRIES_PER_CACHELINE;
    constant CACHELINE_ADDR_LOW : integer := integer(ceil(log2(real(ENTRY_SIZE_BYTES))));
    constant CACHELINE_ADDR_HIGH : integer := integer(ceil(log2(real(ENTRIES_PER_CACHELINE)))) + CACHELINE_ADDR_LOW;
    

    type bus_read_state_type is (IDLE,
                                 BUSY,
                                 WRITEBACK,
                                 DELAY_CYCLE);
                                 
    type bus_write_state_type is (IDLE,
                                  BUSY,
                                  FINALIZE);
                                 
    signal bus_read_state : bus_read_state_type;
    signal bus_read_state_next : bus_read_state_type;
    
    signal bus_write_state : bus_write_state_type;
    signal bus_write_state_next : bus_write_state_type;
    signal bus_stbw_reg : std_logic_vector(3 downto 0);
    
    signal fetched_words_counter : unsigned(integer(ceil(log2(real(ENTRIES_PER_CACHELINE)))) - 1 downto 0);
    signal words_to_fetch : unsigned(integer(ceil(log2(real(ENTRIES_PER_CACHELINE)))) - 1 downto 0);
    signal fetched_cacheline_data : std_logic_vector(CACHELINE_DATA_SIZE - 1 downto 0);
    
    signal stored_words_counter : unsigned(integer(ceil(log2(real(ENTRIES_PER_CACHELINE)))) - 1 downto 0);
    signal words_to_store : unsigned(integer(ceil(log2(real(ENTRIES_PER_CACHELINE)))) - 1 downto 0);
    signal bus_curr_addr_write : std_logic_vector(ADDR_SIZE - 1 downto 0); 
    
    signal i_load_location_in_set_reg : std_logic_vector(ASSOCIATIVITY - 1 downto 0);
    signal i_evict_cacheline_reg : std_logic_vector(ENTRY_SIZE_BYTES * 8 * ENTRIES_PER_CACHELINE - 1 downto 0);
    signal i_bus_curr_addr_read : std_logic_vector(ADDR_SIZE - 1 downto 0); 
    signal i_writeback_addr : std_logic_vector(ADDR_SIZE - 1 downto 0); 
    
    signal word_aligned : std_logic_vector(ADDR_SIZE - 1 downto 0);
    signal word_stbw : std_logic_vector(3 downto 0);
begin
    process(all)
    begin
        word_aligned <= (others => '0');
        word_stbw <= (others => '0');
        
        if (cache_write_size = "00") then             -- SB
                    case cache_write_addr(1 downto 0) is      -- Generation of strobe signal based on address (alignment assumed)
                        when "00" =>
                            word_stbw <= "0001";
                            word_aligned(7 downto 0) <= cache_write_word(31 - 24 downto 0);
                        when "01" =>
                            word_stbw <= "0010";
                            word_aligned(15 downto 8) <= cache_write_word(31 - 24 downto 0);
                        when "10" =>
                            word_stbw <= "0100";
                            word_aligned(23 downto 16) <= cache_write_word(31 - 24 downto 0);
                        when "11" =>
                            word_stbw <= "1000";
                            word_aligned(31 downto 24) <= cache_write_word(31 - 24 downto 0);
                        when others =>
                            word_stbw <= "0000";
                    end case;
                elsif (cache_write_size = "01") then   
                    case cache_write_addr(1) is   
                        when '0' =>
                            word_stbw <= "0011";
                            word_aligned(15 downto 0) <= cache_write_word(31 - 16 downto 0);
                        when '1' =>
                            word_stbw <= "1100";
                            word_aligned(31 downto 16) <= cache_write_word(31 - 16 downto 0);
                        when others =>
                            word_stbw <= "0000";
                    end case;
                elsif (cache_write_size = "10") then          -- SW
                    word_stbw <= "1111";
                    word_aligned <= cache_write_word(31 downto 0);
        end if; 
    end process;

    -- ==================== BUS SIDE LOGIC ====================
    load_busy <= '1' when bus_read_state /= IDLE else '0';
    write_busy <= '1' when bus_write_state /= IDLE else '0';
    
    bus_addr_read_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                i_bus_curr_addr_read <= (others => '0');
                i_writeback_addr <= (others => '0');
            else
                if (bus_read_state = IDLE and load_en = '1') then
                    i_bus_curr_addr_read <= load_addr;
                    i_writeback_addr <= load_addr;
                    i_load_location_in_set_reg <= load_location_in_set;
                    words_to_fetch <= to_unsigned(ENTRIES_PER_CACHELINE - 1, integer(ceil(log2(real(ENTRIES_PER_CACHELINE)))));
                elsif (load_word_en = '1' and bus_write_state = IDLE) then
                    if (ENABLE_NONCACHEABLE_ADDRS = 1) then
                        i_bus_curr_addr_read <= load_addr;
                        i_writeback_addr <= load_addr;
                        i_load_location_in_set_reg <= (others => '0');
                        words_to_fetch <= to_unsigned(0, integer(ceil(log2(real(ENTRIES_PER_CACHELINE)))));
                    end if;
                elsif (bus_ackr = '1') then
                    i_bus_curr_addr_read <= std_logic_vector(unsigned(i_bus_curr_addr_read) + 4);
                end if;
            end if;
        end if;
    end process;
    cache_writeback_set_addr <= i_load_location_in_set_reg;
    
    bus_read_sm_state_reg_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                bus_read_state <= IDLE;
            else
                bus_read_state <= bus_read_state_next;
            end if;
        end if;
    end process;
    
    bus_read_sm_next_state : process(all)
    begin
        if (bus_read_state = IDLE) then
            bus_read_state_next <= IDLE;
            
            if ((load_en = '1' or load_word_en = '1') and load_cancel = '0') then
                bus_read_state_next <= BUSY;
            end if;
        elsif (bus_read_state = BUSY) then
            bus_read_state_next <= BUSY;
        
            if (load_cancel = '1') then
                bus_read_state_next <= IDLE;
            elsif (fetched_words_counter = words_to_fetch and bus_ackr = '1') then
                bus_read_state_next <= WRITEBACK;
            end if;
        elsif (bus_read_state = WRITEBACK) then
            bus_read_state_next <= DELAY_CYCLE;
            
            if (load_cancel = '1') then
                bus_read_state_next <= IDLE;
            end if;
        elsif (bus_read_state = DELAY_CYCLE) then
            bus_read_state_next <= IDLE;
        else
            bus_read_state_next <= IDLE;
        end if;
    end process;
    
    bus_read_sm_actions : process(all)
    begin
        cache_writeback_en <= '0';
        bus_stbr <= '0';
        fwd_en <= '0';

        if (bus_read_state = IDLE) then

        elsif (bus_read_state = BUSY) then
            bus_stbr <= '1';
        elsif (bus_read_state = WRITEBACK) then
            cache_writeback_en <= not load_cancel;
        elsif (bus_read_state = DELAY_CYCLE) then
            fwd_en <= '1';
        end if;
    end process;
    
    fetched_cacheline_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (bus_read_state = BUSY and bus_ackr = '1') then
                fetched_cacheline_data(32 * (to_integer(unsigned(i_bus_curr_addr_read(CACHELINE_ADDR_HIGH - 1 downto CACHELINE_ADDR_LOW))) + 1) - 1 downto
                                       32 * to_integer(unsigned(i_bus_curr_addr_read(CACHELINE_ADDR_HIGH - 1 downto CACHELINE_ADDR_LOW)))) <= bus_data_read;
            end if;
        end if;
    end process;
    
    fetched_instrs_counter_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (bus_read_state = IDLE) then
                fetched_words_counter <= (others => '0');
            elsif (bus_read_state = BUSY and bus_ackr = '1') then
                fetched_words_counter <= fetched_words_counter + 1;
            end if;
        end if;
    end process;
    
    bus_addr_read <= i_bus_curr_addr_read;
    cache_writeback_cacheline <= fetched_cacheline_data;
    cache_writeback_addr <= i_writeback_addr;
    -- ========================================================
    bus_cntrl_write_gen : if (ENABLE_WRITES = 1) generate
        bus_write_sm_state_reg_cntrl : process(clk)
        begin
            if (rising_edge(clk)) then
                if (reset = '1') then
                    bus_write_state <= IDLE;
                else
                    bus_write_state <= bus_write_state_next;
                end if;
            end if;
        end process;
        
        bus_write_cntrl : process(clk)
        begin
            if (rising_edge(clk)) then
                if (reset = '1') then
                    bus_curr_addr_write <= (others => '0');
                    i_evict_cacheline_reg <= (others => '0');
                else
                    if (cache_write_en = '1' and bus_write_state = IDLE) then
                        words_to_store <= to_unsigned(ENTRIES_PER_CACHELINE - 1, integer(ceil(log2(real(ENTRIES_PER_CACHELINE)))));
                        i_evict_cacheline_reg <= cache_write_cacheline;
                        bus_curr_addr_write <= cache_write_addr;
                        bus_stbw_reg <= "1111";
                    elsif (cache_write_word_en = '1' and bus_write_state = IDLE) then
                        if (ENABLE_NONCACHEABLE_ADDRS = 1) then
                            words_to_store <= to_unsigned(0, integer(ceil(log2(real(ENTRIES_PER_CACHELINE)))));
                            i_evict_cacheline_reg(ENTRY_SIZE_BYTES * 8 - 1 downto 0) <= word_aligned;
                            bus_curr_addr_write <= cache_write_addr(ADDR_SIZE - 1 downto 2) & "00";
                            bus_stbw_reg <= word_stbw;
                        end if;
                    elsif (bus_ackw = '1' and bus_write_state = BUSY) then
                        bus_curr_addr_write <= std_logic_vector(unsigned(bus_curr_addr_write) + 4);
                    end if;
                end if;
            end if;
        end process;    
        bus_addr_write <= bus_curr_addr_write;
        
        bus_write_sm_next_state : process(all)
        begin
            case bus_write_state is
                when IDLE => 
                    if (cache_write_en = '1' or cache_write_word_en = '1') then
                        bus_write_state_next <= BUSY;
                    else
                        bus_write_state_next <= IDLE;
                    end if;
                when BUSY => 
                    if (stored_words_counter = words_to_store and bus_ackw = '1') then
                        bus_write_state_next <= FINALIZE;
                    else
                        bus_write_state_next <= BUSY;
                    end if;
                when FINALIZE => 
                    bus_write_state_next <= IDLE;
            end case;
        end process;
        
        bus_write_sm_actions : process(all)
        begin
            bus_stbw <= "0000";
            write_done <= '0';
            
            case bus_write_state is
                when IDLE => 
    
                when BUSY => 
                    bus_stbw <= bus_stbw_reg;
                when FINALIZE => 
                    write_done <= '1';
            end case;
        end process;
        
        stored_words_counter_cntrl : process(clk)
        begin
            if (rising_edge(clk)) then
                if (bus_write_state = IDLE) then
                    stored_words_counter <= (others => '0');
                elsif (bus_write_state = BUSY and bus_ackw = '1') then
                    stored_words_counter <= stored_words_counter + 1;
                end if;
            end if;
        end process;
        
        bus_write_data_sel_proc : process(all)
        begin
            bus_data_write <= i_evict_cacheline_reg((ENTRY_SIZE_BYTES * 8 * (to_integer(stored_words_counter) + 1)) - 1 downto (ENTRY_SIZE_BYTES * 8 * to_integer(stored_words_counter)));
        end process;
    end generate;
    
        
end rtl;
















