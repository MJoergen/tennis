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

  pure function log2 (
    arg : sfixed(G_POS_BITS - 1 downto -G_ACCURACY)
  ) return natural is
    variable res_v : natural;
    variable val_v : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);
  begin
    res_v := 0;
    val_v := to_sfixed(1, G_POS_BITS - 1, -G_ACCURACY);
    while val_v < arg loop
      res_v := res_v + 1;
      val_v := resize(val_v * 2.0, val_v);
    end loop;
    assert val_v = arg
      report "Compile error: G_RADIUS (" & to_string(G_RADIUS) & ") must be a power of two (" & to_string(val_v) & ")";
    report "log(G_RADIUS)=" & to_string(res_v);

    return res_v;
  end function;

  constant C_LOG2_RADIUS : natural := log2(G_RADIUS);

  signal   r2 : sfixed(2 * G_POS_BITS downto -G_ACCURACY);

  -- Stage 1
  signal   s1_valid : std_logic;
  signal   s1_dp_x  : sfixed(G_POS_BITS     downto -G_ACCURACY);
  signal   s1_dp_y  : sfixed(G_POS_BITS     downto -G_ACCURACY);
  signal   s1_vel_x : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal   s1_vel_y : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);

  -- Stage 2
  signal   s2_valid : std_logic;
  signal   s2_dp2   : sfixed(2 * G_POS_BITS downto -G_ACCURACY);
  signal   s2_p     : sfixed(G_VEL_BITS + G_POS_BITS downto -G_ACCURACY);
  signal   s2_dp_x  : sfixed(G_POS_BITS     downto -G_ACCURACY);
  signal   s2_dp_y  : sfixed(G_POS_BITS     downto -G_ACCURACY);
  signal   s2_vel_x : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal   s2_vel_y : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);

  -- Stage 3
  signal   s3_valid   : std_logic;
  signal   s3_dp2     : sfixed(2 * G_POS_BITS downto -G_ACCURACY);
  signal   s3_p       : sfixed(G_VEL_BITS + G_POS_BITS downto -G_ACCURACY);
  signal   s3_dp2_inv : sfixed(G_ACCURACY - 1 downto -G_POS_BITS);
  signal   s3_dp_x    : sfixed(G_POS_BITS     downto -G_ACCURACY);
  signal   s3_dp_y    : sfixed(G_POS_BITS     downto -G_ACCURACY);
  signal   s3_vel_x   : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal   s3_vel_y   : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);

  -- Stage 4
  signal   s4_valid : std_logic;
  signal   s4_dp2   : sfixed(2 * G_POS_BITS downto -G_ACCURACY);
  signal   s4_p     : sfixed(2 * G_POS_BITS downto -G_ACCURACY);
  signal   s4_t     : sfixed(G_VEL_BITS + G_ACCURACY - 1 downto -G_ACCURACY);
  signal   s4_dp_x  : sfixed(G_POS_BITS     downto -G_ACCURACY);
  signal   s4_dp_y  : sfixed(G_POS_BITS     downto -G_ACCURACY);
  signal   s4_vel_x : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal   s4_vel_y : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);

begin

  s_ready_o <= m_ready_i or not m_valid_o;

  vel_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      -- R2 = RADIUS^2
      r2         <= resize(G_RADIUS * G_RADIUS, r2);

      -- Stage 1
      -- DP_vec = POS_vec - CENTER_vec
      s1_valid   <= s_valid_i and s_ready_o;
      s1_dp_x    <= resize(to_sfixed(s_pos_x_i) - to_sfixed(s_center_x_i), s1_dp_x);
      s1_dp_y    <= resize(to_sfixed(s_pos_y_i) - to_sfixed(s_center_y_i), s1_dp_y);
      s1_vel_x   <= s_vel_x_i;
      s1_vel_y   <= s_vel_y_i;

      -- Stage 2
      -- DP2 = DP_vec * DP_vec
      -- P = V_vec * DP_vec
      s2_valid   <= s1_valid;
      s2_dp2     <= resize(s1_dp_x  * s1_dp_x + s1_dp_y  * s1_dp_y, s2_dp2);
      s2_p       <= resize(s1_vel_x * s1_dp_x + s1_vel_y * s1_dp_y, s2_p);
      s2_dp_x    <= s1_dp_x;
      s2_dp_y    <= s1_dp_y;
      s2_vel_x   <= s1_vel_x;
      s2_vel_y   <= s1_vel_y;

      -- Stage 3
      -- 1 / DP2 =~= 1 / R2 * (1 + (R2 - DP2)/R2)
      s3_valid   <= s2_valid;
      s3_dp2     <= s2_dp2;
      s3_p       <= s2_p;
      s3_dp2_inv <= resize(1 + ((r2 - s2_dp2) sra (2 * C_LOG2_RADIUS)), s3_dp2_inv) sra (2 * C_LOG2_RADIUS);
      s3_dp_x    <= s2_dp_x;
      s3_dp_y    <= s2_dp_y;
      s3_vel_x   <= s2_vel_x;
      s3_vel_y   <= s2_vel_y;

      -- Stage 4
      -- T = 2*P / DP2
      s4_valid   <= s3_valid;
      s4_dp2     <= s3_dp2;
      s4_p       <= s3_p;
      s4_t       <= resize(s3_p * s3_dp2_inv, s4_t) sla 1;
      s4_dp_x    <= s3_dp_x;
      s4_dp_y    <= s3_dp_y;
      s4_vel_x   <= s3_vel_x;
      s4_vel_y   <= s3_vel_y;

      -- Stage 5
      -- V_NEW_vec = V_vec
      m_valid_o  <= s4_valid;
      m_vel_x_o  <= s4_vel_x;
      m_vel_y_o  <= s4_vel_y;

      if s4_dp2 < r2 then
        -- V_NEW_vec = V_vec - T * DP_vec
        m_vel_x_o <= resize(s4_vel_x - s4_t * s4_dp_x, m_vel_x_o);
        m_vel_y_o <= resize(s4_vel_y - s4_t * s4_dp_y, m_vel_y_o);
      end if;
    end if;
  end process vel_proc;

end architecture synthesis;

