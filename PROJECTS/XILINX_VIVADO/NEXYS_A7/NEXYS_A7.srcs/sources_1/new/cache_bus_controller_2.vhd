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

-- TODO: WRITE -> READ FORWARDING
-- TODO: GENERALIZE WRITE LOGIC FOR DIFFERENT DATA & BURST SIZES

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.PKG_CPU.ALL;

entity cache_bus_controller_2 is
    generic(
        ADDRESS_WIDTH : integer;
        DATA_WIDTH : integer;
        BYTES_PER_ENTRY : integer;
        MAX_BURST_LENGTH : integer;
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
        fetch_data_size : in std_logic_vector(1 downto 0);
        fetch_burst_length : in std_logic_vector(f_bits_needed(MAX_BURST_LENGTH) downto 0);
        fetch_en : in std_logic;
        fetched_cacheline_data : out std_logic_vector(MAX_BURST_LENGTH * BYTES_PER_ENTRY * 8 - 1 downto 0);
        fetched_cacheline_tag : out std_logic_vector(TAG_BITS - 1 downto 0);
        fetched_cacheline_valid : out std_logic;
        
        writeback_data : in std_logic_vector(BYTES_PER_ENTRY * MAX_BURST_LENGTH * 8 - 1 downto 0);
        writeback_address : in std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
        writeback_data_size : in std_logic_vector(1 downto 0);
        writeback_burst_length : in std_logic_vector(f_bits_needed(MAX_BURST_LENGTH) downto 0);
        writeback_en: in std_logic;
        
        clk : in std_logic;
        reset : in std_logic
    );
end cache_bus_controller_2;

architecture rtl of cache_bus_controller_2 is
    type read_fifo_entry_type is record
        address : std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
        burst_length : std_logic_vector(f_bits_needed(MAX_BURST_LENGTH) downto 0);
        data_size : std_logic_vector(1 downto 0);
        valid : std_logic;
    end record;
    
    type write_fifo_entry_type is record
        address : std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
        data : std_logic_vector(BYTES_PER_ENTRY * MAX_BURST_LENGTH * 8 - 1 downto 0);
        data_size : std_logic_vector(1 downto 0);
        burst_length : std_logic_vector(f_bits_needed(MAX_BURST_LENGTH) downto 0);
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
    signal read_fetch_data_reg : std_logic_vector(MAX_BURST_LENGTH * BYTES_PER_ENTRY * 8 - 1 downto 0);
    signal read_fetch_size_reg : std_logic_vector(f_bits_needed(MAX_BURST_LENGTH) downto 0);
    signal read_fetched_words_counter : unsigned(f_bits_needed(MAX_BURST_LENGTH) downto 0);
    signal read_burst_length : unsigned(f_bits_needed(MAX_BURST_LENGTH) downto 0);
    
    type write_sm_states_type is (
        IDLE,
        WRITE,
        WRITE_DONE
    );
    signal write_state : write_sm_states_type;
    signal write_state_next : write_sm_states_type;
    signal write_addr_reg : std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    signal write_data_reg : std_logic_vector(MAX_BURST_LENGTH * BYTES_PER_ENTRY * 8 - 1 downto 0);
    signal write_size_reg : std_logic_vector(1 downto 0);
    signal written_words_counter : unsigned(f_bits_needed(MAX_BURST_LENGTH) downto 0);
    signal write_burst_length : unsigned(f_bits_needed(MAX_BURST_LENGTH) downto 0);
    signal write_cycle_start : std_logic;
    signal bus_stbw_temp : std_logic_vector(3 downto 0);
    
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
                end if;
                
                if (read_fifo_dequeue = '1') then
                    if (read_fifo_empty = '0') then
                        read_fifo_head <= read_fifo_head_next;
                    end if;
                end if;
                
                if (read_fifo_enqueue = '1' and read_fifo_dequeue = '1') then
                    read_fifo_num_elements <= read_fifo_num_elements;
                elsif (read_fifo_enqueue = '1') then
                    read_fifo_num_elements <= read_fifo_num_elements + 1;
                elsif (read_fifo_dequeue = '1') then
                    read_fifo_num_elements <= read_fifo_num_elements - 1;
                end if;
                -- ===========================================
                
                -- ================ WRITE FIFO ================
                if (write_fifo_enqueue = '1') then
                    write_fifo_tail <= write_fifo_tail_next;
                    
                end if;
                
                if (write_fifo_dequeue = '1') then
                    if (write_fifo_empty = '0') then
                        write_fifo_head <= write_fifo_head_next;
                        write_fifo_num_elements <= write_fifo_num_elements - 1;
                    end if;
                end if;
                
                if (write_fifo_enqueue = '1' and write_fifo_dequeue = '1') then
                    write_fifo_num_elements <= write_fifo_num_elements;
                elsif (write_fifo_enqueue = '1') then
                    write_fifo_num_elements <= write_fifo_num_elements + 1;
                elsif (write_fifo_dequeue = '1') then
                    write_fifo_num_elements <= write_fifo_num_elements - 1;
                    
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
                    read_fifo(to_integer(read_fifo_tail)).data_size <= fetch_data_size;
                    read_fifo(to_integer(read_fifo_tail)).burst_length <= fetch_burst_length;
                    read_fifo(to_integer(read_fifo_tail)).valid <= '1';
                end if;
                
                if (read_fifo_dequeue = '1') then
                    read_fifo(to_integer(read_fifo_head)).valid <= '0';
                end if;
                
                if (write_fifo_enqueue = '1') then
                    write_fifo(to_integer(write_fifo_tail)).address <= writeback_address;
                    write_fifo(to_integer(write_fifo_tail)).data <= writeback_data;
                    write_fifo(to_integer(write_fifo_tail)).data_size <= writeback_data_size;
                    write_fifo(to_integer(write_fifo_tail)).burst_length <= writeback_burst_length;
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
                
                if (read_fetched_words_counter = read_burst_length - 1 and bus_ackr = '1') then
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
    read_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                read_fetched_words_counter <= to_unsigned(0, f_bits_needed(MAX_BURST_LENGTH) + 1);
            else
                if (fetch_cycle_start = '1') then
                    read_fetched_words_counter <= to_unsigned(0, f_bits_needed(MAX_BURST_LENGTH) + 1);
                    read_burst_length <= unsigned(read_fifo(to_integer(read_fifo_head)).burst_length);
                                           
                    read_fetch_size_reg <= read_fifo(to_integer(read_fifo_head)).burst_length;
                    read_fetch_addr_reg <= read_fifo(to_integer(read_fifo_head)).address;
                end if;
                
                if (bus_ackr = '1' and read_state = FETCH) then
                    read_fetched_words_counter <= read_fetched_words_counter + 1;
                    read_fetch_addr_reg <= std_logic_vector(unsigned(read_fetch_addr_reg) + 4);
                    
                    
                    read_fetch_data_reg(BYTES_PER_ENTRY * 8 * to_integer(read_fetched_words_counter + 1) - 1 downto BYTES_PER_ENTRY * 8 * to_integer(read_fetched_words_counter)) <=
                        bus_data_read;
                end if;
            end if;
        end if;
    end process;
    fetched_cacheline_data <= read_fetch_data_reg;
    fetched_cacheline_tag <= read_fetch_addr_reg(31 downto 32 - TAG_BITS);
    
    bus_addr_read <= read_fetch_addr_reg;
    
    -- ============================================================================
    --                            WRITE STATE MACHINE
    -- ============================================================================
    write_sm_next_state_reg_cntrl : process(all)
    begin
        case (write_state) is
            when IDLE =>
                write_state_next <= IDLE; 
                if (write_fifo_empty = '0') then
                    write_state_next <= WRITE;
                end if;
            when WRITE => 
                write_state_next <= WRITE;
                if (written_words_counter = write_burst_length - 1) then
                    write_state_next <= WRITE_DONE;
                end if;
            when WRITE_DONE =>
                write_state_next <= IDLE; 
        end case;
    end process;
    
    write_sm_state_reg_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                write_state <= IDLE;
            else
                write_state <= write_state_next;
            end if;
        end if;
    end process;
    
    write_sm_eff : process(all)
    begin
        write_cycle_start <= '0';
        write_fifo_dequeue <= '0';
        bus_stbw <= (others => '0');
        case (write_state) is
            when IDLE => 
                if (write_fifo_empty = '0') then
                    write_cycle_start <= '1';
                end if;
            when WRITE => 
                bus_stbw <= bus_stbw_temp;
            when WRITE_DONE => 
                write_fifo_dequeue <= '1';
        end case;
    end process;
    
    -- ============================================================================
    --                               WRITE LOGIC
    -- ============================================================================
    write_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                
            else
                if (write_cycle_start = '1') then
                    written_words_counter <= to_unsigned(0, f_bits_needed(MAX_BURST_LENGTH) + 1);
                    write_burst_length <= unsigned(write_fifo(to_integer(write_fifo_head)).burst_length);
                    write_addr_reg <= write_fifo(to_integer(write_fifo_head)).address;
                    
                    write_data_reg <= write_fifo(to_integer(write_fifo_head)).data;
                    write_size_reg <= write_fifo(to_integer(write_fifo_head)).data_size;
                end if;
                
                if (bus_ackw = '1' and write_state = WRITE) then
                    written_words_counter <= written_words_counter + 1;
                    write_addr_reg <= std_logic_vector(unsigned(write_addr_reg) + 4);
                    
                    -- Shift to the right after every write so that the lower 32 bits of the register contain the data that we want to write next
                    write_data_reg(BYTES_PER_ENTRY * MAX_BURST_LENGTH * 8 - 1 downto BYTES_PER_ENTRY * MAX_BURST_LENGTH * 8 - 32) <= (others => '0');
                    write_data_reg(BYTES_PER_ENTRY * MAX_BURST_LENGTH * 8 - 33 downto 0) <= write_data_reg(BYTES_PER_ENTRY * MAX_BURST_LENGTH * 8 - 1 downto 32);
                end if;
            end if;
        end if;
    end process;
    bus_addr_write <= write_addr_reg;
    
    write_data_cntrl : process(all)
    begin
        bus_data_write <= (others => '0');
        bus_stbw_temp <= (others => '0');
        case write_size_reg is
            when "00" =>                      -- BYTE (8 bits)
                case write_addr_reg(1 downto 0) is
                    when "00" =>
                        bus_data_write(7 downto 0) <= write_data_reg(7 downto 0); 
                        bus_stbw_temp <= "0001";
                    when "01" =>
                        bus_data_write(15 downto 8) <= write_data_reg(7 downto 0);
                        bus_stbw_temp <= "0010"; 
                    when "10" => 
                        bus_data_write(23 downto 16) <= write_data_reg(7 downto 0);
                        bus_stbw_temp <= "0100";
                    when "11" => 
                        bus_data_write(31 downto 24) <= write_data_reg(7 downto 0);
                        bus_stbw_temp <= "1000";
                    when others =>
                end case;
            when "01" =>                      -- HALF-WORD (16 bits)
                case write_addr_reg(1) is
                    when '0' =>
                        bus_data_write(15 downto 0) <= write_data_reg(15 downto 0);
                        bus_stbw_temp <= "0011"; 
                    when '1' =>
                        bus_data_write(31 downto 16) <= write_data_reg(15 downto 0);
                        bus_stbw_temp <= "1100"; 
                    when others =>
                end case;
            when "10" =>                      -- WORD (32 bits)
                bus_data_write <= write_data_reg(31 downto 0);
                bus_stbw_temp <= "1111";
            when others =>
                
        end case;
    end process;
end rtl;










