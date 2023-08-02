library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity audio_interface is
    port(
        pdm_input : in std_logic;
    
        bus_addr : in std_logic_vector(31 downto 0);
        bus_wdata : in std_logic_vector(31 downto 0);
        bus_rdata : out std_logic_vector(31 downto 0);
        bus_stbw : in std_logic_vector(3 downto 0);
        bus_ack : out std_logic;
        bus_cyc : in std_logic;
        
        clk_bus : in std_logic;
        clk_pdm : in std_logic;
        reset : in std_logic
    );
end audio_interface;

architecture rtl of audio_interface is
    signal pcm_sample, pcm_sample_2, pcm_sample_3, pcm_sample_4, pcm_sample_5 : std_logic_vector(15 downto 0);
    
    signal sample_rate_divider_counter_reg : unsigned(7 downto 0);
    signal sample_rate_divisor : unsigned(7 downto 0) := X"7F";
   
    signal cic_dec_valid, fir_1_valid, fifo_wr_en, i_bus_ready, fifo_empty : std_logic;
    
    COMPONENT fifo_generator_0
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC
  );
END COMPONENT;

begin
    cic_decimator : entity work.cic_decimator
                          generic map(BITS_PER_SAMPLE => 16,
                                      DELAY => 1,
                                      ORDER => 4,
                                      DECIMATION_FACTOR => 8)
                          port map(signal_in(0) => pdm_input,
                                   signal_in(15 downto 1) => (others => '0'),
                                   --signal_in(15 downto 9) => (others => '0'),
                                   std_logic_vector(signal_out) => pcm_sample,
                                   signal_out_valid => cic_dec_valid,
                                   
                                   clk => clk_pdm,
                                   reset => reset);
    
    fir_filter_inst : entity work.fir_filter
                      generic map(BITS_PER_SAMPLE => 16,
                                  BITS_FRACTION => 12,
                                  ORDER => 61,
                                  COEFFS => (
X"FFEB",
X"FF79",
X"0053",
X"0487",
X"0784",
X"0487",
X"0053",
X"FF79",
X"FFEB",
others => (others => '0')))
                      port map(signal_in(12 DOWNTO 0) => signed(pcm_sample(12 downto 0)),
                              signal_in(15 downto 13) => (others => '0'),
                               signal_in_valid => cic_dec_valid,
                               std_logic_vector(signal_out) => pcm_sample_2,
                               
                               clk => clk_pdm,
                               reset => reset);
                               
    decimator_inst : entity work.decimator
                     generic map(BITS_PER_SAMPLE => 16,
                                 DECIMATION_FACTOR => 2)
                     port map(signal_in => pcm_sample_2,
                              signal_in_valid => cic_dec_valid,
                              signal_out => pcm_sample_3,
                              signal_out_valid => fir_1_valid,
                              
                              clk => clk_pdm,
                              reset => reset);
     
    fir_filter_inst_2 : entity work.fir_filter
                      generic map(BITS_PER_SAMPLE => 16,
                                  BITS_FRACTION => 12,
                                  ORDER => 61,
                                  COEFFS => (
X"0009",
X"0011",
X"001F",
X"0032",
X"0047",
X"005B",
X"006A",
X"006F",
X"0062",
X"003E",
X"FFFF",
X"FFA0",
X"FF26",
X"FE97",
X"FDFF",
X"FD70",
X"FCFE",
X"FCC1",
X"FCD2",
X"FD43",
X"FE24",
X"FF7B",
X"0141",
X"0368",
X"05D4",
X"0861",
X"0AE3",
X"0D2C",
X"0F11",
X"106C",
X"1120",
X"1120",
X"106C",
X"0F11",
X"0D2C",
X"0AE3",
X"0861",
X"05D4",
X"0368",
X"0141",
X"FF7B",
X"FE24",
X"FD43",
X"FCD2",
X"FCC1",
X"FCFE",
X"FD70",
X"FDFF",
X"FE97",
X"FF26",
X"FFA0",
X"FFFF",
X"003E",
X"0062",
X"006F",
X"006A",
X"005B",
X"0047",
X"0032",
X"001F",
X"0011",
X"0009",
others => (others => '0')))
                      port map(signal_in(12 DOWNTO 0) => signed(pcm_sample_3(12 downto 0)),
                              signal_in(15 downto 13) => (others => '0'),
                               signal_in_valid => fir_1_valid,
                               std_logic_vector(signal_out) => pcm_sample_4,
                               
                               clk => clk_pdm,
                               reset => reset);
                               
    decimator_inst_2 : entity work.decimator
                     generic map(BITS_PER_SAMPLE => 16,
                                 DECIMATION_FACTOR => 4)
                     port map(signal_in => pcm_sample_4,
                              signal_in_valid => fir_1_valid,
                              signal_out => pcm_sample_5,
                              signal_out_valid => fifo_wr_en,
                              
                              clk => clk_pdm,
                              reset => reset);

    your_instance_name : fifo_generator_0
      PORT MAP (
        rst => reset,
        wr_clk => clk_pdm,
        rd_clk => clk_bus,
        din(15 downto 0) => pcm_sample_5,
        wr_en => fifo_wr_en,
        rd_en => bus_ack,
        dout => bus_rdata(15 downto 0),
        --full => full,
        empty => fifo_empty
      );
      
    bus_rdata(16) <= fifo_empty;
    bus_rdata(31 downto 17) <= (others => '0'); 
      
    bus_cntrl : process(clk_bus)
    begin
        if (rising_edge(clk_bus)) then
            if (reset = '1') then
                i_bus_ready <= '0';
            else
                i_bus_ready <= bus_cyc and not i_bus_ready;
            end if;
        end if;
    end process;
    
    bus_ack <= i_bus_ready;

end rtl;
