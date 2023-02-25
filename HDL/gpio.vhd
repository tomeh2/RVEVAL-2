library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity gpio is
    port (
        gpio_i : in std_logic_vector(31 downto 0);
        gpio_o : out std_logic_vector(31 downto 0);
    
        bus_wdata : in std_logic_vector(31 downto 0);
        bus_rdata : out std_logic_vector(31 downto 0);
        bus_stbw : in std_logic_vector(3 downto 0);
        bus_ack : out std_logic;
        bus_cyc : in std_logic;
        
        clk : in std_logic;
        reset : in std_logic
    );
end gpio;

architecture rtl of gpio is
    signal i_bus_ready : std_logic;
    
    signal i_gpio_o_reg : std_logic_vector(31 downto 0);
    signal i_gpio_i_reg : std_logic_vector(31 downto 0);
begin
    gpio_reg_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                i_gpio_i_reg <= (others => '0');
                i_gpio_o_reg <= (others => '0');
            else
                if (bus_stbw /= "0000") then
                    i_gpio_o_reg <= bus_wdata;
                end if;
                
                i_gpio_i_reg <= gpio_i;
            end if;
        end if;
    end process;
    
    gpio_o <= i_gpio_o_reg;
    bus_rdata <= i_gpio_i_reg;

    bus_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                i_bus_ready <= '0';
            else
                i_bus_ready <= bus_cyc and not i_bus_ready;
            end if;
        end if;
    end process;
    
    bus_ack <= i_bus_ready;
end rtl;