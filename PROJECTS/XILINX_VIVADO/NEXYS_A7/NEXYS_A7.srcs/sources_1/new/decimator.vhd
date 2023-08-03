library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity decimator is
    generic(
        BITS_PER_SAMPLE : integer;
        DECIMATION_FACTOR : integer
    );
    port(
        signal_in : in std_logic_vector(BITS_PER_SAMPLE - 1 downto 0);
        signal_in_valid : in std_logic;
        signal_out : out std_logic_vector(BITS_PER_SAMPLE - 1 downto 0);
        signal_out_valid : out std_logic;
        
        clk : in std_logic;
        reset : in std_logic
        );
end decimator;

architecture rtl of decimator is
    signal decimation_counter_reg : unsigned(7 downto 0);
    signal decimation_sample_valid : std_logic;
begin
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                decimation_counter_reg <= to_unsigned(0, 8);
            elsif (signal_in_valid = '1' or decimation_sample_valid = '1') then
                if (decimation_counter_reg = DECIMATION_FACTOR - 1) then
                    decimation_counter_reg <= to_unsigned(0, 8);
                else
                    decimation_counter_reg <= decimation_counter_reg + 1;
                end if;
            end if;
        end if;
    end process;
    signal_out <= signal_in;
    decimation_sample_valid <= '1' when decimation_counter_reg = DECIMATION_FACTOR - 1 and signal_in_valid = '1' else '0';
    signal_out_valid <= decimation_sample_valid;

end rtl;
