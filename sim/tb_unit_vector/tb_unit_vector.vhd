library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;
  use ieee.math_real.all;

library work;
  use work.fmt.fmt;
  use work.fmt.f;

entity tb_unit_vector is
end entity tb_unit_vector;

architecture simulation of tb_unit_vector is

  constant C_LOOPS    : natural := 1000;
  constant C_ITERS    : natural := 24;
  constant C_ACCURACY : natural := 16;
  constant C_BITS     : natural := 8;

  signal   running : std_logic  := '1';
  signal   clk     : std_logic  := '1';
  signal   rst     : std_logic  := '1';

  signal   s_ready : std_logic;
  signal   s_valid : std_logic;
  signal   s_x     : sfixed(C_BITS - 1 downto - C_ACCURACY);
  signal   s_y     : sfixed(C_BITS - 1 downto - C_ACCURACY);
  signal   m_ready : std_logic;
  signal   m_valid : std_logic;
  signal   m_x     : sfixed(0 downto - C_ACCURACY - C_BITS);
  signal   m_y     : sfixed(0 downto - C_ACCURACY - C_BITS);

begin

  clk <= running and not clk after 5 ns; -- 100 MHz
  rst <= '1', '0' after 100 ns;

  -- Instantiate DUT
  unit_vector_inst : entity work.unit_vector
    generic map (
      G_ITERS    => C_ITERS,
      G_ACCURACY => C_ACCURACY,
      G_BITS     => C_BITS
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => s_ready,
      s_valid_i => s_valid,
      s_x_i     => s_x,
      s_y_i     => s_y,
      m_ready_i => m_ready,
      m_valid_o => m_valid,
      m_x_o     => m_x,
      m_y_o     => m_y
    ); -- unit_vector_inst : entity work.unit_vector

  verify_proc : process
    variable x_v      : real;
    variable y_v      : real;
    variable l_v      : real;
    variable ux_exp_v : real;
    variable uy_exp_v : real;
    variable ux_obs_v : real;
    variable uy_obs_v : real;
    variable dx_v     : real;
    variable dy_v     : real;
    variable d_v      : real;
    variable d_max_v  : real := -1.0;
  begin
    while s_valid /= '1' or s_ready /= '1' loop
      wait until rising_edge(clk);
    end loop;

    x_v      := to_real(s_x);
    y_v      := to_real(s_y);
    l_v      := sqrt(x_v * x_v + y_v * y_v);
    ux_exp_v := x_v / l_v;
    uy_exp_v := y_v / l_v;

    while m_valid /= '1' or m_ready /= '1' loop
      wait until rising_edge(clk);
    end loop;

    ux_obs_v := to_real(m_x);
    uy_obs_v := to_real(m_y);

    dx_v     := ux_obs_v - ux_exp_v;
    dy_v     := uy_obs_v - uy_exp_v;

    d_v      := sqrt(dx_v * dx_v + dy_v * dy_v);

    if d_v > d_max_v then
      report fmt("x={} y={} ux_obs={} uy_obs={} ux_exp={} uy_exp={} d={}",
             f(x_v,      ">8.5f"),
             f(y_v,      ">8.5f"),
             f(ux_obs_v, ">8.5f"),
             f(uy_obs_v, ">8.5f"),
             f(ux_exp_v, ">8.5f"),
             f(uy_exp_v, ">8.5f"),
             f(d_v,      ">8.5f"));

      d_max_v := d_v;
    end if;
  end process verify_proc;

  stim_proc : process
    variable seed1_v : positive;
    variable seed2_v : positive;
    variable rand_v  : real;
  begin
    s_valid <= '0';
    m_ready <= '0';
    wait until rst = '0';
    wait until rising_edge(clk);
    report "Test started";

    for i in 1 to C_LOOPS loop

      uniform(seed1_v, seed2_v, rand_v);
      s_x     <= to_sfixed(rand_v * 2.0 - 1.0, C_BITS - 1, - C_ACCURACY);
      uniform(seed1_v, seed2_v, rand_v);
      s_y     <= to_sfixed(rand_v * 2.0 - 1.0, C_BITS - 1, - C_ACCURACY);
      s_valid <= '1';
      wait until rising_edge(clk);
      while s_ready /= '1' loop
        wait until rising_edge(clk);
      end loop;
      s_valid <= '0';
      wait until rising_edge(clk);

      m_ready <= '1';
      while m_valid /= '1' loop
        wait until rising_edge(clk);
      end loop;
      m_ready <= '0';
      wait until rising_edge(clk);
      wait until rising_edge(clk);
    end loop;

    report "Test stopped";
    running <= '0';
    wait;
  end process stim_proc;

end architecture simulation;

