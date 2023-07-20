library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top_nexys_a7 is
    port(
        CLK100MHZ : in std_logic;
        CPU_RESETN : in std_logic;
        
        M_CLK : out std_logic;
        M_DATA : in std_logic;
        M_LRSEL : out std_logic;
        
        LED : out std_logic_vector(15 downto 0);
        
        CA : out std_logic;
        CB : out std_logic;
        CC : out std_logic;
        CD : out std_logic;
        CE : out std_logic;
        CF : out std_logic;
        CG : out std_logic;
        DP : out std_logic;
        AN : out std_logic_vector(7 downto 0);
        
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
          clk_out2          : out    std_logic;
          -- Status and control signals
          locked            : out    std_logic;
          clk_in1           : in     std_logic
         );
    end component;
    
    signal clk, clk_locked, clk_pdm, clk_pdm_div_2 : std_logic;
begin
    clk_wiz : clk_wiz_0
       port map ( 
      -- Clock out ports  
       clk_out1 => clk,
       clk_out2 => clk_pdm,
      -- Status and control signals                
       locked => clk_locked,
       -- Clock in ports
       clk_in1 => CLK100MHZ
       );
       
    process(clk_pdm)
    begin
        if (rising_edge(clk_pdm)) then
            if ((not CPU_RESETN and clk_locked) = '1') then
                clk_pdm_div_2 <= '0';
            else
                clk_pdm_div_2 <= not clk_pdm_div_2;
            end if;
        end if;   
    end process;
    
    M_CLK <= clk_pdm_div_2;
    M_LRSEL <= '0';

    soc_inst : entity work.soc(rtl)
               port map(clk => clk,
                        clk_pdm => clk_pdm,
                        reset => not CPU_RESETN and clk_locked,
                        
                        pdm_input => M_DATA,
                        
                        gpio_i => (others => '0'),
                        gpio_o(7 downto 0) => LED(7 downto 0),
                        gpio_o(31 downto 8) => open,
                        
                        anodes => AN,
                        cathodes(0) => CA,
                        cathodes(1) => CB,
                        cathodes(2) => CC,
                        cathodes(3) => CD,
                        cathodes(4) => CE,
                        cathodes(5) => CF,
                        cathodes(6) => CG,
                        cathodes(7) => DP,
                        
                        uart_tx => UART_RXD_OUT,
                        uart_rx => UART_TXD_IN);

    LED(15 downto 8) <= (others => '0');

end rtl;
