library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.RSA_PKG.all;

entity RSA_KEYGEN is
  port(
    clk     : in  std_logic;
    rst     : in  std_logic;
    start   : in  std_logic;

    seed    : in  unsigned(127 downto 0);
    load    : in  std_logic;

    o_done  : out std_logic;
    o_N     : out unsigned(2*PRIME_WIDTH-1 downto 0);  
    o_e     : out unsigned(2*PRIME_WIDTH-1 downto 0);  
    o_d     : out unsigned(2*PRIME_WIDTH-1 downto 0);  
    o_valid : out std_logic                            
  );
end entity;

architecture RTL of RSA_KEYGEN is

  constant KEY_WIDTH : positive := 2 * PRIME_WIDTH;

  constant E_VALUE : unsigned(KEY_WIDTH-1 downto 0) := to_unsigned(65537, KEY_WIDTH);

  component RANDOM_GEN is
    generic(WIDTH : positive);
    port(
      clk    : in  std_logic;
      rst    : in  std_logic;
      seed   : in  unsigned(127 downto 0);
      load   : in  std_logic;
      start  : in  std_logic;
      o_done : out std_logic;
      o_rng  : out unsigned(WIDTH-1 downto 0)
    );
  end component;

  component MILLER_RABIN is
    generic(
      K             : positive;
      NUM_WITNESSES : positive
    );
    port(
      clk     : in  std_logic;
      rst     : in  std_logic;
      start   : in  std_logic;
      i_n     : in  unsigned(K-1 downto 0);
      o_done  : out std_logic;
      o_prime : out std_logic
    );
  end component;

  component EXT_GCD is
    generic(K : positive);
    port(
      clk     : in  std_logic;
      rst     : in  std_logic;
      start   : in  std_logic;
      i_e     : in  unsigned(K-1 downto 0);
      i_phi   : in  unsigned(K-1 downto 0);
      o_done  : out std_logic;
      o_valid : out std_logic;
      o_d     : out unsigned(K-1 downto 0)
    );
  end component;

  type state_t is (
    IDLE,
    ST_GEN_P,          -- Request random number for p
    ST_GEN_P_WAIT,     -- Wait for PRNG
    ST_TEST_P,         -- Start Miller-Rabin on p candidate
    ST_TEST_P_WAIT,    -- Wait for primality result
    ST_GEN_Q,          -- Request random number for q
    ST_GEN_Q_WAIT,     -- Wait for PRNG
    ST_TEST_Q,         -- Start Miller-Rabin on q candidate
    ST_TEST_Q_WAIT,    -- Wait for primality result
    ST_COMPUTE_N,      -- N = p * q, phi = (p-1)*(q-1)
    ST_GCD_LAUNCH,     -- Start EXT_GCD for d = e^-1 mod phi
    ST_GCD_WAIT,       -- Wait for GCD result
    ST_OUTPUT_KEYS,    -- Latch outputs
    DONE_ST
  );
  signal state : state_t := IDLE;


  signal rng_start : std_logic := '0';
  signal rng_done  : std_logic;
  signal rng_out   : unsigned(PRIME_WIDTH-1 downto 0);

  signal mr_start  : std_logic := '0';
  signal mr_input  : unsigned(PRIME_WIDTH-1 downto 0) := (others => '0');
  signal mr_done   : std_logic;
  signal mr_prime  : std_logic;

  signal gcd_start : std_logic := '0';
  signal gcd_e     : unsigned(KEY_WIDTH-1 downto 0) := (others => '0');
  signal gcd_phi   : unsigned(KEY_WIDTH-1 downto 0) := (others => '0');
  signal gcd_done  : std_logic;
  signal gcd_valid : std_logic;
  signal gcd_d     : unsigned(KEY_WIDTH-1 downto 0);

  -- Stored primes
  signal p_reg : unsigned(PRIME_WIDTH-1 downto 0) := (others => '0');
  signal q_reg : unsigned(PRIME_WIDTH-1 downto 0) := (others => '0');

  -- Computed values
  signal n_reg   : unsigned(KEY_WIDTH-1 downto 0) := (others => '0');
  signal phi_reg : unsigned(KEY_WIDTH-1 downto 0) := (others => '0');
  signal d_reg   : unsigned(KEY_WIDTH-1 downto 0) := (others => '0');

  signal valid_reg : std_logic := '0';

begin

  RNG_INST : RANDOM_GEN
    generic map(WIDTH => PRIME_WIDTH)
    port map(
      clk    => clk,
      rst    => rst,
      seed   => seed,
      load   => load,
      start  => rng_start,
      o_done => rng_done,
      o_rng  => rng_out
    );

  MR_INST : MILLER_RABIN
    generic map(
      K             => PRIME_WIDTH,
      NUM_WITNESSES => NUM_WITNESSES
    )
    port map(
      clk     => clk,
      rst     => rst,
      start   => mr_start,
      i_n     => mr_input,
      o_done  => mr_done,
      o_prime => mr_prime
    );

  GCD_INST : EXT_GCD
    generic map(K => KEY_WIDTH)
    port map(
      clk     => clk,
      rst     => rst,
      start   => gcd_start,
      i_e     => gcd_e,
      i_phi   => gcd_phi,
      o_done  => gcd_done,
      o_valid => gcd_valid,
      o_d     => gcd_d
    );

  process(clk, rst)
  begin
    if rst = '1' then
      state     <= IDLE;
      rng_start <= '0';
      mr_start  <= '0';
      gcd_start <= '0';
      mr_input  <= (others => '0');
      gcd_e     <= (others => '0');
      gcd_phi   <= (others => '0');
      p_reg     <= (others => '0');
      q_reg     <= (others => '0');
      n_reg     <= (others => '0');
      phi_reg   <= (others => '0');
      d_reg     <= (others => '0');
      valid_reg <= '0';
      o_done    <= '0';
      o_N       <= (others => '0');
      o_e       <= (others => '0');
      o_d       <= (others => '0');
      o_valid   <= '0';

    elsif rising_edge(clk) then
      rng_start <= '0';
      mr_start  <= '0';
      gcd_start <= '0';
      o_done    <= '0';

      case state is
      
        when IDLE =>
          if start = '1' then
            state <= ST_GEN_P;
          end if;

        when ST_GEN_P =>
          rng_start <= '1';
          state     <= ST_GEN_P_WAIT;

        when ST_GEN_P_WAIT =>
          if rng_done = '1' then
            mr_input <= rng_out;
            mr_start <= '1';
            state    <= ST_TEST_P;
          end if;

        -- ================================================================
        -- Test p for primality
        -- ================================================================
        when ST_TEST_P =>
          state <= ST_TEST_P_WAIT;

        when ST_TEST_P_WAIT =>
          if mr_done = '1' then
            if mr_prime = '1' then
              p_reg <= mr_input;
              state <= ST_GEN_Q;
            else
              state <= ST_GEN_P;
            end if;
          end if;

        when ST_GEN_Q =>
          rng_start <= '1';
          state     <= ST_GEN_Q_WAIT;

        when ST_GEN_Q_WAIT =>
          if rng_done = '1' then
            mr_input <= rng_out;
            mr_start <= '1';
            state    <= ST_TEST_Q;
          end if;

        -- ================================================================
        -- Test q for primality
        -- ================================================================
        when ST_TEST_Q =>
          state <= ST_TEST_Q_WAIT;

        when ST_TEST_Q_WAIT =>
          if mr_done = '1' then
            if mr_prime = '1' then
              q_reg <= mr_input;
              -- Ensure p /= q
              if mr_input = p_reg then
                state <= ST_GEN_Q;
              else
                state <= ST_COMPUTE_N;
              end if;
            else
              state <= ST_GEN_Q;
            end if;
          end if;

        -- ================================================================
        -- Compute N = p*q and phi = (p-1)*(q-1)
        -- ================================================================
        when ST_COMPUTE_N =>
          n_reg   <= p_reg * q_reg;
          phi_reg <= (p_reg - 1) * (q_reg - 1);
          state   <= ST_GCD_LAUNCH;

        -- ================================================================
        -- Compute d = e^(-1) mod phi
        -- ================================================================
        when ST_GCD_LAUNCH =>
          gcd_e     <= resize(E_VALUE, KEY_WIDTH);
          gcd_phi   <= phi_reg;
          gcd_start <= '1';
          state     <= ST_GCD_WAIT;

        when ST_GCD_WAIT =>
          if gcd_done = '1' then
            if gcd_valid = '1' then
              d_reg     <= gcd_d;
              valid_reg <= '1';
              state     <= ST_OUTPUT_KEYS;
            else
              -- gcd(e, phi) /= 1, retry with new q
              valid_reg <= '0';
              state     <= ST_GEN_Q;
            end if;
          end if;

        when ST_OUTPUT_KEYS =>
          o_N     <= n_reg;
          o_e     <= E_VALUE;
          o_d     <= d_reg;
          o_valid <= valid_reg;
          state   <= DONE_ST;

       when DONE_ST =>
          o_done <= '1';
          state  <= IDLE;

      end case;
    end if;
  end process;

end RTL;