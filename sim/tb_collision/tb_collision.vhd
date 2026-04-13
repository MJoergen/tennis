library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_collision is
end entity tb_collision;

architecture simulation of tb_collision is

  constant C_MAX_POS : natural                := 100;
  constant C_MAX_VEL : natural                := 10;
  constant C_RADIUS  : natural                := 8;

  signal   running : std_logic                := '1';
  signal   clk     : std_logic                := '1';
  signal   rst     : std_logic                := '1';

  -- Test cases
  type     testcase_type is record
    pos_x     : natural range 0 to C_MAX_POS;
    pos_y     : natural range 0 to C_MAX_POS;
    vel_x_old : integer range -C_MAX_VEL to C_MAX_VEL;
    vel_y_old : integer range -C_MAX_VEL to C_MAX_VEL;
    center_x  : natural range 0 to C_MAX_POS;
    center_y  : natural range 0 to C_MAX_POS;
    vel_x_new : integer range -C_MAX_VEL to C_MAX_VEL;
    vel_y_new : integer range -C_MAX_VEL to C_MAX_VEL;
  end record testcase_type;

  type     testcase_vector_type is array (natural range <>) of testcase_type;

  constant C_TESTCASES : testcase_vector_type := (
                                                   0 => (10, 10,  0, 5,  10, 19,  0, 5),
                                                   1 => (10, 10,  0, 5,  10, 17,  0, -5)
                                                 );

  signal   test_idx : natural range C_TESTCASES'range;

  signal   vel_x_new : integer range -C_MAX_VEL to C_MAX_VEL;
  signal   vel_y_new : integer range -C_MAX_VEL to C_MAX_VEL;

begin

  clk <= running and not clk after 20 ns; -- 25 MHz
  rst <= '1', '0' after 100 ns;

  -- Instantiate DUT
  collision_inst : entity work.collision
    generic map (
      G_MAX_POS => C_MAX_POS,
      G_MAX_VEL => C_MAX_VEL,
      G_RADIUS  => C_RADIUS
    )
    port map (
      clk_i      => clk,
      rst_i      => rst,
      pos_x_i    => C_TESTCASES(test_idx).pos_x,
      pos_y_i    => C_TESTCASES(test_idx).pos_y,
      vel_x_i    => C_TESTCASES(test_idx).vel_x_old,
      vel_y_i    => C_TESTCASES(test_idx).vel_y_old,
      center_x_i => C_TESTCASES(test_idx).center_x,
      center_y_i => C_TESTCASES(test_idx).center_y,
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

      assert vel_x_new = C_TESTCASES(test_idx).vel_x_new;
      assert vel_y_new = C_TESTCASES(test_idx).vel_y_new;
    end loop;

    report "Test finished";
    running <= '0';
    wait;
  end process test_proc;

end architecture simulation;

