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
use WORK.PKG_CPU.ALL;

entity cpu is
    port(uart_rx : in std_logic;
        uart_tx : out std_logic;
        uart_cts : out std_logic;
        uart_rts : in std_logic;
        
        gpio_i : in std_logic_vector(31 downto 0);
        gpio_o : out std_logic_vector(31 downto 0);
    
        clk_cpu : in std_logic;
        
        reset_cpu : in std_logic
    );
end cpu;

architecture structural of cpu is 
    COMPONENT ila_0
    PORT (
        clk : IN STD_LOGIC;
    
    
    
        probe0 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
        probe1 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
        probe2 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
        probe3 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
        probe4 : IN STD_LOGIC_VECTOR(3 DOWNTO 0); 
        probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
    );
    END COMPONENT  ;

        -- TEMPORARY BUS STUFF
    signal bus_addr_read : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
    signal bus_addr_write : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
    signal bus_data_read : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal bus_data_write : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal bus_stbr : std_logic;
    signal bus_stbw : std_logic_vector(3 downto 0);
    signal bus_ackr : std_logic;
    signal bus_ackw : std_logic;
    
    signal resetn : std_logic;
    signal ram_en : std_logic;
    signal ram_read_valid_1 : std_logic;
    signal ram_read_valid_2 : std_logic;
    
    signal bus_data_read_rom : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal bus_data_read_ram : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal bus_data_read_uart : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal bus_data_read_gpio : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal bus_data_read_perfc : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    
    signal cs_uart : std_logic;
    signal cs_ram : std_logic;
    
    signal re_rom : std_logic;
    signal re_ram : std_logic;
    signal re_uart : std_logic;
    signal re_gpio : std_logic;
    signal re_perfc : std_logic;
    signal stbw_ram : std_logic_vector(3 downto 0);
    signal stbw_gpio : std_logic_vector(3 downto 0);
    signal we_uart : std_logic;
    
    signal ackr_uart : std_logic;
    signal ackr_rom : std_logic;
    signal ackr_ram : std_logic;
    signal ackr_gpio : std_logic;
    signal ackr_perfc : std_logic;
    signal ackw_uart : std_logic;
    signal ackw_ram : std_logic;
    signal ackw_gpio : std_logic;
begin
    bus_debug_gen : if (ENABLE_EXT_BUS_ILA = true) generate
        your_instance_name : ila_0
        PORT MAP (
            clk => clk_cpu,
        
            probe0 => bus_addr_read, 
            probe1 => bus_addr_write, 
            probe2 => bus_data_read, 
            probe3 => bus_data_write, 
            probe4 => bus_stbw, 
            probe5(0) => bus_ackw, 
            probe6(0) => bus_stbr,
            probe7(0) => bus_ackr
        );
    end generate;

    core_1 : entity work.core(structural)
             port map(bus_addr_read => bus_addr_read,
                      bus_addr_write => bus_addr_write,
                      bus_data_read => bus_data_read,
                      bus_data_write => bus_data_write,
                      bus_stbr => bus_stbr,
                      bus_stbw => bus_stbw,
                      bus_ackr => bus_ackr,
                      bus_ackw => bus_ackw,

                      clk => clk_cpu,
                      
                      reset => reset_cpu);

    -- Just a 1 clk delay to give ram time to perform a read
    process(clk_cpu)
    begin
        if (rising_edge(clk_cpu)) then
            if (reset_cpu = '1') then
                ram_read_valid_1 <= '0';
                ram_read_valid_2 <= '0';
                ackr_uart <= '0';
                ackw_uart <= '0';
            else
                ram_read_valid_1 <= re_ram;
                ackr_uart <= re_uart and not ackr_uart;
                ackw_uart <= we_uart and not ackw_uart;
            end if;
        end if;
    end process;
                          

  
  rom_memory : entity work.rom_memory(rtl) 
               port map(data => bus_data_read_rom,
                        addr => bus_addr_read(13 downto 2),
                        en => re_rom,
                        ack => ackr_rom,
                        reset => reset_cpu,
                        clk => clk_cpu);
    
    ram_memory : entity work.ram_memory(rtl)
                 generic map(SIZE_BYTES => 32768)
                 port map(bus_raddr => bus_addr_read(14 downto 0),
                          bus_waddr => bus_addr_write(14 downto 0),
                          bus_wdata => bus_data_write,
                          bus_rdata => bus_data_read_ram,
                          bus_rstrb => re_ram,
                          bus_wstrb => stbw_ram,
                          bus_ackr => ackr_ram,
                          bus_ackw => ackw_ram,

                          clk => clk_cpu,
                          resetn => not reset_cpu);
    
    uart_controller : entity work.uart_simple(rtl)
                      port map(bus_data_read => bus_data_read_uart,
                               bus_data_write => bus_data_write,
                              
                               bus_addr_read => bus_addr_read(3 downto 0),
                               bus_addr_write => bus_addr_write(3 downto 0),
                               
                               rx => uart_rx,
                               tx => uart_tx,
                               
                               clk => clk_cpu,
                               reset => reset_cpu,
                               wr_en => we_uart,
                               rd_en => re_uart);

    gpio_controller : entity work.gpio_controller(rtl)
                      port map(bus_raddr => bus_addr_read(3 downto 0),
                               bus_waddr => bus_addr_write(3 downto 0),
                               bus_wdata => bus_data_write,
                               bus_rdata => bus_data_read_gpio,
                               bus_rstrb => re_gpio,
                               bus_wstrb => stbw_gpio,
                               bus_ackr => ackr_gpio,
                               bus_ackw => ackw_gpio,
                               
                               gpio_i => gpio_i,
                               gpio_o => gpio_o,

                               clk => clk_cpu,
                               reset => reset_cpu);

    bus_data_read <= bus_data_read_ram when re_ram = '1' else
                     bus_data_read_uart when re_uart = '1' else
                     bus_data_read_rom when re_rom = '1' else
                     bus_data_read_gpio when re_gpio = '1' else
                     bus_data_read_perfc when re_perfc = '1' else 
                     (others => '0');

    re_rom <= '1' when bus_addr_read(31 downto 28) = X"0" and bus_stbr = '1' else '0';
    re_uart <= '1' when bus_addr_read(31 downto 12) = X"FFFF0" and bus_stbr = '1' else '0';
    --re_uart <= '1' when bus_addr_read(31 downto 28) = X"1" and bus_stbr = '1' else '0';
    re_ram <= '1' when bus_addr_read(31 downto 28) = X"2" and bus_stbr = '1' else '0';
    re_gpio <= '1' when bus_addr_read(31 downto 28) = X"3" and bus_stbr = '1' else '0';
    re_perfc <= '1' when bus_addr_read(31 downto 28) = X"4" and bus_stbr = '1' else '0';
    we_uart <= '1' when bus_addr_write(31 downto 12) = X"FFFF0" and bus_stbw /= X"0" else '0';
    --we_uart <= '1' when bus_addr_write(31 downto 28) = X"1" and bus_stbw /= X"0" else '0';
    stbw_ram <= bus_stbw when bus_addr_write(31 downto 28) = X"2" and bus_stbw /= X"0" else X"0";
    stbw_gpio <= bus_stbw when bus_addr_write(31 downto 28) = X"3" and bus_stbw /= X"0" else X"0";

    cs_uart <= we_uart or re_uart;

    bus_ackr <= ackr_ram or ackr_uart or ackr_rom or ackr_gpio; --or ackr_perfc;
    bus_ackw <= ackw_ram or ackw_uart or ackw_gpio;

    resetn <= not reset_cpu;          


end structural;
