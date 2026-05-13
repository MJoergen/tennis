library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

entity player is
  generic (
    G_POS_BITS    : natural;
    G_VEL_BITS    : natural;
    G_ACCURACY    : natural;
    G_SIZE_SPRITE : natural;
    G_SCREEN_X    : natural range 0 to 2047;
    G_SCREEN_Y    : natural range 0 to 2047
  );
  port (
    clk_i       : in    std_logic;
    rst_i       : in    std_logic;
    ce_i        : in    std_logic;
    btn_left_i  : in    std_logic;
    btn_right_i : in    std_logic;
    player_x_o  : out   ufixed(G_POS_BITS - 1 downto - G_ACCURACY);
    player_y_o  : out   ufixed(G_POS_BITS - 1 downto - G_ACCURACY)
  );
end entity player;

architecture synthesis of player is

  constant C_INIT_PLAYER_X   : natural                                   := G_SCREEN_X / 4;
  constant C_INIT_PLAYER_Y   : natural                                   := G_SCREEN_Y - G_SIZE_SPRITE;
  constant C_PLAYER_VELOCITY : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY) := to_sfixed(0.1, G_VEL_BITS - 1, -G_ACCURACY);

  signal   player_x : ufixed(G_POS_BITS - 1 downto - G_ACCURACY);
  signal   player_y : ufixed(G_POS_BITS - 1 downto - G_ACCURACY);

begin

  player_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if ce_i = '1' then
        if btn_left_i = '1' and player_x > 0 then
          player_x <= resize(ufixed(sfixed(player_x) - C_PLAYER_VELOCITY), player_x);
        end if;
        if btn_right_i = '1' and player_x < G_SCREEN_X - 1 then
          player_x <= resize(ufixed(sfixed(player_x) + C_PLAYER_VELOCITY), player_x);
        end if;
      end if;

      if rst_i = '1' then
        player_x <= to_ufixed(C_INIT_PLAYER_X, G_POS_BITS - 1, - G_ACCURACY);
        player_y <= to_ufixed(C_INIT_PLAYER_Y, G_POS_BITS - 1, - G_ACCURACY);
      end if;
    end if;
  end process player_proc;

  player_x_o <= player_x;
  player_y_o <= player_y;

end architecture synthesis;

