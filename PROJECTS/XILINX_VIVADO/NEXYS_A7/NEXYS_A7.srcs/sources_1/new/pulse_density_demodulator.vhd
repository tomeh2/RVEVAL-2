library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity pulse_density_demodulator is
    port(
        pdm_input : in std_logic;
        
        bus_wdata : in std_logic_vector(31 downto 0);
        bus_rdata : out std_logic_vector(31 downto 0);
        bus_stbw : in std_logic_vector(3 downto 0);
        bus_ack : out std_logic;
        bus_cyc : in std_logic;
        
        clk_bus : in std_logic;
        clk_pdm : in std_logic;
        reset : in std_logic 
    );
end pulse_density_demodulator;

architecture rtl of pulse_density_demodulator is

begin


end rtl;
