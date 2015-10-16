-- TestBench Template

  LIBRARY ieee;
  USE ieee.std_logic_1164.ALL;
  USE ieee.numeric_std.ALL;

  use work.types.all;

  ENTITY testbench IS
      generic (
          wtime : std_logic_vector (15 downto 0) := x"0100"
      );
  END testbench;

  ARCHITECTURE behavior OF testbench IS

  -- Component Declaration
          COMPONENT TOP
          generic (
--              wtime : std_logic_vector (15 downto 0) := x"1ADB"
              wtime : std_logic_vector (15 downto 0) := x"0D6D"
          );
          PORT(
                  MCLK1 : in std_logic;
                  RS_RX : in std_logic;
                  RS_TX : out std_logic;
                  ZD     : inout std_logic_vector (31 downto 0);
                  ZA     : out   std_logic_vector (19 downto 0);
                  XWA    : out   std_logic;
                  XE1    : out   std_logic;
                  E2A    : out   std_logic;
                  XE3    : out   std_logic;
                  XGA    : out   std_logic;
                  XZCKE  : out   std_logic;
                  ADVA   : out   std_logic;
                  XLBO   : out   std_logic;
                  ZZA    : out   std_logic;
                  XFT    : out   std_logic;
                  XZBE   : out   std_logic_vector (3 downto 0);
                  ZCLKMA : out   std_logic_vector (1 downto 0));
          END COMPONENT;
          component sram_sim port (
                  ZD     : inout std_logic_vector (31 downto 0);
                  ZA     : in std_logic_vector (19 downto 0);
                  XWA    : in std_logic;
                  XE1    : in std_logic;
                  E2A    : in std_logic;
                  XE3    : in std_logic;
                  XGA    : in std_logic;
                  XZCKE  : in std_logic;
                  ADVA   : in std_logic;
                  XLBO   : in std_logic;
                  ZZA    : in std_logic;
                  XFT    : in std_logic;
                  XZBE   : in std_logic_vector (3 downto 0);
                  ZCLKMA : in std_logic_vector (1 downto 0));
          end component;
          signal clk : std_logic;
          signal rs_rx : std_logic;
          signal rs_tx : std_logic;
          signal zd     : std_logic_vector (31 downto 0);
          signal za     : std_logic_vector (19 downto 0);
          signal xwa    : std_logic;
          signal xe1    : std_logic;
          signal e2a    : std_logic;
          signal xe3    : std_logic;
          signal xga    : std_logic;
          signal xzcke  : std_logic;
          signal adva   : std_logic;
          signal xlbo   : std_logic;
          signal zza    : std_logic;
          signal xft    : std_logic;
          signal xzbe   : std_logic_vector (3 downto 0);
          signal zclkma : std_logic_vector (1 downto 0);
          signal rst : std_logic := '0';
          signal receiver_in : receiver_in_type;
          signal receiver_out : receiver_out_type;
          signal sender_in : sender_in_type;
          signal sender_out : sender_out_type;
          signal counter : std_logic_vector (7 downto 0) := x"16";
          type inst_list_type is array (22 downto 0) of std_logic_vector (31 downto 0);
          signal inst_list : inst_list_type := (
x"01000014",
x"08207f7f",
x"0a000010",
x"14218000",
x"0821ffff",
x"08407f00",
x"14428000",
x"08420001",
x"08600009",
x"0880000a",
x"20610000",
x"08630001",
x"20620000",
x"d8620000",
x"10630001",
x"d8610000",
x"c0211000",
x"d4810000",
x"24890000",
x"81200000",
x"84000000",
x"03000000",
x"00000000"
        );

  BEGIN

  -- Component Instantiation
--          uut: TOP generic map (x"01ab") PORT MAP(
          uut: TOP generic map (wtime) PORT MAP(
            MCLK1 => clk,
            RS_RX => rs_rx,
            RS_TX => rs_tx,
            ZD => zd,
            ZA => za,
            XWA => xwa,
            XE1 => xe1,
            E2A => e2a,
            XE3 => xe3,
            XGA => xga,
            XZCKE => xzcke,
            ADVA => adva,
            XLBO => xlbo,
            ZZA => zza,
            XFT => xft,
            XZBE => xzbe,
            ZCLKMA => zclkma
            );

          sram : sram_sim port map (
            ZD => zd,
            ZA => za,
            XWA => xwa,
            XE1 => xe1,
            E2A => e2a,
            XE3 => xe3,
            XGA => xga,
            XZCKE => xzcke,
            ADVA => adva,
            XLBO => xlbo,
            ZZA => zza,
            XFT => xft,
            XZBE => xzbe,
            ZCLKMA => zclkma
        );


          recv: receiver generic map (wtime) port map (
            clk,
            rst,
            receiver_in,
            receiver_out);
          send: sender generic map (wtime) port map (
            clk,
            rst,
            sender_in,
            sender_out);

          receiver_in.rs_rx <= rs_tx;
          rs_rx <= sender_out.rs_tx;


  --  Test Bench Statements
     tb : PROCESS
     BEGIN
        clk <= '0';
        wait for 7.26 ns;
        clk <= '1';
        wait for 7.26 ns;
     END PROCESS tb;

     process (clk)
         variable sending : std_logic := '0';
     begin
         if rising_edge(clk) then
             if sender_out.busy = '0' and sending = '0' and unsigned(counter) /= 0 then
                 counter <= std_logic_vector (unsigned(counter) - 1);
                 sender_in.data <= inst_list (to_integer(unsigned(counter)));
                 sender_in.go <= '1';
                 sending := '1';
             else
                 sender_in.go <= '0';
                 sending := '0';
             end if;
         end if;
     end process;
  --  End Test Bench

  END;
