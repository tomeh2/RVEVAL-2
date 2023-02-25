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
    component clk_wiz_0
        port
         (-- Clock in ports
          -- Clock out ports
          clk_out1          : out    std_logic;
          -- Status and control signals
          locked            : out    std_logic;
          clk_in1           : in     std_logic
         );
    end component;
    
    signal clk, clk_locked : std_logic;
begin
    clk_wiz : clk_wiz_0
       port map ( 
      -- Clock out ports  
       clk_out1 => clk,
      -- Status and control signals                
       locked => clk_locked,
       -- Clock in ports
       clk_in1 => CLK100MHZ
       );

    soc_inst : entity work.soc(rtl)
               port map(clk => clk,
                        reset => not CPU_RESETN and clk_locked,
                        
                        gpio_i => (others => '0'),
                        gpio_o(7 downto 0) => LED(7 downto 0),
                        gpio_o(31 downto 8) => open,
                        
                        uart_tx => UART_RXD_OUT,
                        uart_rx => UART_TXD_IN);

    LED(15 downto 8) <= (others => '0');

end rtl;
