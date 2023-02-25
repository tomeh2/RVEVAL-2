library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top_nexys_a7 is
    port(
        CLK100MHZ : in std_logic;
        CPU_RESETN : in std_logic;
        
        LED : out std_logic_vector(15 downto 0);
        
        UART_TXD_IN : in std_logic;
        UART_RXD_OUT : out std_logic
    );
end top_nexys_a7;

architecture rtl of top_nexys_a7 is

begin
    soc_inst : entity work.soc(rtl)
               port map(clk => CLK100MHZ,
                        reset => not CPU_RESETN,
                        
                        gpio_i => (others => '0'),
                        gpio_o(7 downto 0) => LED(7 downto 0),
                        gpio_o(31 downto 8) => open,
                        
                        uart_tx => UART_RXD_OUT,
                        uart_rx => UART_TXD_IN);

    LED(15 downto 8) <= (others => '0');

end rtl;
