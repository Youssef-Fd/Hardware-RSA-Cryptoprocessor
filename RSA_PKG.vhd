library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package RSA_PKG is

  constant NUM_MODULI : positive := 4;
  constant MOD_WIDTH  : positive := 32;
  constant INT_WIDTH  : positive := 32;

  constant PRIME_WIDTH   : positive := 128;
  constant NUM_WITNESSES : positive := 4;

  subtype mod_word_t  is unsigned(MOD_WIDTH-1 downto 0);
  type    mod_array_t is array (natural range <>) of mod_word_t;
  
  ---------------------------------------------------------------------------
  -- mod_inverse_fn: compute a^-1 mod m  (Extended Euclidean Algorithm).
  -- Used at ELABORATION TIME only (inside generics / generate statements).
  -- Both a and m must fit in a VHDL integer (≥ 32 bits).
  ---------------------------------------------------------------------------
  function mod_inverse_fn(a : integer; m : integer) return integer;

end package;

package body RSA_PKG is
  function mod_inverse_fn(a : integer; m : integer) return integer is
    variable t     : integer := 0;
    variable new_t : integer := 1;
    variable r     : integer := m;
    variable new_r : integer := a;
    variable q     : integer;
    variable tmp   : integer;
  begin
    for i in 0 to 63 loop        -- 64 iterations covers any 32-bit input
      exit when new_r = 0;       -- same as while condition
      q     := r / new_r;
      tmp   := t - q * new_t;
      t     := new_t;
      new_t := tmp;
      tmp   := r - q * new_r;
      r     := new_r;
      new_r := tmp;
    end loop;
    if t < 0 then
      t := t + m;
    end if;
    return t;
  end function;
end package body;