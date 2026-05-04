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
      clk_i      => clk,
      rst_i      => rst,
      pos_x_i    => to_ufixed(C_TESTCASES(test_idx).pos_cur.x, C_POS_BITS - 1, - C_ACCURACY),
      pos_y_i    => to_ufixed(C_TESTCASES(test_idx).pos_cur.y, C_POS_BITS - 1, - C_ACCURACY),
      vel_x_i    => to_sfixed(C_TESTCASES(test_idx).vel_cur.x, C_VEL_BITS - 1, - C_ACCURACY),
      vel_y_i    => to_sfixed(C_TESTCASES(test_idx).vel_cur.y, C_VEL_BITS - 1, - C_ACCURACY),
      center_x_i => to_ufixed(C_TESTCASES(test_idx).center.x,  C_POS_BITS - 1, - C_ACCURACY),
      center_y_i => to_ufixed(C_TESTCASES(test_idx).center.y,  C_POS_BITS - 1, - C_ACCURACY),
      vel_x_o    => vel_x_new,
      vel_y_o    => vel_y_new
    ); -- collision_inst : entity work.collision

  test_proc : process
    variable   vel_x_exp : sfixed(C_VEL_BITS - 1 downto -C_ACCURACY);
    variable   vel_y_exp : sfixed(C_VEL_BITS - 1 downto -C_ACCURACY);
  begin
    test_idx <= 0;

    wait until falling_edge(rst);
    wait for 100 ns;
    wait until rising_edge(clk);

    report "Test started";

    for idx in C_TESTCASES'range loop
      report "Testing case " & to_string(idx);
      test_idx <= idx;
      wait until rising_edge(clk);
      wait until rising_edge(clk);

      vel_x_exp := to_sfixed(C_TESTCASES(test_idx).vel_new.x, C_VEL_BITS - 1, -C_ACCURACY);
      vel_y_exp := to_sfixed(C_TESTCASES(test_idx).vel_new.y, C_VEL_BITS - 1, -C_ACCURACY);

      if resize(vel_x_new, C_VEL_BITS-1, 0) /= resize(vel_x_exp, C_VEL_BITS-1, 0) or
         resize(vel_y_new, C_VEL_BITS-1, 0) /= resize(vel_y_exp, C_VEL_BITS-1, 0) then
        report "Expected velocity:   " & to_string(vel_x_exp) & " , " & to_string(vel_y_exp);
        report "Calculated velocity: " & to_string(vel_x_new) & " , " & to_string(vel_y_new);
      end if;
    end loop;

    report "Test finished";
    running <= '0';
    wait;
  end process test_proc;

end architecture simulation;

