library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.sprite_pkg.all;

entity ball is
  generic (
    G_SCREEN_X : natural range 0 to 2047;
    G_SCREEN_Y : natural range 0 to 2047
  );
  port (
    clk_i        : in    std_logic;
    rst_i        : in    std_logic;
    ce_i         : in    std_logic;
    player_x_i   : in    natural range 0 to 2047;
    player_y_i   : in    natural range 0 to 2047;
    computer_x_i : in    natural range 0 to 2047;
    computer_y_i : in    natural range 0 to 2047;
    ball_x_o     : out   natural range 0 to 2047;
    ball_y_o     : out   natural range 0 to 2047
  );
end entity ball;

architecture synthesis of ball is

  constant C_GRAVITY : natural  := 1;

  constant C_MAX_POS : natural  := 2047;
  constant C_MAX_VEL : natural  := 100;

  subtype  pos_type is natural range 0 to C_MAX_POS;
  subtype  vel_type is integer range -C_MAX_VEL to C_MAX_VEL;

  signal   pos_x     : pos_type := G_SCREEN_X / 2;
  signal   pos_y     : pos_type := G_SCREEN_Y / 2;
  signal   vel_x     : vel_type;
  signal   vel_y     : vel_type;
  signal   center_x  : pos_type;
  signal   center_y  : pos_type;
  signal   vel_x_new : vel_type;
  signal   vel_y_new : vel_type;

begin

  -- Update ball velocity and position
  ball_proc : process (clk_i)
    --

    pure function add_clamp (
      x : natural;
      y : integer
    ) return pos_type is
    begin
      if x + y >= 0 and x + y <= C_MAX_POS then
        return x + y;
      elsif x + y < 0 then
        return 0;
      else
        return C_MAX_POS;
      end if;
    end function;

  begin
    if rising_edge(clk_i) then
      vel_x <= vel_x_new;
      vel_y <= vel_y_new + C_GRAVITY;

      pos_x <= add_clamp(pos_x, vel_x);
      pos_y <= add_clamp(pos_y, vel_y);
    end if;
  end process ball_proc;

  -- Check collision with player
  collision_inst : entity work.collision
    generic map (
      G_MAX_POS => C_MAX_POS,
      G_MAX_VEL => C_MAX_VEL,
      G_RADIUS  => 1
    )
    port map (
      clk_i      => clk_i,
      rst_i      => rst_i,
      pos_x_i    => pos_x,
      pos_y_i    => pos_y,
      vel_x_i    => vel_x,
      vel_y_i    => vel_y,
      center_x_i => player_x_i,
      center_y_i => player_y_i,
      vel_x_o    => vel_x_new,
      vel_y_o    => vel_y_new
    ); -- collision_inst : entity work.collision

end architecture synthesis;

