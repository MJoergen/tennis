library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

entity tb_ball is
end entity tb_ball;

architecture simulation of tb_ball is

  signal   running : std_logic                  := '1';
  signal   clk     : std_logic                  := '1';
  signal   rst     : std_logic                  := '1';
  signal   ce      : std_logic                  := '0';

  constant C_POS_BITS : natural                 := 14;
  constant C_VEL_BITS : natural                 := 9;
  constant C_ACCURACY : natural                 := 8;
  constant C_GRAVITY  : sfixed(C_VEL_BITS - 1 downto -C_ACCURACY) := to_sfixed(0.5, C_VEL_BITS-1, -C_ACCURACY);
  constant C_SCREEN_X : natural range 0 to 4095 := 2048;
  constant C_SCREEN_Y : natural range 0 to 4095 := 1024;

  signal   player_x   : ufixed(C_POS_BITS - 1 downto - C_ACCURACY);
  signal   player_y   : ufixed(C_POS_BITS - 1 downto - C_ACCURACY);
  signal   computer_x : ufixed(C_POS_BITS - 1 downto - C_ACCURACY);
  signal   computer_y : ufixed(C_POS_BITS - 1 downto - C_ACCURACY);
  signal   ball_pos_x : ufixed(C_POS_BITS - 1 downto - C_ACCURACY);
  signal   ball_pos_y : ufixed(C_POS_BITS - 1 downto - C_ACCURACY);
  signal   ball_vel_x : sfixed(C_VEL_BITS - 1 downto - C_ACCURACY);
  signal   ball_vel_y : sfixed(C_VEL_BITS - 1 downto - C_ACCURACY);
  signal   ball_valid : std_logic;

begin

  clk <= running and not clk after 5 ns; -- 100 MHz
  rst <= '1', '0' after 100 ns;

  ball_inst : entity work.ball
    generic map (
      G_RADIUS   => 32,
      G_POS_BITS => C_POS_BITS,
      G_VEL_BITS => C_VEL_BITS,
      G_ACCURACY => C_ACCURACY,
      G_GRAVITY  => C_GRAVITY,
      G_SCREEN_X => C_SCREEN_X,
      G_SCREEN_Y => C_SCREEN_Y
    )
    port map (
      clk_i        => clk,
      rst_i        => rst,
      ce_i         => ce,
      player_x_i   => player_x,
      player_y_i   => player_y,
      computer_x_i => computer_x,
      computer_y_i => computer_y,
      ball_pos_x_o => ball_pos_x,
      ball_pos_y_o => ball_pos_y,
      ball_vel_x_o => ball_vel_x,
      ball_vel_y_o => ball_vel_y,
      ball_valid_o => ball_valid
    ); -- ball_inst : entity work.ball


  test_proc : process
    --

    procedure verify (
      pos_x : real;
      pos_y : real;
      vel_x : real;
      vel_y : real
    ) is
    begin
      ce <= '1';
      wait until rising_edge(clk);
      ce <= '0';
      wait until rising_edge(clk);

      wait until ball_valid = '1';
      wait until rising_edge(clk);

      report "Verifying";
      assert resize(ball_pos_x, C_POS_BITS - 1, -2) = to_ufixed(pos_x, C_POS_BITS - 1, - 2)
        report "ball_pos_x=" & to_string(to_real(ball_pos_x)) & ", pos_x=" & to_string(pos_x)
          severity warning;
      assert resize(ball_pos_y, C_POS_BITS - 1, -2) = to_ufixed(pos_y, C_POS_BITS - 1, - 2)
        report "ball_pos_y=" & to_string(to_real(ball_pos_y)) & ", pos_y=" & to_string(pos_y)
          severity warning;
      assert resize(ball_vel_x, C_POS_BITS - 1, -2) = to_sfixed(vel_x, C_VEL_BITS - 1, - 2)
        report "ball_vel_x=" & to_string(to_real(ball_vel_x)) & ", vel_x=" & to_string(vel_x)
          severity warning;
      assert resize(ball_vel_y, C_POS_BITS - 1, -2) = to_sfixed(vel_y, C_VEL_BITS - 1, - 2)
        report "ball_vel_y=" & to_string(to_real(ball_vel_y)) & ", vel_y=" & to_string(vel_y)
          severity warning;
    end procedure verify;

  begin
    ce         <= '0';

    wait until falling_edge(rst);
    wait for 100 ns;
    wait until rising_edge(clk);

    report "Test initial values";
    assert ball_pos_x = to_ufixed(512, C_POS_BITS - 1, - C_ACCURACY);
    assert ball_pos_y = to_ufixed(512, C_POS_BITS - 1, - C_ACCURACY);
    assert ball_vel_x = to_sfixed(  0, C_POS_BITS - 1, - C_ACCURACY);
    assert ball_vel_y = to_sfixed(  0, C_POS_BITS - 1, - C_ACCURACY);

    player_x   <= to_ufixed( 524, C_POS_BITS - 1, - C_ACCURACY);
    player_y   <= to_ufixed( 900, C_POS_BITS - 1, - C_ACCURACY);
    computer_x <= to_ufixed(1500, C_POS_BITS - 1, - C_ACCURACY);
    computer_y <= to_ufixed( 900, C_POS_BITS - 1, - C_ACCURACY);
    wait until rising_edge(clk);

    report "Test few values";
    verify(512.0, 512.0, 0.0, 0.5);
    verify(512.0, 512.5, 0.0, 1.0);
    verify(512.0, 513.5, 0.0, 1.5);
    verify(512.0, 515.0, 0.0, 2.0);

    report "Wait until ball bounces up";
    while ball_vel_y > 0 loop
      ce <= '1';
      wait until rising_edge(clk);
      ce <= '0';
      wait until rising_edge(clk);

      wait until ball_valid = '1';
      wait until rising_edge(clk);
    end loop;

    verify(496.6, 811.9, -7.7, -15.8);

    report "Wait until ball bounces right";
    while ball_vel_x < 0 loop
      ce <= '1';
      wait until rising_edge(clk);
      ce <= '0';
      wait until rising_edge(clk);

      wait until ball_valid = '1';
      wait until rising_edge(clk);
    end loop;

    verify(72.9, 734.4, 7.7, 13.7);

    report "Test finished";
    running    <= '0';
    wait;
  end process test_proc;

end architecture simulation;

