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

use WORK.PKG_CPU.ALL;

entity uart_simple is
    port(
        bus_data_write : in std_logic_vector(31 downto 0);
        bus_data_read : out std_logic_vector(31 downto 0);
        bus_addr_write : in std_logic_vector(3 downto 0);
        bus_addr_read : in std_logic_vector(3 downto 0);
        bus_ack : out std_logic;
        
        tx : out std_logic;
        rx : in std_logic;
        
        wr_en : in std_logic;
        rd_en : in std_logic;
        clk : in std_logic;
        reset : in std_logic
    );
end uart_simple;

architecture rtl of uart_simple is
    COMPONENT ila_1
    PORT (
        clk : IN STD_LOGIC;
    
    
    
        probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe4 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
        probe5 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
        probe6 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        probe7 : IN STD_LOGIC_VECTOR(4 DOWNTO 0)
    );
    END COMPONENT  ;


    -- REGISTERS
    signal div_h_reg : std_logic_vector(7 downto 0);
    signal div_l_reg : std_logic_vector(7 downto 0);
    signal data_tx_reg : std_logic_vector(7 downto 0);
    signal data_rx_reg : std_logic_vector(7 downto 0);
    signal status_reg : std_logic_vector(7 downto 0);       -- [0: TX START | 1: TX FINISHED | 2 - 7: RESERVED]
    signal status_reg_en : std_logic;       -- [0: TX START | 1: TX FINISHED | 2 - 7: RESERVED]
    
    signal baud_div : std_logic_vector(15 downto 0);
    
    -- INTERNAL SIGNALS
    signal baud_gen_counter_reg : unsigned(15 downto 0);
    signal baud_gen_counter_next : unsigned(15 downto 0);
    signal baud_gen_counter_en : std_logic;
    signal baud_tick : std_logic;
    signal baud_gen_x16_counter_reg : unsigned(15 downto 0);
    signal baud_gen_x16_counter_next : unsigned(15 downto 0);
    signal baud_gen_x16_counter_en : std_logic;
    signal baud_tick_x16 : std_logic;
    
    signal tx_start : std_logic;
    signal tx_end : std_logic;
    
    signal bits_transmitted : unsigned(2 downto 0);
    
    type uart_tx_state_type is (IDLE, START_BIT, BUSY, END_BIT);
    signal uart_tx_state : uart_tx_state_type;
    signal uart_tx_state_next : uart_tx_state_type;
    
    
    
    type uart_rx_state_type is (IDLE, START_RX, START_BIT, RECV, END_BIT);
    signal uart_rx_state : uart_rx_state_type;
    signal uart_rx_state_next : uart_rx_state_type;
    
    signal uart_rx_sampling_counter_reg : unsigned(3 downto 0);
    signal uart_rx_sample_en : std_logic;
    signal recv_en : std_logic;
    signal data_temp_rx_reg : std_logic_vector(7 downto 0);  
    
    signal rx_reg : std_logic;
    signal rx_start : std_logic;
    signal rx_end : std_logic;
    
    signal bits_received : unsigned(2 downto 0);
    
    -- BUS INTERNAL SIGNALS
    signal bus_data_read_i : std_logic_vector(31 downto 0);
    signal ack_i : std_logic;
begin
    -- REGISTER CONTROL
    status_reg_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                status_reg <= (others => '0');
            elsif (status_reg_en = '1') then
                if (tx_end = '1') then
                    status_reg(0) <= '0';
                elsif (tx_start = '1') then
                    status_reg(0) <= '1';
                end if;
                
                if ((rd_en = '1' and bus_addr_read = X"4") and rx_end = '0') then
                    status_reg(1) <= '0';
                elsif (rx_end = '1') then
                    status_reg(1) <= '1';
                end if;
            end if;
        end if;
    end process;
    
    status_reg_en <= tx_start or tx_end or rx_start or rx_end or rd_en;
    tx_start <= '1' when wr_en = '1' and bus_addr_write = X"8" else '0';
    tx_end <= '1' when uart_tx_state = END_BIT and baud_tick = '1' else '0'; 
    
    registers_write_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                div_l_reg <= (others => '1');
                div_h_reg <= (others => '1');
            elsif (wr_en = '1') then
                case bus_addr_write is 
                    when X"0" =>
                        div_l_reg <= bus_data_write(7 downto 0);
                    when X"4" =>
                        div_h_reg <= bus_data_write(7 downto 0);
                    when X"8" =>
                        data_tx_reg <= bus_data_write(7 downto 0);
                    when others =>
                    
                end case;
            end if;
        end if;
    end process;
    
    registers_read_proc : process(all)
    begin
        bus_data_read(31 downto 8) <= (others => '0');
        case bus_addr_read is  
            when X"0" =>
                bus_data_read(7 downto 0) <= div_l_reg;
            when X"4" =>
                bus_data_read(7 downto 0) <= data_rx_reg;
            when X"8" =>
                bus_data_read(7 downto 0) <= data_tx_reg;
            when X"C" =>
                bus_data_read(7 downto 0) <= status_reg;
            when others => 
                bus_data_read(7 downto 0) <= (others => '0');
        end case;
    end process;

    --bus_data_read_i <= status_reg & data_tx_reg & div_h_reg & div_l_reg;
--    registers_read_proc : process(clk)
--    begin
--        if (rising_edge(clk)) then
--            bus_data_read <= bus_data_read_i;
--        end if;
--    end process;
    
    -- BAUD GENERATION
    baud_gen_counter_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                baud_gen_counter_reg <= (others => '0');
            elsif (baud_gen_counter_en = '1') then
                baud_gen_counter_reg <= baud_gen_counter_next;
            end if;
            
            if (reset = '1') then
                baud_gen_x16_counter_reg <= (others => '0');
            else
                baud_gen_x16_counter_reg <= baud_gen_x16_counter_next;
            end if;
        end if;
    end process;
    
    baud_div <= div_h_reg & div_l_reg;
    baud_gen_counter_next_sel : process(all)
    begin
        if ((uart_tx_state = IDLE) or (std_logic_vector(baud_gen_counter_reg) = baud_div)) then
            baud_gen_counter_next <= (others => '0');
        else
            baud_gen_counter_next <= baud_gen_counter_reg + 1;
        end if;
    end process;
    baud_tick <= '1' when std_logic_vector(baud_gen_counter_reg) = baud_div else '0';
    
    baud_gen_x16_counter_next_proc : process(all)
    begin
        if (baud_gen_x16_counter_en = '0' or (std_logic_vector(baud_gen_x16_counter_reg) = "0000" & baud_div(15 downto 4))) then
            baud_gen_x16_counter_next <= (others => '0');
        else
            baud_gen_x16_counter_next <= baud_gen_x16_counter_reg + 1;
        end if;
    end process;
    baud_tick_x16 <= '1' when std_logic_vector(baud_gen_x16_counter_reg) = ("0000" & baud_div(15 downto 4)) else '0';
    
    sampling_counter_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (baud_gen_x16_counter_en = '0') then
                uart_rx_sampling_counter_reg <= (others => '0');
            elsif (baud_tick_x16 = '1') then
                uart_rx_sampling_counter_reg <= uart_rx_sampling_counter_reg + 1;
            end if;
        end if;
    end process;
    uart_rx_sample_en <= '1' when uart_rx_sampling_counter_reg = "1000" and baud_tick_x16 = '1' else '0';
    
    -- TX ENGINE
    bits_transmitted_counter_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                bits_transmitted <= (others => '0');
            else
                if (uart_tx_state = BUSY) then
                    if (baud_tick = '1') then
                        bits_transmitted <= bits_transmitted + 1;
                    end if;
                else
                    bits_transmitted <= (others => '0');
                end if;
            end if;
        end if;
    end process;
    
    tx_sm_state_reg_proc : process(clk) 
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                uart_tx_state <= IDLE;
            else
                uart_tx_state <= uart_tx_state_next;
            end if;
        end if;
    end process;
    
    tx_sm_state_next : process(all)
    begin
        case uart_tx_state is
            when IDLE =>
                if (status_reg(0) = '1') then
                    uart_tx_state_next <= START_BIT;
                else
                    uart_tx_state_next <= IDLE;
                end if;
            when START_BIT =>
                if (baud_tick = '1') then
                    uart_tx_state_next <= BUSY;
                else
                    uart_tx_state_next <= START_BIT;                
                end if;
            when BUSY =>
                if (bits_transmitted = 7 and baud_tick = '1') then
                    uart_tx_state_next <= END_BIT;
                else
                    uart_tx_state_next <= BUSY;
                end if;
            when END_BIT =>
                if (baud_tick = '1') then
                    uart_tx_state_next <= IDLE;
                else
                    uart_tx_state_next <= END_BIT;
                end if;
            when others =>
                uart_tx_state_next <= IDLE;
        end case;
    end process;
    
    tx_proc : process(all)
    begin
        case uart_tx_state is
            when IDLE =>
                tx <= '1';
                baud_gen_counter_en <= '0';
            when START_BIT =>
                tx <= '0';
                baud_gen_counter_en <= '1';
            when BUSY =>
                tx <= data_tx_reg(to_integer(bits_transmitted));
                baud_gen_counter_en <= '1';
            when END_BIT =>
                tx <= '1';
                baud_gen_counter_en <= '1';
        end case;
    end process;
    
    -- RX ENGINE
    rx_reg_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                data_rx_reg <= (others => '0');
            end if;
            
            if (rx_end = '1') then
                data_rx_reg <= data_temp_rx_reg;
            end if;
            
            rx_reg <= rx;
        end if;
    end process;
    
    rx_sm_state_reg_proc : process(clk) 
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                uart_rx_state <= IDLE;
            else
                uart_rx_state <= uart_rx_state_next;
            end if;
        end if;
    end process;
    
    rx_sm_next_state_proc : process(all)
    begin
        case uart_rx_state is
            when IDLE => 
                if (rx_reg = '0') then
                    uart_rx_state_next <= START_RX;
                else
                    uart_rx_state_next <= IDLE;
                end if;
            when START_RX =>
                 uart_rx_state_next <= START_BIT;
            when START_BIT =>             -- Detect whether start is real (not caused by noise) 
                if (uart_rx_sample_en = '1') then
                    if (rx_reg = '0') then
                        uart_rx_state_next <= RECV;
                    else
                        uart_rx_state_next <= IDLE;
                    end if;
                else
                    uart_rx_state_next <= START_BIT;
                end if; 
            when RECV => 
                if (uart_rx_sample_en = '1' and bits_received = "111") then
                    uart_rx_state_next <= END_BIT;
                else
                    uart_rx_state_next <= RECV;
                end if;
            when END_BIT => 
                if (uart_rx_sample_en = '1') then
                    uart_rx_state_next <= IDLE;
                else
                    uart_rx_state_next <= END_BIT;
                end if;
        end case;
    end process;
    
    rx_sm_output_proc : process(all)
    begin
        rx_start <= '0';
        rx_end <= '0';
        recv_en <= '0';
        baud_gen_x16_counter_en <= '0';
        case uart_rx_state is
            when IDLE => 
            
            when START_RX => 
                rx_start <= '1';
            when START_BIT => 
                baud_gen_x16_counter_en <= '1';
            when RECV => 
                baud_gen_x16_counter_en <= '1';
                recv_en <= '1';
            when END_BIT => 
                baud_gen_x16_counter_en <= '1';
                
                if (uart_rx_sample_en = '1') then
                    rx_end <= '1';
                end if;
            when others =>
                
        end case;
    end process;
    
    rx_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                data_temp_rx_reg <= (others => '0');
                bits_received <= (others => '0');
            else
                if (uart_rx_sample_en = '1' and recv_en = '1') then
                    data_temp_rx_reg(7) <= rx_reg;
                    data_temp_rx_reg(6 downto 0) <= data_temp_rx_reg(7 downto 1);
                    
                    bits_received <= bits_received + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- BUS INTERNAL SIGNALS
    ack_generate_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                ack_i <= '0';
            else
                ack_i <= (wr_en or rd_en) and not ack_i; 
            end if;
        end if;
    end process;
    
    bus_ack <= ack_i;
    
    uart_ila_gen : if (ENABLE_UART_ILA = true) generate
        your_instance_name : ila_1
        PORT MAP (
            clk => clk,
        
        
        
            probe0(0) => baud_gen_x16_counter_en, 
            probe1(0) => uart_rx_sample_en, 
            probe2(0) => rx_start, 
            probe3(0) => rx, 
            probe4 => status_reg, 
            probe5 => data_rx_reg, 
            probe6 => std_logic_vector(to_unsigned(uart_rx_state_type'pos(uart_rx_state_next), 3)),
            probe7 => std_logic_vector(to_unsigned(uart_rx_state_type'pos(uart_rx_state), 5))
        );
    end generate;

end rtl;















