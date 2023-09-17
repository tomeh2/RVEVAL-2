--===============================================================================
--MIT License

--Copyright (c) 2023 Tomislav Harmina

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
use WORK.PKG_CPU.ALL;

entity cache_bus_controller_2 is
    generic(
        ADDRESS_WIDTH : integer;
        DATA_WIDTH : integer;
        ENTRY_SIZE_BYTES : integer;
        ENTRIES_PER_CACHELINE : integer;
        TAG_BITS : integer;
    
        READ_FIFO_DEPTH : integer;
        WRITE_FIFO_DEPTH : integer
    );
    port(
        bus_addr_write : out std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
        bus_data_write : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        bus_addr_read : out std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
        bus_data_read : in std_logic_vector(DATA_WIDTH - 1 downto 0);
        bus_stbw : out std_logic_vector(3 downto 0);
        bus_ackw : in std_logic;
        bus_stbr : out std_logic;
        bus_ackr : in std_logic;
    
        fetch_address : in std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
        fetch_cacheable : in std_logic;
        fetch_size : in std_logic_vector(1 downto 0);
        fetch_en : in std_logic;
        fetched_cacheline_data : out std_logic_vector(ENTRIES_PER_CACHELINE * ENTRY_SIZE_BYTES * 8 - 1 downto 0);
        fetched_cacheline_tag : out std_logic_vector(TAG_BITS - 1 downto 0);
        fetched_cacheline_valid : out std_logic;
        
        writeback_address : in std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
        writeback_size : in std_logic_vector(1 downto 0);
        writeback_cacheable : in std_logic;
        writeback_en: in std_logic;
        
        clk : in std_logic;
        reset : in std_logic
    );
end cache_bus_controller_2;

architecture rtl of cache_bus_controller_2 is
    type read_fifo_entry_type is record
        address : std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
        size : std_logic_vector(1 downto 0);
        cacheable : std_logic;
        valid : std_logic;
    end record;
    
    type write_fifo_entry_type is record
        address : std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
        data : std_logic_vector(ENTRY_SIZE_BYTES * ENTRIES_PER_CACHELINE * 8 - 1 downto 0);
        size : std_logic_vector(1 downto 0);
        cacheable : std_logic;
        valid : std_logic;
    end record;

    signal read_fifo_head : unsigned(f_bits_needed(READ_FIFO_DEPTH) - 1 downto 0);
    signal read_fifo_head_next : unsigned(f_bits_needed(READ_FIFO_DEPTH) - 1 downto 0);
    signal read_fifo_tail : unsigned(f_bits_needed(READ_FIFO_DEPTH) - 1 downto 0);
    signal read_fifo_tail_next : unsigned(f_bits_needed(READ_FIFO_DEPTH) - 1 downto 0);
    signal read_fifo_num_elements : unsigned(f_bits_needed(READ_FIFO_DEPTH) downto 0);
    signal read_fifo_full : std_logic;
    signal read_fifo_empty : std_logic;
    signal read_fifo_enqueue : std_logic;
    signal read_fifo_dequeue : std_logic;
    type read_fifo_type is array (0 to READ_FIFO_DEPTH - 1) of read_fifo_entry_type;
    signal read_fifo : read_fifo_type;
    signal fetch_cycle_start : std_logic;
    
    type read_sm_states_type is (
        IDLE,
        FETCH,
        FETCH_DONE
    );
    signal read_state : read_sm_states_type;
    signal read_state_next : read_sm_states_type;
    signal read_fetch_addr_reg : std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    signal read_fetch_data_reg : std_logic_vector(ENTRIES_PER_CACHELINE * ENTRY_SIZE_BYTES * 8 - 1 downto 0);
    signal read_fetch_size_reg : std_logic_vector(1 downto 0);
    signal read_fetched_words_counter : unsigned(f_bits_needed(ENTRIES_PER_CACHELINE) downto 0);
    signal read_words_to_fetch : unsigned(f_bits_needed(ENTRIES_PER_CACHELINE) downto 0);
    
    signal write_fifo_head : unsigned(f_bits_needed(WRITE_FIFO_DEPTH) - 1 downto 0);
    signal write_fifo_head_next : unsigned(f_bits_needed(WRITE_FIFO_DEPTH) - 1 downto 0);
    signal write_fifo_tail : unsigned(f_bits_needed(WRITE_FIFO_DEPTH) - 1 downto 0);
    signal write_fifo_tail_next : unsigned(f_bits_needed(WRITE_FIFO_DEPTH) - 1 downto 0);
    signal write_fifo_num_elements : unsigned(f_bits_needed(WRITE_FIFO_DEPTH) downto 0);
    signal write_fifo_full : std_logic;
    signal write_fifo_empty : std_logic;
    signal write_fifo_enqueue : std_logic;
    signal write_fifo_dequeue : std_logic;
    type write_fifo_type is array (0 to WRITE_FIFO_DEPTH - 1) of write_fifo_entry_type;
    signal write_fifo : write_fifo_type;
begin
    read_fifo_head_next <= to_unsigned(0, f_bits_needed(READ_FIFO_DEPTH)) when read_fifo_head = to_unsigned(READ_FIFO_DEPTH - 1, f_bits_needed(READ_FIFO_DEPTH)) else
                           read_fifo_head + 1;
    read_fifo_tail_next <= to_unsigned(0, f_bits_needed(READ_FIFO_DEPTH)) when read_fifo_tail = to_unsigned(READ_FIFO_DEPTH - 1, f_bits_needed(READ_FIFO_DEPTH)) else
                           read_fifo_tail + 1;
    write_fifo_head_next <= to_unsigned(0, f_bits_needed(WRITE_FIFO_DEPTH)) when write_fifo_head = to_unsigned(WRITE_FIFO_DEPTH - 1, f_bits_needed(WRITE_FIFO_DEPTH)) else
                           write_fifo_head + 1;
    write_fifo_tail_next <= to_unsigned(0, f_bits_needed(WRITE_FIFO_DEPTH)) when write_fifo_tail = to_unsigned(WRITE_FIFO_DEPTH - 1, f_bits_needed(WRITE_FIFO_DEPTH)) else
                           write_fifo_tail + 1;
                           
    read_fifo_enqueue <= fetch_en and not read_fifo_full;
    write_fifo_enqueue <= writeback_en and not write_fifo_full;

    read_fifo_full <= '1' when read_fifo_num_elements = READ_FIFO_DEPTH else '0';
    read_fifo_empty <= '1' when read_fifo_num_elements = 0 else '0';
    
    write_fifo_full <= '1' when write_fifo_num_elements = WRITE_FIFO_DEPTH else '0';
    write_fifo_empty <= '1' when write_fifo_num_elements = 0 else '0';

    fifo_cntrs_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                read_fifo_head <= to_unsigned(0, f_bits_needed(READ_FIFO_DEPTH));
                read_fifo_tail <= to_unsigned(0, f_bits_needed(READ_FIFO_DEPTH));
                read_fifo_num_elements <= to_unsigned(0, f_bits_needed(READ_FIFO_DEPTH) + 1);
                
                write_fifo_head <= to_unsigned(0, f_bits_needed(WRITE_FIFO_DEPTH));
                write_fifo_tail <= to_unsigned(0, f_bits_needed(WRITE_FIFO_DEPTH));
                write_fifo_num_elements <= to_unsigned(0, f_bits_needed(WRITE_FIFO_DEPTH) + 1);
            else
                -- ================ READ FIFO ================
                if (read_fifo_enqueue = '1') then
                    read_fifo_tail <= read_fifo_tail_next;
                    read_fifo_num_elements <= read_fifo_num_elements + 1;
                end if;
                
                if (read_fifo_dequeue = '1') then
                    if (read_fifo_empty = '0') then
                        read_fifo_head <= read_fifo_head_next;
                        read_fifo_num_elements <= read_fifo_num_elements - 1;
                    end if;
                end if;
                -- ===========================================
                
                -- ================ WRITE FIFO ================
                if (write_fifo_enqueue = '1') then
                    write_fifo_tail <= write_fifo_tail_next;
                end if;
                
                if (write_fifo_dequeue = '1') then
                    if (write_fifo_empty = '0') then
                        write_fifo_head <= write_fifo_head_next;
                    end if;
                end if;
                -- ============================================
            end if;
        end if;
    end process;
    
    fifo_data_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                for i in 0 to READ_FIFO_DEPTH - 1 loop
                    read_fifo(i).valid <= '0';
                    write_fifo(i).valid <= '0';
                end loop;
            else
                if (read_fifo_enqueue = '1') then
                    read_fifo(to_integer(read_fifo_tail)).address <= fetch_address;
                    read_fifo(to_integer(read_fifo_tail)).size <= fetch_size;
                    read_fifo(to_integer(read_fifo_tail)).cacheable <= fetch_cacheable;
                    read_fifo(to_integer(read_fifo_tail)).valid <= '1';
                end if;
                
                if (read_fifo_dequeue = '1') then
                    read_fifo(to_integer(read_fifo_head)).valid <= '0';
                end if;
                
                if (write_fifo_enqueue = '1') then
                    write_fifo(to_integer(write_fifo_tail)).address <= writeback_address;
                    write_fifo(to_integer(write_fifo_tail)).size <= writeback_size;
                    write_fifo(to_integer(write_fifo_tail)).cacheable <= writeback_cacheable;
                    write_fifo(to_integer(write_fifo_tail)).valid <= '1';
                end if;
                
                if (write_fifo_dequeue = '1') then
                    write_fifo(to_integer(write_fifo_head)).valid <= '0';
                end if;
            end if;
        end if;
    end process;

    -- ============================================================================
    --                            READ STATE MACHINE
    -- ============================================================================
    read_sm_next_state_logic : process(all)
    begin
        case (read_state) is
            when IDLE => 
                read_state_next <= IDLE;
                if (read_fifo_empty = '0') then
                    read_state_next <= FETCH;
                end if;
            when FETCH => 
                read_state_next <= FETCH;
                
                if (read_fetched_words_counter = read_words_to_fetch - 1 and bus_ackr = '1') then
                    read_state_next <= FETCH_DONE;
                end if;
            when FETCH_DONE => 
                 read_state_next <= IDLE;
        end case;
    end process;
    
    read_sm_state_reg_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                read_state <= IDLE;
            else
                read_state <= read_state_next;
            end if;
        end if;
    end process;
    
    read_sm_eff : process(all)
    begin
        bus_stbr <= '0';
        fetch_cycle_start <= '0';
        fetched_cacheline_valid <= '0';
        read_fifo_dequeue <= '0';
        case (read_state) is
            when IDLE => 
                if (read_fifo_empty = '0') then
                    fetch_cycle_start <= '1';
                end if;
            when FETCH => 
                bus_stbr <= '1';
            when FETCH_DONE => 
                fetched_cacheline_valid <= '1';
                read_fifo_dequeue <= '1';
        end case;
    end process;
    
    -- ============================================================================
    --                                  READ LOGIC
    -- ============================================================================
    read_reg_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                read_fetched_words_counter <= to_unsigned(0, f_bits_needed(ENTRIES_PER_CACHELINE) + 1);
            else
                if (fetch_cycle_start = '1') then
                    read_fetched_words_counter <= to_unsigned(0, f_bits_needed(ENTRIES_PER_CACHELINE) + 1);
                    read_words_to_fetch <= to_unsigned(ENTRIES_PER_CACHELINE, f_bits_needed(ENTRIES_PER_CACHELINE) + 1) when read_fifo(to_integer(read_fifo_head)).cacheable = '1' else
                                           to_unsigned(1, f_bits_needed(ENTRIES_PER_CACHELINE) + 1);
                                           
                    read_fetch_size_reg <= read_fifo(to_integer(read_fifo_head)).size;
                    read_fetch_addr_reg <= read_fifo(to_integer(read_fifo_head)).address;
                end if;
                
                if (bus_ackr = '1' and read_state = FETCH) then
                    read_fetched_words_counter <= read_fetched_words_counter + 1;
                    read_fetch_addr_reg <= std_logic_vector(unsigned(read_fetch_addr_reg) + 4);
                    
                    read_fetch_data_reg(ENTRY_SIZE_BYTES * 8 * to_integer(read_fetched_words_counter + 1) - 1 downto ENTRY_SIZE_BYTES * 8 * to_integer(read_fetched_words_counter)) <=
                        bus_data_read;
                end if;
            end if;
        end if;
    end process;
    fetched_cacheline_data <= read_fetch_data_reg;
    fetched_cacheline_tag <= read_fetch_addr_reg(31 downto 32 - TAG_BITS);
    
    bus_addr_read <= read_fetch_addr_reg;

end rtl;










