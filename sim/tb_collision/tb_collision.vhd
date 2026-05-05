library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

entity tb_collision is
end entity tb_collision;

architecture simulation of tb_collision is

  constant C_ACCURACY : natural               := 4;
  constant C_POS_BITS : natural               := 8;
  constant C_VEL_BITS : natural               := 8;
  constant C_RADIUS   : natural               := 8;

  signal   running : std_logic                := '1';
  signal   clk     : std_logic                := '1';
  signal   rst     : std_logic                := '1';

  signal   s_ready    : std_logic;
  signal   s_valid    : std_logic;
  signal   s_pos_x    : ufixed(C_POS_BITS - 1 downto - C_ACCURACY);
  signal   s_pos_y    : ufixed(C_POS_BITS - 1 downto - C_ACCURACY);
  signal   s_vel_x    : sfixed(C_VEL_BITS - 1 downto - C_ACCURACY);
  signal   s_vel_y    : sfixed(C_VEL_BITS - 1 downto - C_ACCURACY);
  signal   s_center_x : ufixed(C_POS_BITS - 1 downto - C_ACCURACY);
  signal   s_center_y : ufixed(C_POS_BITS - 1 downto - C_ACCURACY);
  signal   m_ready    : std_logic;
  signal   m_valid    : std_logic;
  signal   m_vel_x    : sfixed(C_VEL_BITS - 1 downto - C_ACCURACY);
  signal   m_vel_y    : sfixed(C_VEL_BITS - 1 downto - C_ACCURACY);

  type     pos_type is record
    x : natural range 0 to 2 ** C_POS_BITS - 1;
    y : natural range 0 to 2 ** C_POS_BITS - 1;
  end record pos_type;

  type     vel_type is record
    x : integer range -2 ** C_VEL_BITS to 2 ** C_VEL_BITS - 1;
    y : integer range -2 ** C_VEL_BITS to 2 ** C_VEL_BITS - 1;
  end record vel_type;

  -- Test cases
  type     testcase_type is record
    pos_cur : pos_type;
    vel_cur : vel_type;
    center  : pos_type;
    vel_new : vel_type;
  end record testcase_type;

  type     testcase_vector_type is array (natural range <>) of testcase_type;

  constant C_TESTCASES : testcase_vector_type := (
                                                   -- Not yet collided
                                                   0 => ((10, 10), (0, 5), (10, 19), (0,  5)),
                                                   1 => ((10, 10), (0, 5), ( 9, 18), (0,  5)),
                                                   2 => ((10, 10), (0, 5), (11, 18), (0,  5)),
                                                   3 => ((10, 10), (0, 5), ( 6, 17), (0,  5)),
                                                   4 => ((10, 10), (0, 5), (14, 17), (0,  5)),

                                                   --
                                                   5 => ((10, 10), (0, 5), (10, 17), (0, -5)),
                                                   6 => ((10, 10), (0, 5), ( 7, 16), (4, -3))
                                                 );

  signal   test_idx : natural range C_TESTCASES'range;

  signal   vel_x_new : sfixed(C_VEL_BITS - 1 downto -C_ACCURACY);
  signal   vel_y_new : sfixed(C_VEL_BITS - 1 downto -C_ACCURACY);

begin

  clk <= running and not clk after 20 ns; -- 25 MHz
  rst <= '1', '0' after 100 ns;

  -- Instantiate DUT
  collision_inst : entity work.collision
    generic map (
      G_ACCURACY => C_ACCURACY,
      G_POS_BITS => C_POS_BITS,
      G_VEL_BITS => C_VEL_BITS,
      G_RADIUS   => to_sfixed(C_RADIUS, C_POS_BITS - 1, - C_ACCURACY)
    )
    port map (
      clk_i        => clk,
      rst_i        => rst,
      s_ready_o    => s_ready,
      s_valid_i    => s_valid,
      s_pos_x_i    => s_pos_x,
      s_pos_y_i    => s_pos_y,
      s_vel_x_i    => s_vel_x,
      s_vel_y_i    => s_vel_y,
      s_center_x_i => s_center_x,
      s_center_y_i => s_center_y,
      m_ready_i    => m_ready,
      m_valid_o    => m_valid,
      m_vel_x_o    => m_vel_x,
      m_vel_y_o    => m_vel_y
    ); -- collision_inst : entity work.collision

  test_proc : process
    variable vel_x_exp : sfixed(C_VEL_BITS - 1 downto -C_ACCURACY);
    variable vel_y_exp : sfixed(C_VEL_BITS - 1 downto -C_ACCURACY);
    variable vel_x_obs : sfixed(C_VEL_BITS - 1 downto -C_ACCURACY);
    variable vel_y_obs : sfixed(C_VEL_BITS - 1 downto -C_ACCURACY);
  begin
    test_idx <= 0;
    s_valid  <= '0';
    m_ready  <= '0';

    wait until falling_edge(rst);
    wait for 100 ns;
    wait until rising_edge(clk);

    report "Test started";

    for idx in C_TESTCASES'range loop
      report "Testing case " & to_string(idx);
      test_idx   <= idx;
      wait until rising_edge(clk);
      s_pos_x    <= to_ufixed(C_TESTCASES(test_idx).pos_cur.x, C_POS_BITS - 1, - C_ACCURACY);
      s_pos_y    <= to_ufixed(C_TESTCASES(test_idx).pos_cur.y, C_POS_BITS - 1, - C_ACCURACY);
      s_vel_x    <= to_sfixed(C_TESTCASES(test_idx).vel_cur.x, C_VEL_BITS - 1, - C_ACCURACY);
      s_vel_y    <= to_sfixed(C_TESTCASES(test_idx).vel_cur.y, C_VEL_BITS - 1, - C_ACCURACY);
      s_center_x <= to_ufixed(C_TESTCASES(test_idx).center.x,  C_POS_BITS - 1, - C_ACCURACY);
      s_center_y <= to_ufixed(C_TESTCASES(test_idx).center.y,  C_POS_BITS - 1, - C_ACCURACY);
      s_valid    <= '1';
      wait until rising_edge(clk);
      while s_ready = '0' loop
        wait until rising_edge(clk);
      end loop;
      s_valid <= '0';
      m_ready <= '1';
      wait until rising_edge(clk);
      while m_valid = '0' loop
        wait until rising_edge(clk);
      end loop;
      vel_x_obs := m_vel_x;
      vel_y_obs := m_vel_y;

      m_ready   <= '0';

      vel_x_exp := to_sfixed(C_TESTCASES(test_idx).vel_new.x, C_VEL_BITS - 1, -C_ACCURACY);
      vel_y_exp := to_sfixed(C_TESTCASES(test_idx).vel_new.y, C_VEL_BITS - 1, -C_ACCURACY);

      if resize(vel_x_obs, C_VEL_BITS - 1, 0) /= resize(vel_x_exp, C_VEL_BITS - 1, 0) or
         resize(vel_y_obs, C_VEL_BITS - 1, 0) /= resize(vel_y_exp, C_VEL_BITS - 1, 0) then
        report "Expected velocity:   " & to_string(vel_x_exp) & " , " & to_string(vel_y_exp);
        report "Calculated velocity: " & to_string(vel_x_obs) & " , " & to_string(vel_y_obs);
      end if;
    end loop;

    report "Test finished";
    running <= '0';
    wait;
  end process test_proc;

end architecture simulation;

