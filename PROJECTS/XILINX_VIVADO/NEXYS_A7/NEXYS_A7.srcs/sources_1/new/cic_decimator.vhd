library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cic_decimator is
    generic(
        BITS_PER_SAMPLE : integer;
        DELAY : integer;
        ORDER : integer;
        DECIMATION_FACTOR : integer
    );
    port(
        signal_in : in std_logic_vector(BITS_PER_SAMPLE - 1 downto 0);
        signal_in_en : in std_logic;
        signal_out : out std_logic_vector(BITS_PER_SAMPLE - 1 downto 0);
        signal_out_valid : out std_logic;
        
        clk : in std_logic;
        reset : in std_logic
    );
end cic_decimator;

architecture rtl of cic_decimator is
    signal decimation_counter_reg : unsigned(7 downto 0);
    signal decimation_sample_valid : std_logic;
    
    type integrator_regs_type is array (ORDER - 1 downto 0) of signed(BITS_PER_SAMPLE - 1 downto 0);
    signal integrator_regs : integrator_regs_type;
    
    type intermediate_results_type is array (ORDER * 2 downto 0) of signed(BITS_PER_SAMPLE - 1 downto 0);
    signal intermediate_results : intermediate_results_type;
    
    type comb_delay_regs_type is array (DELAY - 1 downto 0) of signed(BITS_PER_SAMPLE - 1 downto 0);
    type comb_regs_type is array (ORDER - 1 downto 0) of comb_delay_regs_type;
    signal comb_regs : comb_regs_type;
begin
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                decimation_counter_reg <= to_unsigned(0, 8);
            elsif (signal_in_en = '1') then
                if (decimation_counter_reg = DECIMATION_FACTOR - 1) then
                    decimation_counter_reg <= to_unsigned(0, 8);
                else
                    decimation_counter_reg <= decimation_counter_reg + 1;
                end if;
            end if;
        end if;
    end process;
    decimation_sample_valid <= '1' when decimation_counter_reg = DECIMATION_FACTOR - 1 and signal_in_en = '1' else '0';
    signal_out_valid <= decimation_sample_valid;
    
    -- INTEGRATORS
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                integrator_regs <= (others => to_signed(0, BITS_PER_SAMPLE));             
            elsif (signal_in_en = '1') then
                for i in 0 to ORDER - 1 loop
                    integrator_regs(i) <= intermediate_results(i + 1);
                end loop;
            end if;
        end if;
    end process;
    
    intermediate_results(0) <= signed(signal_in);
    gen_int : for i in 1 to ORDER generate
            intermediate_results(i) <= integrator_regs(i - 1) + intermediate_results(i - 1);
    end generate;

    -- COMBS
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                comb_regs <= (others => (others => to_signed(0, BITS_PER_SAMPLE)));
            elsif (signal_in_en = '1') then
                if (decimation_sample_valid = '1') then
                    for i in 0 to ORDER - 1 loop
                        comb_regs(i)(0) <= intermediate_results(i + ORDER);
                        
                        for j in 1 to DELAY - 1 loop
                            comb_regs(i)(j) <= comb_regs(i)(j - 1);
                        end loop;
                    end loop;
                end if;
            end if;
        end if;
    end process;
    
    gen_comb : for i in ORDER + 1 to 2 * ORDER generate
        intermediate_results(i) <= intermediate_results(i - 1) - comb_regs(i - ORDER - 1)(DELAY - 1);
    end generate;
    signal_out <= std_logic_vector(intermediate_results(2 * ORDER));
end rtl;










