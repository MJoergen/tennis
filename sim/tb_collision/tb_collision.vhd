library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

entity tb_collision is
end entity tb_collision;

architecture simulation of tb_collision is

  constant C_ACCURACY : natural                                   := 4;
  constant C_POS_BITS : natural                                   := 8;
  constant C_VEL_BITS : natural                                   := 8;
  constant C_RADIUS   : sfixed(C_POS_BITS - 1 downto -C_ACCURACY) := to_sfixed(8, C_POS_BITS - 1, -C_ACCURACY);

  signal   running : std_logic                                    := '1';
  signal   clk     : std_logic                                    := '1';
  signal   rst     : std_logic                                    := '1';

  -- Test cases
  type     testcase_type is record
    pos_x     : natural range 0 to 2 ** C_POS_BITS - 1;
    pos_y     : natural range 0 to 2 ** C_POS_BITS - 1;
    vel_x_old : integer range -2 ** C_VEL_BITS to 2 ** C_VEL_BITS - 1;
    vel_y_old : integer range -2 ** C_VEL_BITS to 2 ** C_VEL_BITS - 1;
    center_x  : natural range 0 to 2 ** C_POS_BITS - 1;
    center_y  : natural range 0 to 2 ** C_POS_BITS - 1;
    vel_x_new : integer range -2 ** C_VEL_BITS to 2 ** C_VEL_BITS - 1;
    vel_y_new : integer range -2 ** C_VEL_BITS to 2 ** C_VEL_BITS - 1;
  end record testcase_type;

  type     testcase_vector_type is array (natural range <>) of testcase_type;

  constant C_TESTCASES : testcase_vector_type                     := (
                                                   0 => (10, 10,  0, 5,  10, 19,  0, 5),
                                                   1 => (10, 10,  0, 5,  10, 17,  0, -5)
                                                 );

  signal   test_idx : natural range C_TESTCASES'range;

  signal   vel_x_new : sfixed(C_VEL_BITS-1 downto -C_ACCURACY);
  signal   vel_y_new : sfixed(C_VEL_BITS-1 downto -C_ACCURACY);

begin

  clk <= running and not clk after 20 ns; -- 25 MHz
  rst <= '1', '0' after 100 ns;

  -- Instantiate DUT
  collision_inst : entity work.collision
    generic map (
      G_ACCURACY => C_ACCURACY,
      G_POS_BITS => C_POS_BITS,
      G_VEL_BITS => C_VEL_BITS,
      G_RADIUS   => C_RADIUS
    )
    port map (
      clk_i      => clk,
      rst_i      => rst,
      pos_x_i    => to_ufixed(C_TESTCASES(test_idx).pos_x, C_POS_BITS - 1, - C_ACCURACY),
      pos_y_i    => to_ufixed(C_TESTCASES(test_idx).pos_y, C_POS_BITS - 1, - C_ACCURACY),
      vel_x_i    => to_sfixed(C_TESTCASES(test_idx).vel_x_old, C_VEL_BITS - 1, - C_ACCURACY),
      vel_y_i    => to_sfixed(C_TESTCASES(test_idx).vel_y_old, C_VEL_BITS - 1, - C_ACCURACY),
      center_x_i => to_ufixed(C_TESTCASES(test_idx).center_x, C_POS_BITS - 1, - C_ACCURACY),
      center_y_i => to_ufixed(C_TESTCASES(test_idx).center_y, C_POS_BITS - 1, - C_ACCURACY),
      vel_x_o    => vel_x_new,
      vel_y_o    => vel_y_new
    ); -- collision_inst : entity work.collision

  test_proc : process
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

      assert vel_x_new = to_sfixed(C_TESTCASES(test_idx).vel_x_new, C_VEL_BITS - 1, -C_ACCURACY);
      assert vel_y_new = to_sfixed(C_TESTCASES(test_idx).vel_y_new, C_VEL_BITS - 1, -C_ACCURACY);
    end loop;

    report "Test finished";
    running <= '0';
    wait;
  end process test_proc;

end architecture simulation;

