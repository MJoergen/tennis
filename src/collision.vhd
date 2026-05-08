library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

-- This is a fairly generic collision handling block.
-- The concept is a point object with a given position and moving with a given velocity.
-- On its path it encounters a stationary circular ball with a given center and a constant
-- radius. This block will calculate the new velocity assuming completely elastic
-- collision.

-- Since the calculations are quite involved, some approximations are made along the way.
-- Furthermore, it is assumed that the radius is a power of two.

-- The formulae used are:
-- DP_vec = POS_vec - CENTER_vec
-- DP2 = DP_vec * DP_vec
-- R2 = RADIUS^2
-- P = V_vec * DP_vec
-- T = 2*P / DP2
-- V_NEW_vec = V_vec
-- if DP2 < R2
--   V_NEW_vec = V_vec - T * DP_vec
--
-- In order to avoid the division by DP2 when calculating T, we employ the following
-- approximation:
-- 1 / DP2 === 1 / R2 * (1 + (R2 - DP2)/R2)
-- which is good when DP2 is close to R2.
-- It can be assumed that dividing by R2 is easy, since the radius must be a power of two.

entity collision is
  generic (
    G_ACCURACY : natural;
    G_POS_BITS : natural;
    G_VEL_BITS : natural;
    G_RADIUS   : sfixed(G_POS_BITS - 1 downto -G_ACCURACY)
  );
  port (
    clk_i        : in    std_logic;
    rst_i        : in    std_logic;

    s_ready_o    : out   std_logic;
    s_valid_i    : in    std_logic;
    s_pos_x_i    : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
    s_pos_y_i    : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
    s_vel_x_i    : in    sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
    s_vel_y_i    : in    sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
    s_center_x_i : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
    s_center_y_i : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);

    m_ready_i    : in    std_logic;
    m_valid_o    : out   std_logic;
    m_vel_x_o    : out   sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
    m_vel_y_o    : out   sfixed(G_VEL_BITS - 1 downto -G_ACCURACY)
  );
end entity collision;

architecture synthesis of collision is

  signal dp_ready : std_logic;
  signal dp_valid : std_logic;
  signal dp_x     : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal dp_y     : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);

  signal dp2_ready : std_logic;
  signal dp2_valid : std_logic;
  signal dp2       : sfixed(2 * G_POS_BITS - 1 downto -G_ACCURACY);

  signal r2 : sfixed(2 * G_POS_BITS - 1 downto -G_ACCURACY);

  signal dp_unit_m_ready : std_logic;
  signal dp_unit_m_valid : std_logic;
  signal dp_unit_m_x     : sfixed(0 downto -G_ACCURACY);
  signal dp_unit_m_y     : sfixed(0 downto -G_ACCURACY);

  signal dot_ready : std_logic;
  signal dot_valid : std_logic;
  signal dot       : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);

begin

  s_ready_o <= '1';

  -- Calculate DP = POS - CENTER
  dp_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if dp_ready = '1' then
        dp_valid <= '0';
      end if;

      if s_valid_i = '1' then
        dp_x     <= resize(to_sfixed(s_pos_x_i) - to_sfixed(s_center_x_i), dp_x);
        dp_y     <= resize(to_sfixed(s_pos_y_i) - to_sfixed(s_center_y_i), dp_y);
        dp_valid <= '1';
      end if;
    end if;
  end process dp_proc;

  -- Convert DP to unit vector
  unit_vector_dp_inst : entity work.unit_vector
    generic map (
      G_ITERS    => G_ACCURACY + 1,
      G_ACCURACY => G_ACCURACY,
      G_BITS     => G_POS_BITS
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => dp_ready,
      s_valid_i => dp_valid,
      s_x_i     => dp_x,
      s_y_i     => dp_y,
      m_ready_i => dp_unit_m_ready,
      m_valid_o => dp_unit_m_valid,
      m_x_o     => dp_unit_m_x,
      m_y_o     => dp_unit_m_y
    ); -- unit_vector_dp : entity work.unit_vector

  dot_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if dot_ready = '1' then
        dot_valid <= '0';
      end if;

      if dp_unit_m_valid = '1' then
        dot       <= resize(dp_unit_m_x * s_vel_x_i + dp_unit_m_y * s_vel_y_i, dot);
        dot_valid <= '1';
      end if;
    end if;
  end process dot_proc;

  dp2_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if dp2_ready = '1' then
        dp2_valid <= '0';
      end if;

      if dp_valid = '1' then
        dp2       <= resize(dp_x * dp_x + dp_y * dp_y, dp2);
        dp2_valid <= '1';
      end if;
    end if;
  end process dp2_proc;

  r2_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      r2 <= resize(G_RADIUS * G_RADIUS, r2);
    end if;
  end process r2_proc;

  dot_ready       <= '1';
  dp2_ready       <= '1';
  dp_unit_m_ready <= '1';

  res_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      if dot_valid = '1' then
        if dp2 < r2 then
          m_vel_x_o <= resize(s_vel_x_i - 2 * dot * dp_x, m_vel_x_o);
          m_vel_y_o <= resize(s_vel_y_i - 2 * dot * dp_y, m_vel_y_o);
        else
          m_vel_x_o <= s_vel_x_i;
          m_vel_y_o <= s_vel_y_i;
        end if;
        m_valid_o <= '1';
      end if;

      if rst_i = '1' then
        m_valid_o <= '0';
      end if;
    end if;
  end process res_proc;

end architecture synthesis;

