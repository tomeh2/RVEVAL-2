library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pulse_density_demodulator is
    port(
        pdm_input : in std_logic;

        pcm_sample : out std_logic_vector(5 downto 0);
        pcm_sample_ready : out std_logic;

        clk_pdm : in std_logic;
        reset : in std_logic 
    );
end pulse_density_demodulator;

architecture rtl of pulse_density_demodulator is
    constant PDM_PCM_COUNTER_MAX : unsigned(5 downto 0) := (others => '1');

    signal pdm_pcm_demod_counter : unsigned(5 downto 0);
    signal pdm_pcm_counter : unsigned(5 downto 0);
begin
    process(clk_pdm)
    begin
        if (rising_edge(clk_pdm)) then
            if (reset = '1') then
                pdm_pcm_demod_counter <= (others => '0');
                pdm_pcm_counter <= (others => '0');
            else
                if (pcm_sample_ready = '1') then
                    pdm_pcm_demod_counter <= (others => '0');
                elsif (pdm_input = '1') then
                    pdm_pcm_demod_counter <= pdm_pcm_demod_counter + 1;
                end if;
                pdm_pcm_counter <= pdm_pcm_counter + 1;
            end if;
        end if;
    end process;
    
    pcm_sample <= std_logic_vector(pdm_pcm_demod_counter);
    pcm_sample_ready <= '1' when pdm_pcm_counter = PDM_PCM_COUNTER_MAX else '0';

end rtl;
