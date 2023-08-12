library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.CONFIG.ALL;

entity wb_interconnect_bus is
    generic(
        DECODER_ADDR_WIDTH : integer := 8;
        NUM_SLAVES : integer := 2;
        NUM_MASTERS : integer := 2;
        BASE_ADDRS : MEMMAP_type := (X"F0", X"F1");
        SEGMENT_SIZES : SEGSIZE_type := (16, 16);          -- In 16-byte multiples
        MASTER_PRIOS : MASPRIO_type := (1, 2)
    );
    port(
        clk : in std_logic;
        reset : in std_logic;
    
        wb_master_rdata : out std_logic_vector(31 downto 0);
        wb_master_wdata : in std_logic_vector(NUM_MASTERS * 32 - 1 downto 0);
        wb_master_addr : in std_logic_vector(NUM_MASTERS * 32 - 1 downto 0);
        wb_master_wstrb : in std_logic_vector(NUM_MASTERS * 4 - 1 downto 0);
        wb_master_wren : in std_logic;
        wb_master_cyc : in std_logic_vector(NUM_MASTERS - 1 downto 0);
        wb_master_ack : out std_logic_vector(NUM_MASTERS - 1 downto 0);
        
        wb_slave_rdata : in std_logic_vector(NUM_SLAVES * 32 - 1 downto 0);
        wb_slave_wdata : out std_logic_vector(31 downto 0);
        wb_slave_addr : out std_logic_vector(31 downto 0);
        wb_slave_wstrb : out std_logic_vector(3 downto 0);
        wb_slave_wren : out std_logic;
        wb_slave_cyc : out std_logic_vector(NUM_SLAVES - 1 downto 0);
        wb_slave_ack : in std_logic_vector(NUM_SLAVES - 1 downto 0)
    );
end wb_interconnect_bus;

architecture rtl of wb_interconnect_bus is
    signal i_bus_rdata : std_logic_vector(31 downto 0);
    signal i_bus_wdata : std_logic_vector(31 downto 0);
    signal i_bus_addr : std_logic_vector(31 downto 0);
    signal i_bus_wstrb : std_logic_vector(3 downto 0);
    signal i_bus_cyc : std_logic;
    signal i_bus_ack : std_logic;
    
    COMPONENT ila_0
        PORT (
            clk : IN STD_LOGIC;
        
            probe0 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
            probe1 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
            probe2 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
            probe3 : IN STD_LOGIC_VECTOR(3 DOWNTO 0); 
            probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
            probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
            probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
        );
    END COMPONENT;
    
    type arbiter_sm_type is (IDLE, LOCKED);
    signal arbiter_state_reg : arbiter_sm_type;
    signal arbiter_state_next : arbiter_sm_type;
    
    signal selected_master_next : integer;
    signal selected_master_reg : integer;
    signal select_master_en : std_logic;
    signal bus_cycle_valid : std_logic;
begin
    bus_ila_gen : if (ENABLE_BUS_ILA_XILINX = true) generate
        your_instance_name : ila_0
        PORT MAP (
            clk => clk,
        
            probe0 => i_bus_addr, 
            probe1 => i_bus_wdata, 
            probe2 => i_bus_rdata, 
            probe3 => i_bus_wstrb, 
            probe4(0) => i_bus_cyc, 
            probe5(0) => i_bus_ack,
            probe6(0) => wb_master_wren
        );
    end generate;

    arbiter_gen : if (NUM_MASTERS > 1) generate
        process(clk)
        begin
            if (rising_edge(clk)) then
                if (reset = '1') then
                    arbiter_state_reg <= IDLE;
                else
                    arbiter_state_reg <= arbiter_state_next;
                end if;
            end if;
        end process;
        
        process(all)    
            variable is_any_master_active : std_logic;
        begin
            is_any_master_active := '0';
            
            for i in 0 to NUM_MASTERS - 1 loop
                selected_master_next <= 0;
                if (wb_master_cyc(i) = '1') then
                    is_any_master_active := '1';
                    selected_master_next <= i;
                end if;
            end loop;
        
            case arbiter_state_reg is
                when IDLE => 
                    arbiter_state_next <= IDLE;
                    if (is_any_master_active = '1') then
                        arbiter_state_next <= LOCKED;
                    end if;
                when LOCKED => 
                    arbiter_state_next <= LOCKED;
                    if (i_bus_ack = '1' or i_bus_cyc = '0') then
                        arbiter_state_next <= IDLE;
                    end if;
                when others => 
                    arbiter_state_next <= IDLE;
            end case;
            
            select_master_en <= '0';
            bus_cycle_valid <= '0';
            case arbiter_state_reg is
                when IDLE => 
                    if (is_any_master_active = '1') then
                        select_master_en <= '1';
                    end if;
                when LOCKED => 
                    bus_cycle_valid <= '1';
                when others => 
                    
            end case;
        end process;
        
        process(clk)    
        begin
            if (rising_edge(clk)) then
                if (reset = '1') then
                    selected_master_reg <= 0;
                else
                    if (select_master_en = '1') then
                        selected_master_reg <= selected_master_next;
                    end if;
                end if;
            end if;
        end process;
    else generate
        selected_master_reg <= 0;
        bus_cycle_valid <= '1';
    end generate;
    

    master_select_proc : process(all)
    begin
        wb_master_rdata <= i_bus_rdata;
        wb_slave_wren <= wb_master_wren;
    
        i_bus_wdata <= (others => '0');
        i_bus_addr <= (others => '0');
        i_bus_wstrb <= (others => '0');
        i_bus_cyc <= '0';
        for i in NUM_MASTERS - 1 downto 0 loop
            wb_master_ack(i) <= '0';
        
            if (bus_cycle_valid = '1') then
                i_bus_wdata <= wb_master_wdata(32 * (selected_master_reg + 1) - 1 downto 32 * selected_master_reg);
                i_bus_addr <= wb_master_addr(32 * (selected_master_reg + 1) - 1 downto 32 * selected_master_reg);
                i_bus_wstrb <= wb_master_wstrb(4 * (selected_master_reg + 1) - 1 downto 4 * selected_master_reg);
                i_bus_cyc <= wb_master_cyc(selected_master_reg);
                wb_master_ack(selected_master_reg) <= i_bus_ack;
            end if;
        end loop;
    end process;

    slave_select_proc : process(all)
    begin
        i_bus_rdata <= (others => '0');
        wb_slave_cyc <= (others => '0');
        i_bus_ack <= '0';
        
        for i in 0 to NUM_SLAVES - 1 loop
            if (std_match(i_bus_addr(31 downto 32 - DECODER_ADDR_WIDTH), BASE_ADDRS(i))) then
                i_bus_rdata <= wb_slave_rdata(32 * (i + 1) - 1 downto 32 * i);
                wb_slave_cyc(i) <= i_bus_cyc;
                i_bus_ack <= wb_slave_ack(i);
            end if;
        end loop;
    end process;
    
    wb_slave_wdata <= i_bus_wdata;
    wb_slave_addr <= i_bus_addr;
    wb_slave_wstrb <= i_bus_wstrb;

end rtl;
