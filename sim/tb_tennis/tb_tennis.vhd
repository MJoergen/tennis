library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.sprite_pkg.all;

entity tb_tennis is
end entity tb_tennis;

architecture simulation of tb_tennis is

  signal running : std_logic := '1';
  signal clk     : std_logic := '1';
  signal rst     : std_logic := '1';
  signal ce      : std_logic := '0';

  signal btn_left  : std_logic;
  signal btn_right : std_logic;
  signal sprites   : sprite_array_type;

begin

  clk <= running and not clk after 20 ns; -- 25 MHz
  rst <= '1', '0' after 100 ns;

  -- Instantiate DUT
  tennis_inst : entity work.tennis
    generic map (
      G_SCREEN_X => 100,
      G_SCREEN_Y => 100
    )
    port map (
      clk_i       => clk,
      rst_i       => rst,
      ce_i        => ce,
      btn_left_i  => btn_left,
      btn_right_i => btn_right,
      sprites_o   => sprites
    ); -- tennis_inst : entity work.tennis

  test_proc : process
  begin
    ce        <= '0';
    btn_left  <= '0';
    btn_right <= '0';

    wait until falling_edge(rst);
    wait for 100 ns;
    wait until rising_edge(clk);

    report "Test started";
    report "Test 0 : Test reset values";
    assert sprites(0).active  = '1';
    assert sprites(1).active  = '1';
    assert sprites(2).active  = '1';

    report "Test finished";
    running   <= '0';
    wait;
  end process test_proc;

end architecture simulation;

