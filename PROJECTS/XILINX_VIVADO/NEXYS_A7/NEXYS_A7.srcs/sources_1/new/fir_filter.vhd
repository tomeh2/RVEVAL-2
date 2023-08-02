library IEEE;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_1164.ALL;

package pkg is
    type coeff_regs_type is array (0 to 1023) of signed(15 downto 0);
end package pkg;

library IEEE;
use work.pkg.all;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_1164.ALL;

entity fir_filter is
    generic(
        BITS_PER_SAMPLE : integer;
        BITS_FRACTION : integer;
        ORDER : integer;
        COEFFS : work.pkg.coeff_regs_type
    );
    
    port(
      signal_in : in signed(BITS_PER_SAMPLE - 1 downto 0);  
      signal_in_valid : in std_logic; 
      signal_out : out signed(BITS_PER_SAMPLE - 1 downto 0);
      
      clk : in std_logic;
      reset : in std_logic  
    );
end fir_filter;

architecture rtl of fir_filter is
    type delay_regs_type is array (ORDER - 1 downto 0) of signed(BITS_PER_SAMPLE - 1 downto 0);
    signal delay_regs : delay_regs_type;
    
    type intermediate_results_type is array (ORDER downto 0) of signed(BITS_PER_SAMPLE - 1 downto 0);
    signal intermediate_results : intermediate_results_type;
    
    type after_mult_temp_type is array (ORDER downto 0) of signed(BITS_PER_SAMPLE * 2 - 1 downto 0);
    signal after_mult_temp : after_mult_temp_type;
    
    type after_shift_temp_type is array (ORDER downto 0) of signed(BITS_PER_SAMPLE - 1 downto 0);
    signal after_shift_temp : after_shift_temp_type;
begin
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then

            elsif (signal_in_valid = '1') then
                delay_regs(ORDER - 1) <= after_shift_temp(ORDER);
                for i in 0 to ORDER - 1 loop
                    delay_regs(i) <= intermediate_results(i + 1);
                end loop;
            end if;
        end if;
    end process;
    
    process(all)
    begin
        for i in 0 to ORDER loop
            after_mult_temp(i) <= signal_in * COEFFS(i)(BITS_PER_SAMPLE - 1 downto 0);
            after_shift_temp(i) <= after_mult_temp(i)(BITS_FRACTION + BITS_PER_SAMPLE - 1 downto BITS_FRACTION);
            
            if (i < ORDER) then
                intermediate_results(i) <= after_shift_temp(i) + delay_regs(i);
            else
                intermediate_results(i) <= after_shift_temp(i);
            end if;
        end loop;
    end process;
    signal_out <= intermediate_results(0);
end rtl;
