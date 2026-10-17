library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.RNS_PKG.all;

entity TB_RSA is
end entity;

architecture sim of TB_RSA is

  component RSA is
    port(
      clk       : in  std_logic;
      rst       : in  std_logic;
      start     : in  std_logic;
      
      i_message : in  unsigned(INT_WIDTH-1 downto 0);
      i_exp     : in  unsigned(MOD_WIDTH-1 downto 0);
      i_N       : in  unsigned(INT_WIDTH-1 downto 0);
      
      o_done    : out std_logic;
      o_result  : out unsigned(INT_WIDTH-1 downto 0)
    );
  end component;

  constant CLK_PERIOD : time := 10 ns;

  signal clk       : std_logic := '0';
  signal rst       : std_logic := '1';
  signal start     : std_logic := '0';
  signal i_message : unsigned(INT_WIDTH-1 downto 0) := (others => '0');
  signal i_exp     : unsigned(MOD_WIDTH-1 downto 0) := (others => '0');
  signal i_N       : unsigned(INT_WIDTH-1 downto 0) := (others => '0');
  signal o_done    : std_logic;
  signal o_result  : unsigned(INT_WIDTH-1 downto 0);

begin

  DUT : RSA
    port map(
      clk       => clk,
      rst       => rst,
      start     => start,
      i_message => i_message,
      i_exp     => i_exp,
      i_N       => i_N,
      o_done    => o_done,
      o_result  => o_result
    );

  clk <= not clk after CLK_PERIOD / 2;

  process

    procedure run_test(
      constant msg      : in integer;
      constant exp      : in integer;
      constant n_val    : in integer;
      constant expected : in integer
    ) is
    begin
      i_message <= to_unsigned(msg,   INT_WIDTH);
      i_exp     <= to_unsigned(exp,   MOD_WIDTH);
      i_N       <= to_unsigned(n_val, INT_WIDTH);

      wait until rising_edge(clk);
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';

      wait until o_done = '1';
      wait until falling_edge(clk);

      if o_result = to_unsigned(expected, INT_WIDTH) then
        report "PASS: " & integer'image(msg) & "^" & integer'image(exp)
               & " mod " & integer'image(n_val)
               & " = " & integer'image(to_integer(o_result));
      else
        report "FAIL: " & integer'image(msg) & "^" & integer'image(exp)
               & " mod " & integer'image(n_val)
               & "  expected=" & integer'image(expected)
               & "  got=" & integer'image(to_integer(o_result))
          severity error;
      end if;

      wait for 5 * CLK_PERIOD;
    end procedure;

  begin
    rst <= '1';
    wait for 4 * CLK_PERIOD;
    rst <= '0';
    wait until rising_edge(clk);

    -- test cases
    
    run_test(5678, 50, 10007, 4887);
    run_test(5678, 52, 10007, 4124);
    run_test(5678, 54, 10007, 2401);
    run_test(5678, 55, 10007, 3344);
    run_test(5678, 56, 10007, 3953);
    run_test(5678, 57, 10007, 9440);
    run_test(5678, 250, 100007, 96251);
    run_test(1234, 123, 10007, 6377);
    run_test(56780, 550, 1000007, 350739);

    

    report "ALL TESTS FINISHED";
    wait;
  end process;

end architecture;