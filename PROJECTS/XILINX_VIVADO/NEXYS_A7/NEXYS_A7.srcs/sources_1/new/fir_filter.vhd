library IEEE;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_1164.ALL;

entity fir_filter is
    generic(
        BITS_PER_SAMPLE : integer;
        ORDER : integer
    );
    port(
      input_signal : in signed(BITS_PER_SAMPLE - 1 downto 0);  
      output_signal : out signed(BITS_PER_SAMPLE - 1 downto 0);
      
      clk : in std_logic;
      reset : in std_logic  
    );
end fir_filter;

architecture rtl of fir_filter is
    type delay_regs_type is array (ORDER downto 0) of signed(BITS_PER_SAMPLE - 1 downto 0);
    signal delay_regs : delay_regs_type;
    
    type coeff_regs_type is array (ORDER downto 0) of signed(BITS_PER_SAMPLE - 1 downto 0);
    signal coeff_regs : coeff_regs_type;
    
    type intermediate_results_type is array (ORDER downto 0) of signed(BITS_PER_SAMPLE * 2 - 1 downto 0);
    signal intermediate_results : intermediate_results_type;
    
    type after_mult_temp_type is array (ORDER downto 0) of signed(BITS_PER_SAMPLE * 2 - 1 downto 0);
    signal after_mult_temp : after_mult_temp_type;
    
    type after_shift_temp_type is array (ORDER downto 0) of signed(BITS_PER_SAMPLE * 2 - 1 downto 0);
    signal after_shift_temp : after_shift_temp_type;
begin
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                coeff_regs(0) <= X"00FE";
                coeff_regs(1) <= X"0074";
                coeff_regs(2) <= X"0010";
                coeff_regs(3) <= X"00C3";
                coeff_regs(4) <= X"00A6";
            else
                delay_regs(0) <= input_signal;
                for i in 1 to ORDER loop
                    delay_regs(i) <= delay_regs(i - 1);
                end loop;
            end if;
        end if;
    end process;
    
    process(all)
    begin
        after_mult_temp(0) <= delay_regs(0) * coeff_regs(0);
        
        after_shift_temp(0)(BITS_PER_SAMPLE / 2 - 1 downto 0) <= after_mult_temp(0)(BITS_PER_SAMPLE - 1 downto BITS_PER_SAMPLE / 2);
        after_shift_temp(0)(BITS_PER_SAMPLE * 2 - 1 downto BITS_PER_SAMPLE * 3 / 2) <= (others => '0');
        after_shift_temp(0)(BITS_PER_SAMPLE * 3 / 2 - 1 downto BITS_PER_SAMPLE / 2) <= after_mult_temp(0)(BITS_PER_SAMPLE * 2 - 1 downto BITS_PER_SAMPLE);
        for i in 1 to ORDER loop
            after_mult_temp(i) <= delay_regs(i) * coeff_regs(i);
            
            after_shift_temp(i)(BITS_PER_SAMPLE / 2 - 1 downto 0) <= after_mult_temp(i)(BITS_PER_SAMPLE - 1 downto BITS_PER_SAMPLE / 2);
            after_shift_temp(i)(BITS_PER_SAMPLE * 2 - 1 downto BITS_PER_SAMPLE * 3 / 2) <= (others => '0');
            after_shift_temp(i)(BITS_PER_SAMPLE * 3 / 2 - 1 downto BITS_PER_SAMPLE / 2) <= after_mult_temp(i)(BITS_PER_SAMPLE * 2 - 1 downto BITS_PER_SAMPLE);
        end loop;
        
        intermediate_results(0) <= after_shift_temp(0);
        for i in 1 to ORDER loop
            intermediate_results(i) <= after_shift_temp(i) + intermediate_results(i - 1);
        end loop;
    end process;
    
    output_signal <= intermediate_results(ORDER - 1)(BITS_PER_SAMPLE - 1 downto 0);

end rtl;
