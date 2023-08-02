library IEEE;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_1164.ALL;

entity fir_filter is
    generic(
        BITS_PER_SAMPLE : integer;
        BITS_FRACTION : integer;
        ORDER : integer
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
    
    type coeff_regs_type is array (ORDER downto 0) of signed(BITS_PER_SAMPLE - 1 downto 0);
-- 2000 Hz Blackman LPF
--    signal coeff_regs : coeff_regs_type := (
--X"0000",
--X"0000",
--X"0000",
--X"0000",
--X"0000",
--X"0001",
--X"0001",
--X"0001",
--X"0001",
--X"0001",
--X"0000",
--X"FFFE",
--X"FFFA",
--X"FFF6",
--X"FFF0",
--X"FFEA",
--X"FFE5",
--X"FFE2",
--X"FFE2",
--X"FFE6",
--X"FFF0",
--X"0000",
--X"0019",
--X"0039",
--X"005F",
--X"008B",
--X"00BA",
--X"00E9",
--X"0115",
--X"013C",
--X"015A",
--X"016D",
--X"0173",
--X"016D",
--X"015A",
--X"013C",
--X"0115",
--X"00E9",
--X"00BA",
--X"008B",
--X"005F",
--X"0039",
--X"0019",
--X"0000",
--X"FFF0",
--X"FFE6",
--X"FFE2",
--X"FFE2",
--X"FFE5",
--X"FFEA",
--X"FFF0",
--X"FFF6",
--X"FFFA",
--X"FFFE",
--X"0000",
--X"0001",
--X"0001",
--X"0001",
--X"0001",
--X"0001",
--X"0000",
--X"0000",
--X"0000",
--X"0000",
--X"0000");

-- 700 HZ Blackman LPF
    signal coeff_regs : coeff_regs_type := (
X"0000",
X"0000",
X"0001",
X"0002",
X"0002",
X"0003",
X"0005",
X"0006",
X"0008",
X"000A",
X"000D",
X"000F",
X"0012",
X"0016",
X"0019",
X"001D",
X"0021",
X"0025",
X"0029",
X"002D",
X"0031",
X"0036",
X"0039",
X"003D",
X"0041",
X"0044",
X"0046",
X"0048",
X"004A",
X"004B",
X"004C",
X"004C",
X"004B",
X"004A",
X"0048",
X"0046",
X"0044",
X"0041",
X"003D",
X"0039",
X"0036",
X"0031",
X"002D",
X"0029",
X"0025",
X"0021",
X"001D",
X"0019",
X"0016",
X"0012",
X"000F",
X"000D",
X"000A",
X"0008",
X"0006",
X"0005",
X"0003",
X"0002",
X"0002",
X"0001",
X"0000",
X"0000");
    
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
            after_mult_temp(i) <= signal_in * coeff_regs(i);
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
