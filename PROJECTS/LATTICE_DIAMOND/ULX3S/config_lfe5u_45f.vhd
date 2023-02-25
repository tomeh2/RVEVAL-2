library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package config is
    constant CLOCK_FREQ_MHZ : integer := 25;
    constant STACK_ADDR : std_logic_vector(31 downto 0) := X"8001_0000";
    constant RESET_PC : std_logic_vector(31 downto 0) := X"0000_0000";
    
    -- PICORV
    -- SERV
    constant CPU_NAME : string := "NEORV";
    constant ENABLE_BUS_ILA_XILINX : boolean := true;
    
    type wb_data_type is array (natural range <>) of std_logic_vector(31 downto 0);
    subtype wb_addr_type is std_logic_vector(31 downto 0);

    type MEMMAP_type is array (natural range <>) of std_logic_vector(23 downto 0); 
    type SEGSIZE_type is array (natural range <>) of integer; 
    type MASPRIO_type is array (natural range <>) of integer; 
end config;