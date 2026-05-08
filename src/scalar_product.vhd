library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

entity scalar_product is
  generic (
    G_A_BITS     : natural;
    G_A_ACCURACY : natural;
    G_B_BITS     : natural;
    G_B_ACCURACY : natural;
    G_O_BITS     : natural;
    G_O_ACCURACY : natural
  );
  port (
    clk_i   : in    std_logic;
    rst_i   : in    std_logic;

    a_i     : in    sfixed(G_A_BITS - 1 downto -G_A_ACCURACY);
    b_x_i   : in    sfixed(G_B_BITS - 1 downto -G_B_ACCURACY);
    b_y_i   : in    sfixed(G_B_BITS - 1 downto -G_B_ACCURACY);

    res_x_o : out   sfixed(G_O_BITS - 1 downto -G_O_ACCURACY);
    res_y_o : out   sfixed(G_O_BITS - 1 downto -G_O_ACCURACY)
  );
end entity scalar_product;

architecture synthesis of scalar_product is

begin

--  res_proc : process (clk_i)
--  begin
--    if rising_edge(clk_i) then
      res_x_o <= resize(a_i * b_x_i, res_x_o,
                        round_style    => fixed_truncate,
                        overflow_style => fixed_wrap);
      res_y_o <= resize(a_i * b_y_i, res_y_o,
                        round_style    => fixed_truncate,
                        overflow_style => fixed_wrap);
--    end if;
--  end process res_proc;

end architecture synthesis;

