library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top_lfe5u_45f is
    port(
		led : out std_logic_vector(7 downto 0);
		
		ftdi_rxd : out std_logic;
		ftdi_txd : in std_logic;
		
		clk_25mhz : in std_logic;
		btn : in std_logic_vector(6 downto 0)
    );
end top_lfe5u_45f;

architecture rtl of top_lfe5u_45f is

begin
    soc_inst : entity work.soc(rtl)
               port map(clk => clk_25mhz,
                        reset => not btn(0),
                        
                        gpio_i => (others => '0'),
                        gpio_o(7 downto 0) => led(7 downto 0),
                        gpio_o(31 downto 8) => open,
                        
                        uart_tx => ftdi_rxd,
                        uart_rx => ftdi_txd );

end rtl;
