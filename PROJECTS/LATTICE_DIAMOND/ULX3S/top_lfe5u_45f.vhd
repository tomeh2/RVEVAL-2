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
	signal clk, clk_locked : std_logic;
begin
	clk_gen : entity work.pll_1(Structure)
			  port map(CLKI => clk_25mhz,
						CLKOP => clk,			-- 50 MHz
						CLKOS => open,			-- 60 MHz
						CLKOS2 => open,			-- 75 MHz
						LOCK => clk_locked);

    soc_inst : entity work.soc(rtl)
               port map(clk => clk,
                        reset => not btn(0) and clk_locked,
                        
                        gpio_i => (others => '0'),
                        gpio_o(7 downto 0) => led(7 downto 0),
                        gpio_o(31 downto 8) => open,
                        
                        uart_tx => ftdi_rxd,
                        uart_rx => ftdi_txd );

end rtl;
