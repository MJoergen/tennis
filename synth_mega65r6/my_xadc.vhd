-- Use XADC Wizard
-- Make following changes:
-- DCLK Frequency -> 148.5 MHz


library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity my_xadc is
  port (
    clk_i        : in    std_logic;
    rst_i        : in    std_logic;
    wbus_cyc_i   : in    std_logic;
    wbus_stall_o : out   std_logic;
    wbus_stb_i   : in    std_logic;
    wbus_addr_i  : in    std_logic_vector(15 downto 0);
    wbus_we_i    : in    std_logic;
    wbus_wrdat_i : in    std_logic_vector(31 downto 0);
    wbus_ack_o   : out   std_logic;
    wbus_rddat_o : out   std_logic_vector(31 downto 0);
    vp_i         : in    std_logic;
    vn_i         : in    std_logic
  );
end entity my_xadc;

architecture synthesis of my_xadc is

  signal drp_addr : std_logic_vector(8 downto 0);
  signal drp_en   : std_logic;
  signal drp_di   : std_logic_vector(15 downto 0);
  signal drp_we   : std_logic;
  signal drp_do   : std_logic_vector(15 downto 0);
  signal drp_rdy  : std_logic;

begin

  wbus_rdp_inst : entity work.wbus_drp
    generic map (
      G_ADDR_SIZE => 7
      G_DATA_SIZE => 16
    )
    port map (
      clk_i        => clk_i,
      rst_i        => rst_i,
      wbus_cyc_i   => wbus_cyc_i,
      wbus_stall_o => wbus_stall_o,
      wbus_stb_i   => wbus_stb_i,
      wbus_addr_i  => wbus_addr_i(6 downto 0),
      wbus_we_i    => wbus_we_i,
      wbus_wrdat_i => wbus_wrdat_i(15 downto 0),
      wbus_ack_o   => wbus_ack_o,
      wbus_rddat_o => wbus_rddat_o(15 downto 0),
      drp_addr_o   => drp_addr,
      drp_en_o     => drp_en,
      drp_di_o     => drp_di,
      drp_we_o     => drp_we,
      drp_do_i     => drp_do,
      drp_rdy_i    => drp_rdy
    );

  wbus_rddat_o(31 downto 16) <= (others => '0');

  xadc_inst : component xadc
    generic map (
      INIT_40          => X"0000",
      INIT_41          => X"31A0",
      INIT_42          => X"0600",
      INIT_48          => X"0100",
      INIT_49          => X"0000",
      INIT_4A          => X"0000",
      INIT_4B          => X"0000",
      INIT_4C          => X"0000",
      INIT_4D          => X"0000",
      INIT_4E          => X"0000",
      INIT_4F          => X"0000",
      INIT_50          => X"B5ED",
      INIT_51          => X"57E4",
      INIT_52          => X"A147",
      INIT_53          => X"CA33",
      INIT_54          => X"A93A",
      INIT_55          => X"52C6",
      INIT_56          => X"9555",
      INIT_57          => X"AE4E",
      INIT_58          => X"5999",
      INIT_5C          => X"5111",
      SIM_DEVICE       => "7SERIES",
      SIM_MONITOR_FILE => "design.txt"
    )
    port map (
      dclk         => clk_i,
      reset        => rst_i,
      convst       => '0',
      convstclk    => '0',
      daddr        => drp_addr,
      den          => drp_en,
      di           => drp_di,
      dwe          => drp_we,
      vauxn        => open,
      vauxp        => open,
      alm          => open,
      busy         => open,
      channel      => open,
      do           => drp_do,
      drdy         => drp_rdy,
      eoc          => open,
      eos          => open,
      jtagbusy     => open,
      jtaglocked   => open,
      jtagmodified => open,
      ot           => open,
      muxaddr      => open,
      vp           => vp_i,
      vn           => vn_i
    ); -- xadc_inst

end architecture synthesis;

