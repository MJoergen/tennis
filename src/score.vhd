library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

entity score is
  generic (
    G_ACCURACY : natural;
    G_POS_BITS : natural;
    G_SCREEN_X : natural range 0 to 2047;
    G_SCREEN_Y : natural range 0 to 2047
  );
  port (
    clk_i         : in    std_logic;
    rst_i         : in    std_logic;
    ce_i          : in    std_logic;
    game_new_i    : in    std_logic;
    ball_x_i      : in    ufixed(G_POS_BITS - 1 downto - G_ACCURACY);
    ball_y_i      : in    ufixed(G_POS_BITS - 1 downto - G_ACCURACY);
    score_left_o  : out   natural range 0 to 10;
    score_right_o : out   natural range 0 to 10;
    game_over_o   : out   std_logic;
    ball_reset_o  : out   std_logic
  );
end entity score;

architecture synthesis of score is

begin

  score_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      ball_reset_o <= '0';
      game_over_o  <= '0';

      if ce_i = '1' then
        if ball_y_i > G_SCREEN_Y then
          if ball_x_i < G_SCREEN_X / 2 then
            score_left_o_ <= score_left_o - 1;
            if score_left_o = 1 then
              game_over_o <= '0';
            end if;
          else
            score_right_o <= score_right_o - 1;
            if score_right_o = 1 then
              game_over_o <= '0';
            end if;
          end if;
          ball_reset_o <= '1';
        end if;
      end if;

      if rst_i = '1' or game_new_i = '1' then
        score_left_o  <= 10;
        score_right_o <= 10;
      end if;
    end if;
  end process score_proc;

end architecture synthesis;

